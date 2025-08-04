// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {ProposalVoting} from "src/ProposalVoting.sol";
import {DevOpsTools} from "foundry-devops/src/DevOpsTools.sol";

contract CreateProposal is Script {
    function createProposal(address proposalVoting, HelperConfig.NetworkConfig memory config) public {
        vm.startBroadcast(config.account);

        ProposalVoting voting = ProposalVoting(proposalVoting);
        string memory proposalTitle = "New Proposal";
        string memory proposalDescription = "This is a new proposal for testing purposes.";

        // Create a new proposal
        voting.createProposal(proposalTitle, proposalDescription);

        vm.stopBroadcast();
    }

    function run() external {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("ProposalVoting", block.chainid);
        createProposal(mostRecentlyDeployed, config);
    }
}

contract VoteProposal is Script {
    function voteOnProposal(address proposalVoting, uint256 proposalId, bool support, HelperConfig.NetworkConfig memory config) public {
        vm.startBroadcast(config.account);

        ProposalVoting voting = ProposalVoting(proposalVoting);
        
        // Vote on the proposal
        voting.vote(proposalId, support);

        vm.stopBroadcast();
    }

    function run() external {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("ProposalVoting", block.chainid);
        
        // Assuming proposalId is known or fetched from somewhere
        uint256 proposalId = 0; // Replace with actual proposal ID
        bool support = true; // Replace with actual vote choice

        voteOnProposal(mostRecentlyDeployed, proposalId, support, config);
    }
}

contract GetProposals is Script {
    function getProposals(address proposalVoting, HelperConfig.NetworkConfig memory config) public {
        vm.startBroadcast(config.account);

        ProposalVoting voting = ProposalVoting(proposalVoting);
        
        // Fetch all proposals
        ProposalVoting.Proposal[] memory proposals = voting.getProposals();

        // Log the proposals
        for (uint256 i = 0; i < proposals.length; i++) {
            console.log("Proposal ID:", proposals[i].id);
            console.log("Title:", proposals[i].title);
            console.log("Description:", proposals[i].description);
            console.log("Votes For:", proposals[i].votesFor);
            console.log("Votes Against:", proposals[i].votesAgainst);
            console.log(
                "Status:", 
                proposals[i].status == ProposalVoting.ProposalStatus.PENDING
                    ? "Pending" : proposals[i].status == ProposalVoting.ProposalStatus.APPROVED
                    ? "Approved" : "Rejected"
            );
        }

        vm.stopBroadcast();
    }

    function run() external {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("ProposalVoting", block.chainid);
        
        getProposals(mostRecentlyDeployed, config);
    }
}

contract SetAutomationForwarder is Script {
    function setAutomationForwarder(address proposalVoting, address automationForwarder, HelperConfig.NetworkConfig memory config) public {
        vm.startBroadcast(config.account);

        ProposalVoting voting = ProposalVoting(proposalVoting);
        
        // Set the automation forwarder
        voting.setAutomationForwarder(automationForwarder);

        vm.stopBroadcast();
    }

    function run() external {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("ProposalVoting", block.chainid);
        
        // Assuming automationForwarder is known or fetched from somewhere
        address automationForwarder = 0xE45D97A9920B5564AE289EF173B1f3FFDE33BCa6; // Replace with actual forwarder address

        setAutomationForwarder(mostRecentlyDeployed, automationForwarder, config);
    }
}