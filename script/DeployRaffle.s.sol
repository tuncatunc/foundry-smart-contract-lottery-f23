// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployRaffle is Script {
    function deployRaffle() public returns (Raffle, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();

        vm.startBroadcast();
        HelperConfig.NetworkConfig memory networkConfig = helperConfig.getNetworkConfig();

        Raffle raffle = new Raffle(
            networkConfig.entranceFee,
            networkConfig.interval,
            networkConfig.vrfSubscriptionId,
            networkConfig.vrfCoordinator,
            networkConfig.keyHash
        );
        vm.stopBroadcast();

        return (raffle, helperConfig);
    }

    function run() external returns (Raffle, HelperConfig) {
        return deployRaffle();
    }
}
