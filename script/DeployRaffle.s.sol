// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {Script, console2} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "script/Interactions.s.sol";

contract DeployRaffle is Script {
    function deployRaffle() public returns (Raffle, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();

        // If subscription is not created, create a one and update config
        HelperConfig.NetworkConfig memory networkConfig = helperConfig.getNetworkConfig();

        if (networkConfig.vrfSubscriptionId == 0) {
            console2.log("Creating subscription");
            // Create a subscription
            CreateSubscription createSubscription = new CreateSubscription();
            (networkConfig.vrfSubscriptionId, networkConfig.vrfCoordinator) =
                createSubscription.createSubscription(networkConfig.account, networkConfig.vrfCoordinator);
            console2.log("Subscription created with vrfSubscriptionId: %s", networkConfig.vrfSubscriptionId);
        }

        // Fund the subscription
        console2.log("Funding subscription");
        console2.log(
            "Vrf Coordinator Address: %s Subscription Id: %s LinkToken Address: %s",
            networkConfig.vrfCoordinator,
            networkConfig.vrfSubscriptionId,
            networkConfig.linkToken
        );
        FundSubscription fundSubscription = new FundSubscription();
        fundSubscription.fundSubcription(
            networkConfig.vrfCoordinator,
            networkConfig.vrfSubscriptionId,
            networkConfig.linkToken,
            networkConfig.account
        );
        console2.log("Subscription funded");

        helperConfig.setNetworkConfig(block.chainid, networkConfig);

        vm.startBroadcast(networkConfig.account);

        Raffle raffle = new Raffle(
            networkConfig.entranceFee,
            networkConfig.interval,
            networkConfig.vrfSubscriptionId,
            networkConfig.vrfCoordinator,
            networkConfig.keyHash
        );
        vm.stopBroadcast();

        // Add Raffle contract as VRF consumer
        AddConsumer addConsumer = new AddConsumer();
        addConsumer.addConsumer(
            networkConfig.account, address(raffle), networkConfig.vrfCoordinator, networkConfig.vrfSubscriptionId
        );

        return (raffle, helperConfig);
    }

    function run() external returns (Raffle, HelperConfig) {
        return deployRaffle();
    }
}
