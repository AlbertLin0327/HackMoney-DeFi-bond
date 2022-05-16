//SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.10;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Staking is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
}
