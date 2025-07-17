// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

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
    uint256 public constant groupMaxMembers = 15;

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

    event GroupStatusUpdated(uint256 indexed groupId, GroupStatus newStatus);

    event MemberJoined(
        uint256 indexed groupId,
        address indexed member,
        uint256 joinedAt
    );
    event MemberInvited(
        uint256 indexed groupId,
        address indexed member,
        address indexed invitedBy
    );
    event MemberLeft(uint256 indexed groupId, address indexed member);

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
            members[_groupId][msg.sender].memberAddress != address(0),
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
            groups[_groupId].status == GroupStatus.ACTIVE,
            "Group not active"
        );
        _;
    }

    modifier validContribution(uint256 _groupId) {
        require(
            usdcToken.allowance(msg.sender, address(this)) >=
                groups[_groupId].contributionAmount,
            "Invalid contribution amount"
        );
        _;
    }

    modifier withinGracePeriod(uint256 _groupId) {
        require(
            block.timestamp < groups[_groupId].paymentDeadline + 1 days,
            "Grace period ended"
        );
        _;
    }

    modifier hasNotReceived(uint256 _groupId) {
        require(
            !members[_groupId][msg.sender].hasReceived,
            "Already received payout"
        );
        _;
    }

    // Functions Group Management
    function createGroup(
        uint256 _maxMembers,
        uint256 _paymentDeadline,
        bool _isPublic,
        uint256 _contributionAmount
    ) external nonReentrant {
        require(_paymentDeadline > block.timestamp, "Invalid payment deadline");

        require(_maxMembers <= groupMaxMembers, "Invalid max members");

        require(_contributionAmount > 0, "Invalid contribution amount");

        groupCounter++;
        groups[groupCounter] = Group({
            groupId: groupCounter,
            admin: msg.sender,
            maxMembers: _maxMembers,
            paymentDeadline: _paymentDeadline,
            isPublic: _isPublic,
            status: GroupStatus.ACTIVE,
            memberCount: 0,
            createdAt: block.timestamp,
            currentRound: 0,
            contributionAmount: _contributionAmount,
            members: new address[](0),
            membersRotationOrder: new address[](0)
        });

        members[groupCounter][msg.sender] = Member({
            memberAddress: msg.sender,
            joinedAt: block.timestamp,
            contributionCount: 0,
            missedPayments: 0,
            totalPenalty: 0,
            hasReceived: false,
            receivedAt: 0,
            status: MemberStatus.ACTIVE
        });

        Group storage group = groups[groupCounter];
        group.members.push(msg.sender);
        group.membersRotationOrder.push(msg.sender);
        group.memberCount = 1;

        memberGroups[msg.sender].push(groupCounter);

        emit GroupCreated(groupCounter, msg.sender, _maxMembers, _isPublic);
    }

    function joinGroup(
        uint256 _groupId
    ) external nonReentrant groupExists(_groupId) groupActive(_groupId) {
        // Group storage group = groups[_groupId];
        require(
            groups[_groupId].memberCount < groups[_groupId].maxMembers,
            "Group is full"
        );

        require(
            members[_groupId][msg.sender].memberAddress == address(0),
            "Already a member"
        );

        members[_groupId][msg.sender] = Member({
            memberAddress: msg.sender,
            joinedAt: block.timestamp,
            contributionCount: 0,
            missedPayments: 0,
            totalPenalty: 0,
            hasReceived: false,
            receivedAt: 0,
            status: MemberStatus.ACTIVE
        });

        groups[_groupId].members.push(msg.sender);
        groups[_groupId].membersRotationOrder.push(msg.sender);
        groups[_groupId].memberCount++;
        memberGroups[msg.sender].push(_groupId);

        emit MemberJoined(_groupId, msg.sender, block.timestamp);
    }

    function inviteToGroup(
        uint256 _groupId,
        address _member
    )
        external
        nonReentrant
        groupExists(_groupId)
        groupActive(_groupId)
        onlyGroupAdmin(_groupId)
    {
        require(
            members[_groupId][_member].memberAddress == address(0),
            "Already a member"
        );

        members[_groupId][_member] = Member({
            memberAddress: _member,
            joinedAt: block.timestamp,
            contributionCount: 0,
            missedPayments: 0,
            totalPenalty: 0,
            hasReceived: false,
            receivedAt: 0,
            status: MemberStatus.ACTIVE
        });

        groups[_groupId].members.push(_member);
        groups[_groupId].membersRotationOrder.push(_member);
        groups[_groupId].memberCount++;
        memberGroups[msg.sender].push(_groupId);

        emit MemberInvited(_groupId, _member, msg.sender);
    }

    function leaveGroup(
        uint256 _groupId
    )
        external
        nonReentrant
        groupExists(_groupId)
        groupActive(_groupId)
        onlyGroupMember(_groupId)
    {
        Group storage group = groups[_groupId];
        Member storage member = members[_groupId][msg.sender];

        require(
            group.memberCount > 1,
            "Cannot leave group with only one member"
        );
        require(member.memberAddress != address(0), "Not a member");

        require(!member.hasReceived, "Cannot leave after receiving payout");

        delete members[_groupId][msg.sender];

        group.memberCount--;

        _removeAddressFromArray(msg.sender, group.members);
        _removeAddressFromArray(msg.sender, group.membersRotationOrder);

        _removeGroupIdFromArray(_groupId, memberGroups[msg.sender]);

        emit MemberLeft(_groupId, msg.sender);
    }

    function setGroupStatus(
        uint256 _groupId,
        GroupStatus _status
    ) external onlyGroupAdmin(_groupId) {
        groups[_groupId].status = _status;
    }

    // function for views
    function getGroup(uint256 _groupId) external view returns (Group memory) {
        return groups[_groupId];
    }

    function getMember(
        uint256 _groupId,
        address _member
    ) external view returns (Member memory) {
        return members[_groupId][_member];
    }

    function getMemberGroups(
        address _member
    ) external view returns (uint256[] memory) {
        return memberGroups[_member];
    }

    function getGroupMembers(
        uint256 _groupId
    ) external view returns (address[] memory) {
        return groups[_groupId].members;
    }

    function getUserGroups(
        address _user
    ) external view returns (uint256[] memory) {
        return memberGroups[_user];
    }

    function getGroupRotationOrder(
        uint256 _groupId
    ) external view returns (address[] memory) {
        return groups[_groupId].membersRotationOrder;
    }

    // Helper Functions
    function _removeAddressFromArray(
        address target,
        address[] storage array
    ) internal {
        for (uint256 i = 0; i < array.length; i++) {
            if (array[i] == target) {
                array[i] = array[array.length - 1]; // move last to deleted spot
                array.pop(); // remove last
                break;
            }
        }
    }

    function _removeGroupIdFromArray(
        uint256 groupId,
        uint256[] storage array
    ) internal {
        for (uint256 i = 0; i < array.length; i++) {
            if (array[i] == groupId) {
                array[i] = array[array.length - 1];
                array.pop();
                break;
            }
        }
    }
}
