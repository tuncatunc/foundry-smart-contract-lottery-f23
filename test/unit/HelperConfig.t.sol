// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";

contract TestHelperConfig is Test {
    HelperConfig helperConfig;

    function setUp() public {
        helperConfig = new HelperConfig();
    }

    function testGetSepoliahEthConfig() public view {
        HelperConfig.NetworkConfig memory config = helperConfig.getSepoliahEthConfig();
        assertEq(config.entranceFee, 0.001 ether);
        assertEq(config.interval, 60);
        assertEq(config.vrfCoordinator, 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B);
        assertEq(config.linkToken, 0x779877A7B0D9E8603169DdbD7836e478b4624789);
    }

    function testGetOrCreateAnvilEthConfig() public {
        HelperConfig.NetworkConfig memory config = helperConfig.getOrCreateAnvilEthConfig();
        assertEq(config.entranceFee, 0.001 ether);
        assertEq(config.interval, 60);
        assertEq(config.account, 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38);
        assertTrue(config.vrfCoordinator != address(0));
        assertTrue(config.linkToken != address(0));
    }

    function testGetNetworkConfigByChainId() public view {
        HelperConfig.NetworkConfig memory config = helperConfig.getNetworkConfigByChainId(11155111);

        assertEq(config.entranceFee, 0.001 ether);
        assertEq(config.interval, 60);
        assertEq(config.vrfCoordinator, 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B);
        assertEq(config.linkToken, 0x779877A7B0D9E8603169DdbD7836e478b4624789);
    }

    function testGetNetworkConfig() public view {
        HelperConfig.NetworkConfig memory config = helperConfig.getNetworkConfig();
        if (block.chainid == 11155111) {
            assertEq(config.entranceFee, 0.001 ether);
            assertEq(config.interval, 60);
            assertEq(config.vrfCoordinator, 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B);
            assertEq(config.linkToken, 0x779877A7B0D9E8603169DdbD7836e478b4624789);
        } else if (block.chainid == 31337) {
            assertEq(config.entranceFee, 0.001 ether);
            assertEq(config.interval, 60);
            assertEq(config.account, 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38);
            assertTrue(config.vrfCoordinator != address(0));
            assertTrue(config.linkToken != address(0));
        }
    }

    function testSetNetworkConfig() public {
        HelperConfig.NetworkConfig memory newConfig = HelperConfig.NetworkConfig({
            entranceFee: 0.002 ether,
            interval: 120,
            vrfSubscriptionId: 123456789,
            vrfCoordinator: address(0x123),
            keyHash: 0x0,
            linkToken: address(0x456),
            account: address(0x789)
        });

        helperConfig.setNetworkConfig(1, newConfig);
        HelperConfig.NetworkConfig memory config = helperConfig.getNetworkConfigByChainId(1);
        assertEq(config.entranceFee, 0.002 ether);
        assertEq(config.interval, 120);
        assertEq(config.vrfCoordinator, address(0x123));
        assertEq(config.linkToken, address(0x456));
        assertEq(config.account, address(0x789));
    }
}
