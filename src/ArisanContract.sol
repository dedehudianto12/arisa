// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ArisanContract is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    // Global State
    IERC20 public immutable usdcToken;
    uint256 public groupCounter;
    uint256 public totalActiveGroups;

    constructor(address _usdcToken) Ownable(msg.sender) {
        usdcToken = IERC20(_usdcToken);
        groupCounter = 0;
        totalActiveGroups = 0;
    }
}
