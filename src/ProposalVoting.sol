// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/automation/AutomationCompatible.sol";

/**
 * @title ProposalVoting
 * @author Thiago Mesquita
 * @notice This contract allows users to create proposals and vote on them.
 *         Proposals can be approved or rejected based on the votes received.
 * @dev The contract uses OpenZeppelin's ReentrancyGuard to prevent reentrancy attacks.
 *      It also implements Chainlink's AutomationCompatibleInterface for automatic closing of voting periods.
 */
contract ProposalVoting is ReentrancyGuard, AutomationCompatibleInterface {
    // Custom errors for better gas efficiency
    error ProposalVoting__NotAuthorized();
    error ProposalVoting__TitleOrDescriptionEmpty();
    error ProposalVoting__VotingAlreadyEnded(uint256 proposalId);
    error ProposalVoting__ProposalNotFound(uint256 proposalId);
    error ProposalVoting__AlreadyVoted(uint256 proposalId);
    error ProposalVoting__ForwarderAddressNotSet();
    error ProposalVoting__InvalidForwarderAddress();

    // Enums and structs to define proposal status and structure
    enum ProposalStatus {
        PENDING,
        APPROVED,
        REJECTED
    }

    struct Proposal {
        uint256 id;
        string title;
        string description;
        uint256 votesFor;
        uint256 votesAgainst;
        ProposalStatus status;
        uint256 creationDate;
    }

    // Contract owner
    address private immutable i_owner;

    // State variables to store proposals and voting data
    uint256 private constant VOTING_PERIOD = 7 days;
    mapping(uint256 => Proposal) private s_proposals;
    mapping(address => mapping(uint256 => bool)) private s_voters;
    uint256 private s_totalProposals;

    // State variables to use with Chainlink Automation
    uint256 private constant PROPOSAL_BATCH_SIZE = 20;
    uint256 private s_lastCheckedProposalIndex;
    address private s_automationForwarder;

    // Events to log proposal creation and voting actions
    event ProposalCreated(uint256 indexed id, string title, string description, uint256 creationDate);
    event VoteRecorded(uint256 indexed proposalId);
    event ProposalClosed(uint256 indexed proposalId, ProposalStatus status);
    event AutomationForwarderSet(address indexed forwarder);

    /**
     * @notice Initializes the contract with zero total proposals and sets the owner.
     */
    constructor() {
        s_totalProposals = 0;
        i_owner = msg.sender;
    }

    /**
     * @notice Sets the automation forwarder address.
     * @dev Only the contract owner can set the forwarder address.
     *      This address is used for Chainlink Automation to perform upkeep.
     * @param forwarder The address of the automation forwarder.
     */
    function setAutomationForwarder(address forwarder) external {
        if (msg.sender != i_owner) revert ProposalVoting__NotAuthorized();
        if (forwarder == address(0)) revert ProposalVoting__InvalidForwarderAddress();
        if (forwarder == s_automationForwarder) return;

        s_automationForwarder = forwarder;

        emit AutomationForwarderSet(forwarder);
    }

    /**
     * @notice Creates a new proposal with a title and description.
     * @dev The function increments the total number of proposals and initializes the new proposal.
     *      Emits a ProposalCreated event upon successful creation.
     * @param title The title of the proposal.
     * @param description The description of the proposal.
     */
    function createProposal(string calldata title, string calldata description) external nonReentrant {
        if (bytes(title).length == 0 || bytes(description).length == 0) {
            revert ProposalVoting__TitleOrDescriptionEmpty();
        }

        uint256 proposalId = s_totalProposals++;
        uint256 creationDate = block.timestamp;

        s_proposals[proposalId] = Proposal({
            id: proposalId,
            title: title,
            description: description,
            votesFor: 0,
            votesAgainst: 0,
            status: ProposalStatus.PENDING,
            creationDate: creationDate
        });

        emit ProposalCreated(proposalId, title, description, creationDate);
    }

    /**
     * @notice Allows users to vote on a proposal.
     * @dev The function checks if the voter is a reentrant caller, the proposal exists, the voting period has ended and the voter has already voted.
     *      If the proposal is still open for voting, it increments the vote count based on the voter's choice.
     *      The voter is then marked as having voted for that proposal.
     *      Emits a VoteRecorded event upon successful voting.
     * @param proposalId The ID of the proposal to vote on.
     * @param support Whether the voter supports the proposal or not.
     */
    function vote(uint256 proposalId, bool support) external nonReentrant {
        if (s_proposals[proposalId].creationDate == 0) {
            revert ProposalVoting__ProposalNotFound(proposalId);
        }
        Proposal storage proposal = s_proposals[proposalId];
        if (proposal.creationDate + VOTING_PERIOD < block.timestamp) {
            revert ProposalVoting__VotingAlreadyEnded(proposalId);
        }
        if (s_voters[msg.sender][proposalId]) {
            revert ProposalVoting__AlreadyVoted(proposalId);
        }

        if (support) {
            proposal.votesFor++;
        } else {
            proposal.votesAgainst++;
        }

        s_voters[msg.sender][proposalId] = true;

        emit VoteRecorded(proposalId);
    }

    /**
     * @notice Checks if there are proposals that need to be closed based on the voting period.
     * @dev This function is used by Chainlink Automation to determine if upkeep is needed.
     *      It checks the last checked proposal index and the total number of pending proposals.
     *      If there are proposals that have exceeded the voting period, it returns them for closure.
     * @return upkeepNeeded Whether upkeep is needed or not.
     * @return performData The data to be passed to performUpkeep.
     */
    function checkUpkeep(bytes calldata) external view override returns (bool upkeepNeeded, bytes memory performData) {
        // If there are no proposals to check, return early
        if (s_totalProposals == 0) {
            upkeepNeeded = false;
            performData = bytes("");
            return (upkeepNeeded, performData);
        }

        uint256 pendingProposalsCount = _getPendingProposalsCount();

        // If there are no pending proposals, return early
        if (pendingProposalsCount == 0) {
            upkeepNeeded = false;
            performData = bytes("");
            return (upkeepNeeded, performData);
        }

        // Calculate the range of proposals to check
        uint256 proposalEnd = s_lastCheckedProposalIndex + PROPOSAL_BATCH_SIZE;
        if (proposalEnd > pendingProposalsCount) {
            proposalEnd = pendingProposalsCount;
        }

        // Get pending proposals and check which ones need to be closed
        Proposal[] memory pendingProposals = _getPendingProposals();
        uint256[] memory proposalsToClose = new uint256[](pendingProposalsCount);
        uint256 proposalsToCloseCount = 0;
        for (uint256 i = s_lastCheckedProposalIndex; i < proposalEnd; i++) {
            Proposal memory proposal = pendingProposals[i];
            if (proposal.creationDate + VOTING_PERIOD < block.timestamp) {
                proposalsToClose[proposalsToCloseCount++] = proposal.id;
            }
        }

        // If there are proposals to close, set upkeepNeeded to true and prepare performData
        if (proposalsToCloseCount > 0) {
            upkeepNeeded = true;
            assembly {
                mstore(proposalsToClose, proposalsToCloseCount)
            }
            performData = abi.encode(proposalsToClose);
        } else {
            // If no proposals need to be closed, set upkeepNeeded to false
            upkeepNeeded = false;
            performData = bytes("");
        }
    }

    /**
     * @notice Performs the upkeep to close proposals that have exceeded the voting period.
     * @dev This function is called by Chainlink Automation when upkeep is needed.
     *      It checks if the automation forwarder address is set and if the caller is the forwarder.
     *      It then processes the proposals to close them based on their vote counts.
     * @param performData The data passed from checkUpkeep containing proposals to close.
     */
    function performUpkeep(bytes calldata performData) external override {
        // Ensure the automation forwarder address is set
        if (s_automationForwarder == address(0)) {
            revert ProposalVoting__ForwarderAddressNotSet();
        }
        // Ensure the function is called by the automation forwarder
        if (msg.sender != s_automationForwarder) {
            revert ProposalVoting__InvalidForwarderAddress();
        }

        // Decode the performData to get the proposals to close
        uint256[] memory proposalsToClose = abi.decode(performData, (uint256[]));

        // Iterate through the proposals to close and update their status
        for (uint256 i = 0; i < proposalsToClose.length; i++) {
            uint256 proposalId = proposalsToClose[i];
            Proposal storage proposal = s_proposals[proposalId];
            if (proposal.status == ProposalStatus.PENDING) {
                if (proposal.votesFor > proposal.votesAgainst) {
                    proposal.status = ProposalStatus.APPROVED;
                } else {
                    proposal.status = ProposalStatus.REJECTED;
                }
                emit ProposalClosed(proposalId, proposal.status);
            }
        }

        uint256 pendingProposalsCount = _getPendingProposalsCount();
        // Update the last checked proposal index for the next upkeep
        if (pendingProposalsCount == 0) {
            // If there are no pending proposals, reset the index
            s_lastCheckedProposalIndex = 0;
        } else {
            // Otherwise, increment the index by the batch size
            s_lastCheckedProposalIndex = (s_lastCheckedProposalIndex + PROPOSAL_BATCH_SIZE) % pendingProposalsCount;
        }
    }

    /**
     * @notice Returns the total number of proposals.
     * @return The total number of proposals created.
     */
    function getProposals() external view returns (Proposal[] memory) {
        Proposal[] memory proposals = new Proposal[](s_totalProposals);
        for (uint256 i = 0; i < s_totalProposals; i++) {
            proposals[i] = s_proposals[i];
        }
        return proposals;
    }

    /**
     * @notice Returns the total number of proposals that are currently pending.
     * @return The total number of pending proposals.
     */
    function _getPendingProposalsCount() internal view returns (uint256) {
        uint256 count = 0;
        for (uint256 i = 0; i < s_totalProposals; i++) {
            if (s_proposals[i].status == ProposalStatus.PENDING) {
                count++;
            }
        }
        return count;
    }

    /**
     * @notice Returns an array of pending proposals.
     * @dev This function iterates through all proposals and collects those that are pending.
     * @return An array of pending Proposal structs.
     */
    function _getPendingProposals() internal view returns (Proposal[] memory) {
        uint256 pendingCount = _getPendingProposalsCount();
        Proposal[] memory pendingProposals = new Proposal[](pendingCount);
        uint256 index = 0;
        for (uint256 i = 0; i < s_totalProposals; i++) {
            if (s_proposals[i].status == ProposalStatus.PENDING) {
                pendingProposals[index++] = s_proposals[i];
            }
        }
        return pendingProposals;
    }
}
