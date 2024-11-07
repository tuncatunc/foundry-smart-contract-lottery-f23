// SPDX-License-Identifier: MIT

// 1. Deploy mocks on local anvil
// 2. Keep track of the address of the deployed mocks

pragma solidity 0.8.19;

import "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts@1.2.0/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {MockLinkToken} from "chainlink-brownie-contracts@0.8/mocks/MockLinkToken.sol";

abstract contract Constants {
    /* Mock VRF Coordinator  Values*/
    uint96 public MOCK_BASE_FEE = 0.001 ether;
    uint96 public MOCK_GAS_PRICE = 20000000000;
    int256 public MOCK_WEI_PER_UNIT_LINK = 1000000000000000000;

    uint256 constant SEPOLIA_CHAIN_ID = 11155111;
    uint256 constant ANVIL_CHAIN_ID = 31337;

    address constant FOUNDRY_DEFAULT_SENDER = 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38;
}

contract HelperConfig is Constants, Script {
    // If we're on local anvil chain, we deploy mocks
    // Otherwise, we use the real contracts from live chain
    error HelperConfig__InvalidChainId(uint256 chainId);

    NetworkConfig public localNetworkConfig;
    mapping(uint256 chainId => NetworkConfig) public networkConfigs;

    struct NetworkConfig {
        uint256 entranceFee;
        uint256 interval;
        uint256 vrfSubscriptionId;
        address vrfCoordinator;
        bytes32 keyHash;
        address linkToken;
        address account;
    }

    constructor() {
        networkConfigs[SEPOLIA_CHAIN_ID] = getSepoliahEthConfig();
        localNetworkConfig = getOrCreateAnvilEthConfig();
    }

    function getSepoliahEthConfig() public pure returns (NetworkConfig memory) {
        NetworkConfig memory config = NetworkConfig({
            entranceFee: 0.001 ether,
            interval: 60,
            vrfSubscriptionId: 88643892962829376642526568752367248075052116482772790387693005868742629678276,
            vrfCoordinator: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B,
            keyHash: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            linkToken: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
            account: 0x9b49c2E118effaBa3a0bA08125eD8192fcDfcEf4
        });
        return config;
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        // Check if the config is already deployed
        if (localNetworkConfig.vrfCoordinator != address(0)) {
            return localNetworkConfig;
        }

        // Deploy mocks
        vm.startBroadcast();
        VRFCoordinatorV2_5Mock vrfCoordinatorMock =
            new VRFCoordinatorV2_5Mock(MOCK_BASE_FEE, MOCK_GAS_PRICE, MOCK_WEI_PER_UNIT_LINK);

        console.log("Deploying Mock Link Token on chain %s", block.chainid);
        MockLinkToken linkToken = new MockLinkToken();
        console.log("Link Token Address: %s", address(linkToken));

        console.log("Deploying Mock VRF Coordinator on chain %s", block.chainid);
        uint256 subId = vrfCoordinatorMock.createSubscription();
        console.log("Subscription Id: %s ", subId, block.chainid);

        vm.stopBroadcast();

        localNetworkConfig = NetworkConfig({
            entranceFee: 0.001 ether,
            interval: 60,
            vrfSubscriptionId: subId,
            vrfCoordinator: address(vrfCoordinatorMock),
            keyHash: 0x0,
            linkToken: address(linkToken),
            account: FOUNDRY_DEFAULT_SENDER
        });
        vm.deal(FOUNDRY_DEFAULT_SENDER, 100 ether);

        return localNetworkConfig;
    }

    function getNetworkConfigByChainId(uint256 chainId) public view returns (NetworkConfig memory) {
        if (networkConfigs[chainId].vrfCoordinator != address(0)) {
            return networkConfigs[chainId];
        } else if (chainId == SEPOLIA_CHAIN_ID) {
            return networkConfigs[SEPOLIA_CHAIN_ID];
        } else {
            return localNetworkConfig;
        }
    }

    function getNetworkConfig() public view returns (NetworkConfig memory) {
        return getNetworkConfigByChainId(block.chainid);
    }

    function setNetworkConfig(uint256 chainId, NetworkConfig memory config) public {
        networkConfigs[chainId] = config;
    }
}
