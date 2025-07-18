// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {ArisanContract} from "../src/ArisanContract.sol";
import {Test, console} from "forge-std/Test.sol";
import {MockUSDC} from "./mocks/MockUSDC.sol";

contract ArisanTest is Test {
    MockUSDC public usdc;
    ArisanContract public arisan;

    function setUp() public {
        usdc = new MockUSDC();
        arisan = new ArisanContract(address(usdc));
    }

    // Test Group Creation;
    function test_CreateGroup_Success() public {
        address admin = makeAddr("admin");
        uint256 maxMembers = 10;
        uint256 paymentDeadline = block.timestamp + 7 days;
        bool isPublic = true;
        uint256 contributionAmount = 10e6;

        vm.startPrank(admin);
        vm.expectEmit(true, true, true, true);
        emit ArisanContract.GroupCreated(1, admin, 10, isPublic);
        arisan.createGroup(
            maxMembers,
            paymentDeadline,
            isPublic,
            contributionAmount
        );
        vm.stopPrank();

        ArisanContract.Group memory group = arisan.getGroup(1);
        assertEq(group.admin, admin);
        assertEq(group.memberCount, 1);

        address[] memory members = arisan.getGroupMembers(1);
        assertEq(members.length, 1);
        assertEq(members[0], admin);

        ArisanContract.Member memory member = arisan.getMember(1, admin);
        assertEq(member.memberAddress, admin);
        assertFalse(member.hasReceived);
    }

    function test_CreateGroup_FailsWhenPastDeadline() public {
        address admin = makeAddr("admin");
        uint256 maxMembers = 10;
        bool isPublic = true;
        uint256 contributionAmount = 10e6;
        vm.warp(1 days);

        uint256 paymentDeadline = block.timestamp - 1 days;

        vm.startPrank(admin);

        vm.expectRevert("Invalid payment deadline");
        arisan.createGroup(
            maxMembers,
            paymentDeadline,
            isPublic,
            contributionAmount
        );

        vm.stopPrank();
    }

    function test_CreateGroup_FailsWithInvalidMaxMembers() public {
        address admin = makeAddr("admin");
        uint256 maxMembers = 20; // Invalid max members
        uint256 paymentDeadline = block.timestamp + 7 days;
        bool isPublic = true;
        uint256 contributionAmount = 10e6;

        vm.startPrank(admin);

        vm.expectRevert("Invalid max members");
        arisan.createGroup(
            maxMembers,
            paymentDeadline,
            isPublic,
            contributionAmount
        );

        vm.stopPrank();
    }

    function test_CreateGroup_FailsWithZeroContribution() public {
        address admin = makeAddr("admin");
        uint256 maxMembers = 10;
        uint256 paymentDeadline = block.timestamp + 7 days;
        bool isPublic = true;
        uint256 contributionAmount = 0; // Zero contribution

        vm.startPrank(admin);

        vm.expectRevert("Invalid contribution amount");
        arisan.createGroup(
            maxMembers,
            paymentDeadline,
            isPublic,
            contributionAmount
        );

        vm.stopPrank();
    }

    function test_CreateGroup_EmitsCorrectEvent() public {
        address admin = makeAddr("admin");
        uint256 maxMembers = 10;
        uint256 paymentDeadline = block.timestamp + 7 days;
        bool isPublic = true;
        uint256 contributionAmount = 10e6;

        vm.startPrank(admin);
        vm.expectEmit(true, true, true, true);
        emit ArisanContract.GroupCreated(1, admin, maxMembers, isPublic);
        arisan.createGroup(
            maxMembers,
            paymentDeadline,
            isPublic,
            contributionAmount
        );
        vm.stopPrank();
    }

    // Test Joining Group
    function test_JoinGroup_Success() public {
        address admin = makeAddr("admin");
        uint256 maxMembers = 10;
        uint256 paymentDeadline = block.timestamp + 7 days;
        bool isPublic = true;
        uint256 contributionAmount = 10e6;

        vm.startPrank(admin);
        arisan.createGroup(
            maxMembers,
            paymentDeadline,
            isPublic,
            contributionAmount
        );
        vm.stopPrank();

        address member = makeAddr("member");
        vm.startPrank(member);
        vm.expectEmit(true, true, true, true);
        emit ArisanContract.MemberJoined(1, member, block.timestamp);
        arisan.joinGroup(1);
        vm.stopPrank();

        address[] memory members = arisan.getGroupMembers(1);
        assertEq(
            members[1],
            member,
            "Second member should be the one who joined"
        );

        ArisanContract.Member memory m = arisan.getMember(1, member);
        assertEq(m.memberAddress, member, "Member address mismatch");
        assertEq(
            uint256(m.status),
            uint256(ArisanContract.MemberStatus.ACTIVE),
            "Member status mismatch"
        );
        assertEq(m.contributionCount, 0, "Should not have contributed yet");
        assertFalse(m.hasReceived, "Should not have received payout yet");
    }

    function test_JoinGroup_FailsWithNonExistentGroup() public {
        address member = makeAddr("member");
        vm.startPrank(member);

        vm.expectRevert("Group does not exist");
        arisan.joinGroup(999);

        vm.stopPrank();
    }

    function test_JoinGroup_FailsWithInactiveGroup() public {
        address admin = makeAddr("admin");
        uint256 maxMembers = 10;
        uint256 paymentDeadline = block.timestamp + 7 days;
        bool isPublic = true;
        uint256 contributionAmount = 10e6;

        vm.startPrank(admin);
        arisan.createGroup(
            maxMembers,
            paymentDeadline,
            isPublic,
            contributionAmount
        );

        arisan.setGroupStatus(1, ArisanContract.GroupStatus.CANCELLED);
        vm.stopPrank();

        address member = makeAddr("member");
        vm.startPrank(member);
        vm.expectRevert("Group not active");
        arisan.joinGroup(1);
        vm.stopPrank();
    }

    function test_JoinGroup_FailsWithFullGroup() public {
        address admin = makeAddr("admin");
        uint256 maxMembers = 2;
        uint256 paymentDeadline = block.timestamp + 7 days;
        bool isPublic = true;
        uint256 contributionAmount = 10e6;

        vm.startPrank(admin);
        arisan.createGroup(
            maxMembers,
            paymentDeadline,
            isPublic,
            contributionAmount
        );
        vm.stopPrank();

        address member1 = makeAddr("member1");
        vm.startPrank(member1);
        arisan.joinGroup(1);
        vm.stopPrank();

        address member2 = makeAddr("member2");
        vm.startPrank(member2);
        vm.expectRevert("Group is full");
        arisan.joinGroup(1);
        vm.stopPrank();
    }

    function test_JoinGroup_FailsWithExistingMember() public {
        address admin = makeAddr("admin");
        uint256 maxMembers = 10;
        uint256 paymentDeadline = block.timestamp + 7 days;
        bool isPublic = true;
        uint256 contributionAmount = 10e6;

        vm.startPrank(admin);
        arisan.createGroup(
            maxMembers,
            paymentDeadline,
            isPublic,
            contributionAmount
        );
        vm.stopPrank();

        address member = makeAddr("member");
        vm.startPrank(member);
        arisan.joinGroup(1);
        vm.stopPrank();

        vm.startPrank(member);
        vm.expectRevert("Already a member");
        arisan.joinGroup(1);
        vm.stopPrank();
    }

    // Test Invite to Group
    function test_InviteToGroup_Success() public {
        address admin = makeAddr("admin");
        uint256 maxMembers = 10;
        uint256 paymentDeadline = block.timestamp + 7 days;
        bool isPublic = true;
        uint256 contributionAmount = 10e6;

        vm.startPrank(admin);
        arisan.createGroup(
            maxMembers,
            paymentDeadline,
            isPublic,
            contributionAmount
        );
        vm.stopPrank();

        address invitee = makeAddr("invitee");
        vm.startPrank(admin);
        vm.expectEmit(true, true, true, true);
        emit ArisanContract.MemberInvited(1, invitee, admin);
        arisan.inviteToGroup(1, invitee);
        vm.stopPrank();

        address[] memory members = arisan.getGroupMembers(1);
        assertEq(members[1], invitee, "Invitee should be added to group");
        assertEq(members.length, 2, "Group should have two members");

        ArisanContract.Member memory invitedMember = arisan.getMember(
            1,
            invitee
        );
        assertEq(
            invitedMember.memberAddress,
            invitee,
            "Invitee address mismatch"
        );
    }

    function test_InviteToGroup_NotAdmin() public {
        address admin = makeAddr("admin");
        uint256 maxMembers = 10;
        uint256 paymentDeadline = block.timestamp + 7 days;
        bool isPublic = true;
        uint256 contributionAmount = 10e6;

        vm.startPrank(admin);
        arisan.createGroup(
            maxMembers,
            paymentDeadline,
            isPublic,
            contributionAmount
        );
        vm.stopPrank();

        address nonAdmin = makeAddr("nonAdmin");
        address invitee = makeAddr("invitee");

        vm.startPrank(nonAdmin);
        vm.expectRevert("Not group admin");
        arisan.inviteToGroup(1, invitee);
        vm.stopPrank();

        address[] memory members = arisan.getGroupMembers(1);
        assertEq(members.length, 1, "Group should still have one members");
        assertEq(
            members[0],
            admin,
            "Admin should be the only member of the group"
        );
    }

    function test_InviteToGroup_AlreadyMember() public {
        // Try to invite existing member
        address admin = makeAddr("admin");
        uint256 maxMembers = 10;
        uint256 paymentDeadline = block.timestamp + 7 days;
        bool isPublic = true;
        uint256 contributionAmount = 10e6;

        vm.startPrank(admin);
        arisan.createGroup(
            maxMembers,
            paymentDeadline,
            isPublic,
            contributionAmount
        );
        vm.stopPrank();

        address invitee = makeAddr("invitee");
        vm.startPrank(admin);
        arisan.inviteToGroup(1, invitee);
        vm.stopPrank();

        vm.startPrank(admin);
        vm.expectRevert("Already a member");
        arisan.inviteToGroup(1, invitee);
        vm.stopPrank();

        address[] memory members = arisan.getGroupMembers(1);
        assertEq(members.length, 2, "Group should still have two members");
        assertEq(members[1], invitee, "Invitee should still be in group");
    }

    // Test Leaving Group
    function test_LeaveGroup_Success() public {
        // Create group, join, then leave
        // Check: member removed from arrays, memberCount decreased
        address admin = makeAddr("admin");
        uint256 maxMembers = 10;
        uint256 paymentDeadline = block.timestamp + 7 days;
        bool isPublic = true;
        uint256 contributionAmount = 10e6;

        vm.startPrank(admin);
        arisan.createGroup(
            maxMembers,
            paymentDeadline,
            isPublic,
            contributionAmount
        );
        vm.stopPrank();

        address member = makeAddr("member");
        vm.startPrank(member);
        arisan.joinGroup(1);
        vm.stopPrank();

        vm.startPrank(member);
        vm.expectEmit(true, true, true, true);
        emit ArisanContract.MemberLeft(1, member);
        arisan.leaveGroup(1);
        vm.stopPrank();

        address[] memory members = arisan.getGroupMembers(1);
        assertEq(members.length, 1, "Group should have one member left");
        assertEq(members[0], admin, "Admin should be the only member left");
    }

    function test_LeaveGroup_LastMember() public {
        // Try to leave when you're the only member
        address admin = makeAddr("admin");
        uint256 maxMembers = 10;
        uint256 paymentDeadline = block.timestamp + 7 days;
        bool isPublic = true;
        uint256 contributionAmount = 10e6;

        vm.startPrank(admin);
        arisan.createGroup(
            maxMembers,
            paymentDeadline,
            isPublic,
            contributionAmount
        );
        vm.stopPrank();

        vm.startPrank(admin);
        vm.expectRevert("Admin cannot leave group");
        arisan.leaveGroup(1);
        vm.stopPrank();
    }

    function test_LeaveGroup_NotInGroup() public {
        // Try to leave when you're the only member
        address admin = makeAddr("admin");
        uint256 maxMembers = 10;
        uint256 paymentDeadline = block.timestamp + 7 days;
        bool isPublic = true;
        uint256 contributionAmount = 10e6;

        vm.startPrank(admin);
        arisan.createGroup(
            maxMembers,
            paymentDeadline,
            isPublic,
            contributionAmount
        );
        vm.stopPrank();

        address nonMember = makeAddr("nonMember");
        vm.startPrank(nonMember);
        vm.expectRevert("Not a member");
        arisan.leaveGroup(1);
        vm.stopPrank();
    }
}
