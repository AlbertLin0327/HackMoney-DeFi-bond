//SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.10;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract veiRIStoken is ERC20, Ownable, ReentrancyGuard {
    /*************************
     **    MAIN VARIABLE     **
     *************************/

    address public immutable iRIS;
    address public stakingContract;

    constructor(address iRIS_) ERC20("Vote Escrowed iRIS Token", "veiRIS") {
        iRIS = iRIS_;
    }

    /*************************
     **    HELPER SECTION    **
     *************************/

    modifier onlyStakingContract() {
        require(stakingContract != address(0), "staking contract not set");
        require(msg.sender == stakingContract, "mismathc sender");
        _;
    }

    /*************************
     **    ADMIN SECTION    **
     *************************/

    function mint(address _account, uint256 _amount)
        external
        onlyStakingContract
    {
        _mint(_account, _amount);
    }

    function burn(address _account, uint256 _amount)
        external
        onlyStakingContract
    {
        _mint(_account, _amount);
    }

    function setStakingContract(address _newAddress) external onlyOwner {
        stakingContract = _newAddress;
    }

    /*************************
     **   INTERNAL SECTION  **
     *************************/

    // non-transferable
    function transfer(address recipient, uint256 amount)
        public
        virtual
        override
        returns (bool)
    {
        recipient;
        amount;
        revert("NOT_SUPPORTED");
    }

    function allowance(address owner, address spender)
        public
        view
        virtual
        override
        returns (uint256)
    {
        owner;
        spender;
        revert("NOT_SUPPORTED");
    }

    function approve(address spender, uint256 amount)
        public
        virtual
        override
        returns (bool)
    {
        spender;
        amount;
        revert("NOT_SUPPORTED");
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual override returns (bool) {
        sender;
        recipient;
        amount;
        revert("NOT_SUPPORTED");
    }

    function increaseAllowance(address spender, uint256 addedValue)
        public
        virtual
        override
        returns (bool)
    {
        spender;
        addedValue;
        revert("NOT_SUPPORTED");
    }

    function decreaseAllowance(address spender, uint256 subtractedValue)
        public
        virtual
        override
        returns (bool)
    {
        spender;
        subtractedValue;
        revert("NOT_SUPPORTED");
    }
}
