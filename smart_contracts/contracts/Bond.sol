//SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.10;
import "@prb/math/contracts/PRBMathUD60x18.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title iRIS Bond main contract
/// @author hklin
/// @notice Every contract stands for one bond
/// @dev    Notice that this should be produce by an upgradable extension

/// @notice Main parameter for a bound
struct BondFeature {
    bool hadSet; // ensure the bond feaure will only set once
    bool convertible; // is the bond a convertible bond
    address issuer; // The issuer of the bond
    address baseToken; // token used to purchase the bond
    address convertibleToken; // convertible payback token
    uint256 maxPrinciple; // the total issuance in _baseToken of the bond
    uint256 couponRate; // the coupon rate of the bond (in block) (Wad)
    uint256 couponInterval; // the date bond issuer make interest payments (in block)
    uint256 couponTime; // the time of which the bond issue coupon
    uint256 convertRatio; // the conversion ratio of baseToken and convertibleToken (Wad)
    uint256 minShare; // the minimum share in price of _baseToken
}

struct Debt {
    uint256 baseDebt;
    uint256 convertibleDebt;
}

/// @notice Control the sale of the bond
struct Sale {
    uint256 saleStart; // the date the bond sale start (in block)
    uint256 saleEnd; // the date the bond sale end (in block)
    uint256 totalPrinciple; // total amount of issued
}

/// @notice Main parameter for a holder of a share
struct Share {
    uint256 purchasedPrinciple; // the amount of total principle purchased
    uint256 convertPrecent; // Percent of bond that have converted (Wad)
    uint256 lastRedeemCoupon; // Record the last coupon redeemed of the bond
}

