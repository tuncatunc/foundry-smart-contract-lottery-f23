// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployRaffle is Script {
    function deployRaffle() public returns (Raffle, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();

        vm.startBroadcast();
        (uint256 entranceFee, uint256 interval, uint256 vrfSubscriptionId, address vrfCoordinator, bytes32 keyHash) =
            helperConfig.activeConfig();

        Raffle raffle = new Raffle(entranceFee, interval, vrfSubscriptionId, vrfCoordinator, keyHash);
        vm.stopBroadcast();

        return (raffle, helperConfig);
    }

    function run() external returns (Raffle, HelperConfig) {
        return deployRaffle();
    }
}
