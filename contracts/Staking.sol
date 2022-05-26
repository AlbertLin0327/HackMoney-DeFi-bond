//SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.10;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IveIRIS is IERC20 {
    function mint(address _account, uint256 _amount) external;

    function burn(address _account, uint256 _amount) external;
}

contract Staking is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /*************************
     **    MAIN VARIABLE     **
     *************************/

    address public iRIS;
    address public veiRIS;
    mapping(address => uint256) staker;

    mapping(address => bool) bonds;
    mapping(address => uint256) lockAmount;

    constructor() {}

    /*************************
     **   INTERNAL SECTION  **
     *************************/

    modifier onlyBond() {
        require(bonds[msg.sender], "not bonds");
        _;
    }

    /*************************
     **     USER SECTION    **
     *************************/

    function stake(uint256 _amount, uint256 _term) external nonReentrant {
        require(_amount > 0, "amount greater that zero");
        require(_term < 4, "out of range");

        IERC20(iRIS).safeTransferFrom(msg.sender, address(this), _amount);

        if (staker[msg.sender] != 0) {
            staker[msg.sender] = _amount + staker[msg.sender];

            IveIRIS(veiRIS).mint(msg.sender, _amount);
        } else {
            staker[msg.sender] = _amount;

            IveIRIS(veiRIS).mint(msg.sender, _amount);
        }
    }

    function unstake(uint256 _amount) external nonReentrant {
        require(getLockable(msg.sender) >= _amount, "non-extractable");

        IveIRIS(veiRIS).burn(msg.sender, _amount);
        IERC20(iRIS).safeTransfer(msg.sender, _amount);
    }

    function lock(address _sender, uint256 _amount) external onlyBond {
        require(getLockable(_sender) >= _amount, "non-extractable");
        lockAmount[_sender] += _amount;
    }

    function unlock(address _sender, uint256 _amount) external onlyBond {
        require(lockAmount[_sender] >= _amount, "non-extractable");
        lockAmount[_sender] -= _amount;
    }

    function getLockable(address _sender) public view returns (uint256) {
        return staker[_sender] - lockAmount[_sender];
    }

    /*************************
     **    ADMIN SECTION    **
     *************************/

    function setVePair(address _iRIS, address _veiRIS) external onlyOwner {
        iRIS = _iRIS;
        veiRIS = _veiRIS;
    }

    function setBondAddress(address _bond, bool _state) external onlyOwner {
        bonds[_bond] = _state;
    }
}
