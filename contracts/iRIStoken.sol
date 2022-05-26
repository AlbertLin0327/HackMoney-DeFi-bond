//SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.10;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract iRIStoken is ERC20, Ownable, ReentrancyGuard {
    constructor() ERC20("iRIS Token", "iRIS") {}

    function mint(address _account, uint256 _amount) external onlyOwner {
        _mint(_account, _amount);
    }

    function burn(uint256 _amount) external {
        _burn(msg.sender, _amount);
    }

    function burnFrom(address _account, uint256 _amount) external {
        _burnFrom(_account, _amount);
    }

    function _burnFrom(address _account, uint256 _amount) internal {
        uint256 decreasedAllowance_ = allowance(_account, msg.sender) - _amount;

        _approve(_account, msg.sender, decreasedAllowance_);
        _burn(_account, _amount);
    }
}
