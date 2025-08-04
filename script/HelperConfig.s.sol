// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";

contract HelperConfig is Script {
    error HelperConfig__InvalidChainId();

    uint256 public constant LOCAL_CHAIN_ID = 31337;
    uint256 public constant AMOY_CHAIN_ID = 80002;

    struct NetworkConfig {
        address account;
    }

    NetworkConfig public localNetworkConfig;
    mapping(uint256 => NetworkConfig) public networkConfigs;

    constructor() {
        networkConfigs[AMOY_CHAIN_ID] = getAmoyConfig();
    }

    function getConfigChainId(uint256 chainId) public returns (NetworkConfig memory) {
        if (networkConfigs[chainId].account != address(0)) {
            return networkConfigs[chainId];
        } else if (chainId == LOCAL_CHAIN_ID) {
            return getOrCreateAnvilEthConfig();
        } else {
            revert HelperConfig__InvalidChainId();
        }
    }

    function getConfig() public returns (NetworkConfig memory) {
        return getConfigChainId(block.chainid);
    }

    function getAmoyConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({account: 0xe7FDf6cA472c484FA8b7b2E11a5E62adaF1e649F}); // Replace with your Amoy account public address
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        localNetworkConfig = NetworkConfig({account: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266});
        return localNetworkConfig;
    }
}
