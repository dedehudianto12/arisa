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

    // Enums
    enum GroupStatus {
        ACTIVE,
        COMPLETED,
        CANCELLED
    }
    enum MemberStatus {
        ACTIVE,
        PENALIZED,
        REMOVED
    }

    // Structs
    struct Group {
        uint256 groupId;
        address admin;
        uint256 maxMembers;
        uint256 paymentDeadline;
        bool isPublic;
        GroupStatus status;
        uint256 memberCount;
        uint256 createdAt;
        uint256 currentRound;
        uint256 contributionAmount;
        address[] members;
        address[] membersRotationOrder;
    }

    struct Member {
        address memberAddress;
        uint256 joinedAt;
        uint256 contributionCount;
        uint256 missedPayments;
        uint256 totalPenalty;
        bool hasReceived;
        uint256 receivedAt;
        MemberStatus status;
    }

    struct Payment {
        uint256 round;
        uint256 totalAmount;
        uint256 yieldEarned;
        address recipient;
        uint256 timestamp;
        bool isProcessed;
    }

    // Mappings
    mapping(uint256 => Group) public groups;
    mapping(uint256 => mapping(address => Member)) public members;
    mapping(uint256 => mapping(uint256 => Payment)) public payments;
    mapping(address => uint256[]) public memberGroups;

    constructor(address _usdcToken) Ownable(msg.sender) {
        usdcToken = IERC20(_usdcToken);
        groupCounter = 0;
        totalActiveGroups = 0;
    }
}
