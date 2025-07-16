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

    // Constructor
    constructor(address _usdcToken) Ownable(msg.sender) {
        usdcToken = IERC20(_usdcToken);
        groupCounter = 0;
        totalActiveGroups = 0;
    }

    // Events
    event GroupCreated(
        uint256 indexed groupId,
        address indexed admin,
        uint256 maxMembers,
        bool isPublic
    );
    event MemberJoined(
        uint256 indexed groupId,
        address indexed membe,
        uint256 joinedAt
    );
    event MemberInvited(
        uint256 indexed groupId,
        address indexed member,
        address indexed invitedBy
    );
    event ContributionMade(
        uint256 indexed groupId,
        address indexed member,
        uint256 amount,
        uint256 round
    );
    event PaymentProcessed(
        uint256 indexed groupId,
        address indexed recipient,
        uint256 amount,
        uint256 round
    );
    event PenaltyApplied(
        uint256 indexed groupId,
        address indexed member,
        uint256 penaltyAmount
    );
    event GroupCompleted(uint256 indexed groupId, uint256 totalRounds);
    event GroupCancelled(uint256 indexed groupId, address indexed admin);
    event YieldEarned(uint256 indexed groupId, uint256 yieldAmount);

    // Modifiers
    modifier onlyGroupAdmin(uint256 _groupId) {
        require(groups[_groupId].admin == msg.sender, "Not group admin");
        _;
    }

    modifier onlyGroupMember(uint256 _groupId) {
        require(
            members[_groupId][msg.sender].wallet != address(0),
            "Not a member"
        );
        _;
    }

    modifier groupExists(uint256 _groupId) {
        require(
            _groupId > 0 && _groupId <= groupCounter,
            "Group does not exist"
        );
        _;
    }

    modifier groupActive(uint256 _groupId) {
        require(
            groups[_groupId].status == GroupStatus.Active,
            "Group not active"
        );
        _;
    }

    modifier validContribution(uint256 _groupId) {
        require(
            msg.value == groups[_groupId].contributionAmount,
            "Invalid contribution amount"
        );
        _;
    }

    modifier withinGracePeriod(uint256 _groupId) {
        // Check if current time is within grace period for current round
        _;
    }

    modifier hasNotReceived(uint256 _groupId) {
        require(
            !members[_groupId][msg.sender].hasReceived,
            "Already received payout"
        );
        _;
    }
}
