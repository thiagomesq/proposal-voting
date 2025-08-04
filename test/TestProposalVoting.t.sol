// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {DeployProposalVoting} from "script/DeployProposalVoting.s.sol";
import {ProposalVoting} from "src/ProposalVoting.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {Test} from "forge-std/Test.sol";

contract TestProposalVoting is Test {
    // Declare the contracts to be used in the tests
    DeployProposalVoting public deployer;
    ProposalVoting public proposalVoting;
    HelperConfig.NetworkConfig public config;

    // Users
    address private owner;
    address private user1;
    address private user2;
    address private nonOwner;

    // Test variables
    string constant PROPOSAL_TITLE = "Test Proposal";
    string constant PROPOSAL_DESCRIPTION = "This is a test proposal";
    uint256 constant VOTING_PERIOD = 7 days;

    //////////////////////////////////////////////
    // Events for testing
    //////////////////////////////////////////////

    event ProposalCreated(uint256 indexed id, string title, string description, uint256 creationDate);

    event VoteRecorded(uint256 indexed proposalId);

    event ProposalClosed(uint256 indexed proposalId, ProposalVoting.ProposalStatus status);

    event AutomationForwarderSet(address indexed forwarder);

    function setUp() public {
        deployer = new DeployProposalVoting();
        (proposalVoting, config) = deployer.run();

        owner = config.account;
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        nonOwner = makeAddr("nonOwner");
    }

    //////////////////////////////////////////////
    // Tests for proposal creation
    //////////////////////////////////////////////

    function testCreateProposal() public {
        vm.prank(user1);
        proposalVoting.createProposal(PROPOSAL_TITLE, PROPOSAL_DESCRIPTION);

        ProposalVoting.Proposal[] memory proposals = proposalVoting.getProposals();
        assertEq(proposals.length, 1);
        assertEq(proposals[0].id, 0);
        assertEq(proposals[0].title, PROPOSAL_TITLE);
        assertEq(proposals[0].description, PROPOSAL_DESCRIPTION);
        assertEq(proposals[0].votesFor, 0);
        assertEq(proposals[0].votesAgainst, 0);
        assertEq(uint256(proposals[0].status), uint256(ProposalVoting.ProposalStatus.PENDING));
        assertEq(proposals[0].creationDate, block.timestamp);
    }

    function testCreateProposalEmitEvent() public {
        vm.expectEmit(true, false, false, true);
        emit ProposalCreated(0, PROPOSAL_TITLE, PROPOSAL_DESCRIPTION, block.timestamp);

        vm.prank(user1);
        proposalVoting.createProposal(PROPOSAL_TITLE, PROPOSAL_DESCRIPTION);
    }

    function testCreateProposalRevertEmptyTitle() public {
        vm.expectRevert(ProposalVoting.ProposalVoting__TitleOrDescriptionEmpty.selector);
        vm.prank(user1);
        proposalVoting.createProposal("", PROPOSAL_DESCRIPTION);
    }

    function testCreateProposalRevertEmptyDescription() public {
        vm.expectRevert(ProposalVoting.ProposalVoting__TitleOrDescriptionEmpty.selector);
        vm.prank(user1);
        proposalVoting.createProposal(PROPOSAL_TITLE, "");
    }

    function testCreateMultipleProposals() public {
        vm.prank(user1);
        proposalVoting.createProposal("Proposal 1", "Description 1");

        vm.prank(user2);
        proposalVoting.createProposal("Proposal 2", "Description 2");

        ProposalVoting.Proposal[] memory proposals = proposalVoting.getProposals();
        assertEq(proposals.length, 2);
        assertEq(proposals[0].id, 0);
        assertEq(proposals[1].id, 1);
    }

    //////////////////////////////////////////////
    // Tests for voting functionality
    //////////////////////////////////////////////

    function testVoteForProposal() public {
        vm.prank(user1);
        proposalVoting.createProposal(PROPOSAL_TITLE, PROPOSAL_DESCRIPTION);

        vm.prank(user2);
        bool support = true;
        proposalVoting.vote(0, support);

        ProposalVoting.Proposal[] memory proposals = proposalVoting.getProposals();
        assertEq(proposals[0].votesFor, 1);
        assertEq(proposals[0].votesAgainst, 0);
    }

    function testVoteAgainstProposal() public {
        vm.prank(user1);
        proposalVoting.createProposal(PROPOSAL_TITLE, PROPOSAL_DESCRIPTION);

        vm.prank(user2);
        bool support = false;
        proposalVoting.vote(0, support);

        ProposalVoting.Proposal[] memory proposals = proposalVoting.getProposals();
        assertEq(proposals[0].votesFor, 0);
        assertEq(proposals[0].votesAgainst, 1);
    }

    function testVoteEmitEvent() public {
        vm.prank(user1);
        proposalVoting.createProposal(PROPOSAL_TITLE, PROPOSAL_DESCRIPTION);

        vm.expectEmit(true, false, false, false);
        emit VoteRecorded(0);

        vm.prank(user2);
        bool support = true;
        proposalVoting.vote(0, support);
    }

    function testVoteRevertNonExistentProposal() public {
        vm.expectRevert(abi.encodeWithSelector(ProposalVoting.ProposalVoting__ProposalNotFound.selector, 0));
        vm.prank(user1);
        bool support = true;
        proposalVoting.vote(0, support);
    }

    function testVoteRevertAlreadyVoted() public {
        vm.prank(user1);
        proposalVoting.createProposal(PROPOSAL_TITLE, PROPOSAL_DESCRIPTION);

        vm.prank(user2);
        bool support = true;
        proposalVoting.vote(0, support);

        vm.expectRevert(abi.encodeWithSelector(ProposalVoting.ProposalVoting__AlreadyVoted.selector, 0));
        vm.prank(user2);
        support = false; // Trying to vote again
        proposalVoting.vote(0, support);
    }

    function testVoteRevertVotingPeriodEnded() public {
        vm.prank(user1);
        proposalVoting.createProposal(PROPOSAL_TITLE, PROPOSAL_DESCRIPTION);

        // Fast forward past voting period
        vm.warp(block.timestamp + VOTING_PERIOD + 1);

        vm.expectRevert(abi.encodeWithSelector(ProposalVoting.ProposalVoting__VotingAlreadyEnded.selector, 0));
        vm.prank(user2);
        bool support = true;
        proposalVoting.vote(0, support);
    }

    function testMultipleUsersVoting() public {
        vm.prank(user1);
        proposalVoting.createProposal(PROPOSAL_TITLE, PROPOSAL_DESCRIPTION);

        vm.prank(user1);
        bool support = true;
        proposalVoting.vote(0, support);

        vm.prank(user2);
        support = false;
        proposalVoting.vote(0, support);

        ProposalVoting.Proposal[] memory proposals = proposalVoting.getProposals();
        assertEq(proposals[0].votesFor, 1);
        assertEq(proposals[0].votesAgainst, 1);
    }

    //////////////////////////////////////////////
    // Tests for automation forwarder
    //////////////////////////////////////////////

    function testSetAutomationForwarder() public {
        address forwarder = makeAddr("forwarder");

        vm.prank(owner);
        proposalVoting.setAutomationForwarder(forwarder);

        // Test that the forwarder was set by trying to perform upkeep
        vm.expectRevert(ProposalVoting.ProposalVoting__InvalidForwarderAddress.selector);
        vm.prank(nonOwner);
        proposalVoting.performUpkeep("");
    }

    function testSetAutomationForwarderEmitEvent() public {
        address forwarder = makeAddr("forwarder");

        // Expect the event to be emitted when setting the forwarder
        vm.expectEmit(true, false, false, false);
        emit AutomationForwarderSet(forwarder);

        vm.prank(owner);
        proposalVoting.setAutomationForwarder(forwarder);
    }

    function testSetAutomationForwarderRevertNotOwner() public {
        address forwarder = makeAddr("forwarder");

        vm.expectRevert(ProposalVoting.ProposalVoting__NotAuthorized.selector);
        vm.prank(nonOwner);
        proposalVoting.setAutomationForwarder(forwarder);
    }

    function testSetAutomationForwarderRevertZeroAddress() public {
        vm.expectRevert(ProposalVoting.ProposalVoting__InvalidForwarderAddress.selector);
        vm.prank(owner);
        proposalVoting.setAutomationForwarder(address(0));
    }

    //////////////////////////////////////////////
    // Tests for checkUpkeep
    //////////////////////////////////////////////

    function testCheckUpkeepNoProposals() public view {
        (bool upkeepNeeded, bytes memory performData) = proposalVoting.checkUpkeep("");
        assertFalse(upkeepNeeded);
        assertEq(performData.length, 0);
    }

    function testCheckUpkeepNoPendingProposals() public {
        // Create a proposal but don't close it naturally
        vm.prank(user1);
        proposalVoting.createProposal(PROPOSAL_TITLE, PROPOSAL_DESCRIPTION);

        (bool upkeepNeeded, bytes memory performData) = proposalVoting.checkUpkeep("");
        assertFalse(upkeepNeeded);
        assertEq(performData.length, 0);
    }

    function testCheckUpkeepWithExpiredProposal() public {
        vm.prank(user1);
        proposalVoting.createProposal(PROPOSAL_TITLE, PROPOSAL_DESCRIPTION);

        // Fast forward past voting period
        vm.warp(block.timestamp + VOTING_PERIOD + 1);

        (bool upkeepNeeded, bytes memory performData) = proposalVoting.checkUpkeep("");
        assertTrue(upkeepNeeded);
        assertTrue(performData.length > 0);
    }

    //////////////////////////////////////////////
    // Tests for performUpkeep
    //////////////////////////////////////////////

    function testPerformUpkeepRevertForwarderNotSet() public {
        vm.expectRevert(ProposalVoting.ProposalVoting__ForwarderAddressNotSet.selector);
        proposalVoting.performUpkeep("");
    }

    function testPerformUpkeepRevertInvalidForwarder() public {
        address forwarder = makeAddr("forwarder");
        vm.prank(owner);
        proposalVoting.setAutomationForwarder(forwarder);

        vm.expectRevert(ProposalVoting.ProposalVoting__InvalidForwarderAddress.selector);
        vm.prank(nonOwner);
        proposalVoting.performUpkeep("");
    }

    function testPerformUpkeepApproveProposal() public {
        address forwarder = makeAddr("forwarder");
        vm.prank(owner);
        proposalVoting.setAutomationForwarder(forwarder);

        vm.prank(user1);
        proposalVoting.createProposal(PROPOSAL_TITLE, PROPOSAL_DESCRIPTION);

        // Vote for the proposal
        vm.prank(user1);
        bool support = true;
        proposalVoting.vote(0, support);

        vm.prank(user2);
        support = true;
        proposalVoting.vote(0, support);

        // Fast forward past voting period
        vm.warp(block.timestamp + VOTING_PERIOD + 1);

        // Prepare performData with proposal IDs to close
        uint256[] memory proposalsToClose = new uint256[](1);
        proposalsToClose[0] = 0;
        bytes memory performData = abi.encode(proposalsToClose);

        // Expect the event to be emitted when closing the proposal
        vm.expectEmit(true, false, false, true);
        emit ProposalClosed(0, ProposalVoting.ProposalStatus.APPROVED);

        // Perform upkeep to close the proposal
        vm.prank(forwarder);
        proposalVoting.performUpkeep(performData);

        // Verify the proposal status is now APPROVED
        ProposalVoting.Proposal[] memory proposals = proposalVoting.getProposals();
        assertEq(uint256(proposals[0].status), uint256(ProposalVoting.ProposalStatus.APPROVED));
    }

    function testPerformUpkeepRejectProposal() public {
        address forwarder = makeAddr("forwarder");
        vm.prank(owner);
        proposalVoting.setAutomationForwarder(forwarder);

        vm.prank(user1);
        proposalVoting.createProposal(PROPOSAL_TITLE, PROPOSAL_DESCRIPTION);

        // Vote against the proposal
        vm.prank(user1);
        bool support = false;
        proposalVoting.vote(0, support);

        vm.prank(user2);
        support = false;
        proposalVoting.vote(0, support);

        // Fast forward past voting period
        vm.warp(block.timestamp + VOTING_PERIOD + 1);

        uint256[] memory proposalsToClose = new uint256[](1);
        proposalsToClose[0] = 0;
        bytes memory performData = abi.encode(proposalsToClose);

        vm.expectEmit(true, false, false, true);
        emit ProposalClosed(0, ProposalVoting.ProposalStatus.REJECTED);

        vm.prank(forwarder);
        proposalVoting.performUpkeep(performData);

        ProposalVoting.Proposal[] memory proposals = proposalVoting.getProposals();
        assertEq(uint256(proposals[0].status), uint256(ProposalVoting.ProposalStatus.REJECTED));
    }

    function testPerformUpkeepRejectProposalWithMultipleVotes() public {
        address forwarder = makeAddr("forwarder");
        vm.prank(owner);
        proposalVoting.setAutomationForwarder(forwarder);

        vm.prank(user1);
        proposalVoting.createProposal(PROPOSAL_TITLE, PROPOSAL_DESCRIPTION);

        // Multiple votes
        for (uint256 i = 0; i < 10; i++) {
            address voter = makeAddr(string(abi.encodePacked("voter", i)));
            vm.prank(voter);
            proposalVoting.vote(0, i % 2 == 0); // Alternate votes
        }

        // Fast forward past voting period
        vm.warp(block.timestamp + VOTING_PERIOD + 1);

        uint256[] memory proposalsToClose = new uint256[](1);
        proposalsToClose[0] = 0;
        bytes memory performData = abi.encode(proposalsToClose);

        vm.expectEmit(true, false, false, true);
        emit ProposalClosed(0, ProposalVoting.ProposalStatus.REJECTED);

        vm.prank(forwarder);
        proposalVoting.performUpkeep(performData);

        ProposalVoting.Proposal[] memory proposals = proposalVoting.getProposals();
        assertEq(uint256(proposals[0].status), uint256(ProposalVoting.ProposalStatus.REJECTED));
    }

    //////////////////////////////////////////////
    // Integration tests
    //////////////////////////////////////////////

    function testFullProposalLifecycle() public {
        // Create proposal
        vm.prank(user1);
        proposalVoting.createProposal(PROPOSAL_TITLE, PROPOSAL_DESCRIPTION);

        // Multiple users vote
        vm.prank(user1);
        bool support = true;
        proposalVoting.vote(0, support);

        vm.prank(user2);
        support = true;
        proposalVoting.vote(0, support);

        vm.prank(nonOwner);
        support = false;
        proposalVoting.vote(0, support);

        // Verify voting results
        ProposalVoting.Proposal[] memory proposals = proposalVoting.getProposals();
        assertEq(proposals[0].votesFor, 2);
        assertEq(proposals[0].votesAgainst, 1);
        assertEq(uint256(proposals[0].status), uint256(ProposalVoting.ProposalStatus.PENDING));

        // Fast forward and close proposal
        vm.warp(block.timestamp + VOTING_PERIOD + 1);

        address forwarder = makeAddr("forwarder");
        vm.prank(owner);
        proposalVoting.setAutomationForwarder(forwarder);

        uint256[] memory proposalsToClose = new uint256[](1);
        proposalsToClose[0] = 0;
        bytes memory performData = abi.encode(proposalsToClose);

        vm.prank(forwarder);
        proposalVoting.performUpkeep(performData);

        // Verify final status
        proposals = proposalVoting.getProposals();
        assertEq(uint256(proposals[0].status), uint256(ProposalVoting.ProposalStatus.APPROVED));
    }
}
