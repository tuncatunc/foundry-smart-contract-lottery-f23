// SPDX-License-Identifier: MIT

// 1. Deploy mocks on local anvil
// 2. Keep track of the address of the deployed mocks

pragma solidity 0.8.19;

import "forge-std/Script.sol";

contract HelperConfig is Script {
    // If we're on local anvil chain, we deploy mocks
    // Otherwise, we use the real contracts from live chain

    NetworkConfig public activeConfig;

    struct NetworkConfig {
        uint256 entranceFee;
        uint256 interval;
        uint256 vrfSubscriptionId;
        address vrfCoordinator;
        bytes32 keyHash;
    }

    constructor() {
        if (block.chainid == 11155111) {
            activeConfig = getSepoliahEthConfig();
        } else {
            activeConfig = getAnvilEthConfig();
        }
    }

    function getSepoliahEthConfig() public pure returns (NetworkConfig memory) {
        NetworkConfig memory config = NetworkConfig({
            entranceFee: 0.1 ether,
            interval: 60,
            vrfSubscriptionId: 17184522417954535456058647781288809196340310866013225809895981208296795930336,
            vrfCoordinator: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B,
            keyHash: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae
        });
        return config;
    }

    function getAnvilEthConfig() public returns (NetworkConfig memory) {
        revert("Not implemented");
    }
}