contract Bond is Ownable, ReentrancyGuard {
    using PRBMathUD60x18 for uint256;
    using SafeERC20 for IERC20;

    /*************************
     **    MAIN VARIABLE     **
     *************************/

    address public immutable iRIS; // iRIS token -- governance token
    address public immutable treasury; // Team treasury to collect fees

    Sale public sale; // main contract of bond sale
    BondFeature public bond; // main control variable of the bond
    Debt public debt; // the current debt of the bond
    mapping(address => Share) public holder; // information of each share

    constructor(address iRIS_, address treasury_) {
        iRIS = iRIS_;
        treasury = treasury_;
    }

    /*************************
     **    HELPER SECTION    **
     *************************/

    event BondInitialized(BondFeature _bond);
    event SaleInitialized(Sale _sale);
    event NewBondPurchased(address _purchaser, uint256 _amount);
    event BondRedeemed(
        address _purchaser,
        uint256 _baseAmount,
        uint256 _convertAmount
    );

    modifier validPurchaser() {
        _;
    }

    modifier bondHadSet() {
        require(bond.hadSet, "bond not finish setting");
        require(sale.saleStart != 0, "bond sale start not set");
        require(sale.saleEnd != 0, "bond offset not set");
        _;
    }

    /*************************
     **     USER SECTION    **
     *************************/

    function payDebt(uint256 _baseAmount, uint256 _convertibleAmount)
        external
        bondHadSet
        nonReentrant
    {
        require(
            msg.sender == bond.issuer,
            "Make sure the one paying is issuer"
        );
        require(debt.baseDebt <= _baseAmount, "Pay too many base token");
        require(
            debt.convertibleDebt <= _convertibleAmount,
            "Pay too many convertible token"
        );

        IERC20(bond.baseToken).safeTransfer(msg.sender, _baseAmount);
        IERC20(bond.convertibleToken).safeTransfer(
            msg.sender,
            _convertibleAmount
        );

        debt = Debt({
            baseDebt: debt.baseDebt - _baseAmount,
            convertibleDebt: debt.convertibleDebt - _convertibleAmount
        });
    }

    function purchaseBond(uint256 _amount)
        external
        validPurchaser
        bondHadSet
        nonReentrant
    {
        require(msg.sender != address(0), "address is valid");
        require(_amount >= bond.minShare, "require larger share");
        require(
            _amount + sale.totalPrinciple <= bond.maxPrinciple,
            "exceed maximum selling limit"
        );

        require(block.number >= sale.saleStart, "Sale hasn't started");
        require(block.number <= sale.saleEnd, "Sale has ended");

        address _baseToken = bond.baseToken;

        // transfer fund to conrtact after calling "safeIncreaseAllowance"
        IERC20(_baseToken).safeTransferFrom(msg.sender, address(this), _amount);

        // update total principle purchased of the bond
        sale.totalPrinciple += _amount;

        // Update purchasedPrinciple and convertPrecent of the share
        Share memory _holder = holder[msg.sender];

        uint256 newConvertPrecent = (_holder.purchasedPrinciple.mul(
            _holder.convertPrecent
        ) / (_amount + _holder.purchasedPrinciple)) * 1e18;

        holder[msg.sender] = Share({
            purchasedPrinciple: (_amount + _holder.purchasedPrinciple),
            convertPrecent: newConvertPrecent,
            lastRedeemCoupon: 0
        });

        // Update debt information
        uint256 _convertibleDebt = _amount.mul(newConvertPrecent);
        uint256 _baseDebt = _amount - _convertibleDebt;

        debt = Debt({
            baseDebt: debt.baseDebt + _baseDebt,
            convertibleDebt: debt.convertibleDebt + _convertibleDebt
        });

        emit NewBondPurchased(msg.sender, _amount);
    }

    function redeemBond() external bondHadSet nonReentrant {
        require(
            holder[msg.sender].purchasedPrinciple != 0,
            "didn't purchase the bond"
        );

        Share memory _holder = holder[msg.sender];

        // calculate the redeemable coupon
        uint256 totalRedeemable = (block.number - sale.saleEnd) /
            bond.couponInterval;
        uint256 newlyRedeemable = totalRedeemable - _holder.lastRedeemCoupon;

        // record total payout in the interval
        uint256 payout = 0;

        // if new coupon is receivable
        if (newlyRedeemable > 0) {
            payout +=
                newlyRedeemable *
                _holder.purchasedPrinciple.mul(bond.couponRate);
        }

        // if all coupon is redeemed, payback the principle
        if (totalRedeemable > bond.couponTime) {
            payout += _holder.purchasedPrinciple;
            delete holder[msg.sender];
            payoutBond(msg.sender, payout, _holder.convertPrecent);
        } else {
            holder[msg.sender].lastRedeemCoupon = totalRedeemable;
            payoutBond(msg.sender, payout, _holder.convertPrecent);
        }
    }

    function maturityDate() external view bondHadSet returns (uint256) {
        return sale.saleEnd + bond.couponInterval * bond.couponTime;
    }

    /*************************
     **   INTERNAL SECTION  **
     *************************/

    function payoutBond(
        address _purchaser,
        uint256 _amount,
        uint256 _convertPercent
    ) internal {
        if (_convertPercent == 0) {
            IERC20(bond.baseToken).safeTransfer(_purchaser, _amount);

            emit BondRedeemed(_purchaser, _amount, 0);
        } else {
            uint256 convertPayout = _amount.mul(_convertPercent).mul(
                bond.convertRatio
            );
            uint256 basePayout = _amount - convertPayout;

            IERC20(bond.baseToken).safeTransfer(_purchaser, basePayout);
            IERC20(bond.convertibleToken).safeTransfer(
                _purchaser,
                convertPayout
            );

            emit BondRedeemed(_purchaser, basePayout, convertPayout);
        }
    }

    /*************************
     **     ADMIN SECTION    **
     *************************/

    /// @notice Initialization for Bond Feature
    /// @dev    if convertiable is false, convertibleToken should be address(0)
    function initializaBondFeature(
        bool _convertible,
        address _issuer,
        address _baseToken,
        address _convertibleToken,
        uint256 _maxPrinciple,
        uint256 _couponRate,
        uint256 _couponInterval,
        uint256 _couponTime,
        uint256 _convertRatio,
        uint256 _minShare
    ) external onlyOwner {
        require(!bond.hadSet, "double setting");
        require(
            (_convertible ||
                (!_convertible &&
                    _convertibleToken == address(0) &&
                    _convertRatio != 0)),
            "mismatch conversion setting"
        );
        require(
            (_issuer != address(0) &&
                _baseToken != address(0) &&
                _maxPrinciple != 0 &&
                _couponRate != 0 &&
                _couponInterval != 0 &&
                _couponTime != 0 &&
                _minShare != 0),
            "invalid bond parameters"
        );

        bond = BondFeature({
            hadSet: true,
            convertible: _convertible,
            issuer: _issuer,
            baseToken: _baseToken,
            convertibleToken: _convertibleToken,
            maxPrinciple: _maxPrinciple,
            couponRate: _couponRate,
            couponInterval: _couponInterval,
            couponTime: _couponTime,
            convertRatio: _convertRatio,
            minShare: _minShare
        });

        emit BondInitialized(bond);
    }

    function initializeSale(uint256 _saleStart, uint256 _saleEnd)
        external
        onlyOwner
    {
        require(_saleStart > block.number, "Start should be greater");
        require(_saleEnd > _saleStart, "End should be greater");

        sale = Sale({
            saleStart: _saleStart,
            saleEnd: _saleEnd,
            totalPrinciple: 0
        });

        emit SaleInitialized(sale);
    }
}
