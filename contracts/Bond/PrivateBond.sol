//SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.10;
import "./Bond.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

/// @title iRIS Bond main contract
/// @author hklin
/// @notice Every contract stands for one bond
/// @dev    Notice that this should be produce by an upgradable extension

contract PrivateBond is Bond {
    using PRBMathUD60x18 for uint256;
    using SafeERC20 for IERC20;
    using ECDSA for bytes32;

    /*************************
     **    MAIN VARIABLE     **
     *************************/

    bytes32 private merkleRoot;

    constructor(address iRIS_, address treasury_) Bond(iRIS_, treasury_) {}

    /*************************
     **    HELPER SECTION    **
     *************************/

    modifier validPurchaser(bytes32[] memory proof) {
        require(merkleRoot != "", "Free Claim merkle tree not set");
        require(
            MerkleProof.verify(
                proof,
                merkleRoot,
                keccak256(abi.encodePacked(msg.sender))
            ),
            "Free Claim validation failed"
        );
        _;
    }

    /*************************
     **     USER SECTION    **
     *************************/

    function purchaseBond(uint256 _amount, bytes32[] memory _proof)
        external
        validPurchaser(_proof)
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

        uint256 fee = bondFee(_amount);
        IERC20(_baseToken).safeTransfer(treasury, _amount);
        _amount -= fee;

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
        uint256 _incentive = _amount.mul(5e15);

        debt = Debt({
            baseDebt: debt.baseDebt + _baseDebt,
            convertibleDebt: debt.convertibleDebt + _convertibleDebt,
            incentive: debt.incentive + _incentive
        });

        emit NewBondPurchased(msg.sender, _amount);
    }

    /*************************
     **     USER SECTION    **
     *************************/

    function setMerkleRoot(bytes32 _newRoot) public onlyOwner {
        merkleRoot = _newRoot;
    }
}
