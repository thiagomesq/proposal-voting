// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {ProposalVoting} from "src/ProposalVoting.sol";

contract DeployProposalVoting is Script {
    HelperConfig public helperConfig;

    constructor() {
        helperConfig = new HelperConfig();
    }

    function run() external returns (ProposalVoting, HelperConfig.NetworkConfig memory) {
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        vm.startBroadcast(config.account);
        ProposalVoting proposalVoting = new ProposalVoting();
        vm.stopBroadcast();

        return (proposalVoting, config);
    }
}
