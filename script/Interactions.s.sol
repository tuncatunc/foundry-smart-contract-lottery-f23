// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig, Constants} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "chainlink-brownie-contracts@0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {MockLinkToken} from "chainlink-brownie-contracts@0.8/mocks/MockLinkToken.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract CreateSubscription is Script {
    function createSubscriptionFromConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory networkConfig = helperConfig.getNetworkConfig();

        createSubscription(networkConfig.account, networkConfig.vrfCoordinator);
    }

    function createSubscription(address account, address vrfCoordinatorAddress)
        public
        returns (uint256 subId, address vrfCoordinator)
    {
        // Create a subscription

        console.log("Creating subscription on chainId: %s", block.chainid);
        vm.startBroadcast(account);
        VRFCoordinatorV2_5Mock coordinator = VRFCoordinatorV2_5Mock(vrfCoordinatorAddress);
        uint256 sid = coordinator.createSubscription();
        vm.stopBroadcast();
        console.log("Vrf Coordinator Address: %s Subscription Id: %s", vrfCoordinatorAddress, sid);
        console.log("Remember to set the subscription id in the HelperConfig contract for the network");
        return (sid, vrfCoordinatorAddress);
    }

    function run() external {
        createSubscriptionFromConfig();
    }
}

contract FundSubscription is Script, Constants {
    uint256 public constant FUND_AMOUNT = 3 ether; // 3 LINK Tokens

    function fundSubcriptionFromConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory networkConfig = helperConfig.getNetworkConfig();

        fundSubcription(
            networkConfig.vrfCoordinator,
            networkConfig.vrfSubscriptionId,
            networkConfig.linkToken,
            networkConfig.account
        );
    }

    function fundSubcription(address vrfCoordinatorV2_5, uint256 subId, address link, address account) public {
        console.log("Funding subscription: ", subId);
        console.log("Using vrfCoordinator: ", vrfCoordinatorV2_5);
        console.log("On ChainID: ", block.chainid);
        if (block.chainid == ANVIL_CHAIN_ID) {
            vm.startBroadcast(account);
            VRFCoordinatorV2_5Mock(vrfCoordinatorV2_5).fundSubscription(subId, FUND_AMOUNT);
            vm.stopBroadcast();
        } else {
            console.log(MockLinkToken(link).balanceOf(msg.sender));
            console.log(msg.sender);
            console.log(MockLinkToken(link).balanceOf(address(this)));
            console.log(address(this));
            vm.startBroadcast(account);
            MockLinkToken(link).transferAndCall(vrfCoordinatorV2_5, FUND_AMOUNT, abi.encode(subId));
            vm.stopBroadcast();
        }
    }

    function _fundSubcription(address account, address vrfCoordinatorAddress, uint256 vrfSubscriptionId, address link)
        public
    {
        if (block.chainid == ANVIL_CHAIN_ID) {
            vm.startBroadcast(account);
            VRFCoordinatorV2_5Mock coordinator = VRFCoordinatorV2_5Mock(vrfCoordinatorAddress);

            coordinator.fundSubscription(vrfSubscriptionId, FUND_AMOUNT);
            vm.stopBroadcast();
        } else {
            console.log(MockLinkToken(link).balanceOf(msg.sender));
            console.log(msg.sender);
            console.log(MockLinkToken(link).balanceOf(address(this)));
            console.log(address(this));
            vm.startBroadcast(account);
            MockLinkToken(link).transferAndCall(vrfCoordinatorAddress, FUND_AMOUNT, abi.encode(vrfSubscriptionId));
            vm.stopBroadcast();
        }
    }

    function run() external {
        fundSubcriptionFromConfig();
    }
}

contract AddConsumer is Script, Constants {
    function addConsumerFromConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory networkConfig = helperConfig.getNetworkConfig();

        address raffleAddress = DevOpsTools.get_most_recent_deployment("Raffle", block.chainid);
        addConsumer(networkConfig.account, raffleAddress, networkConfig.vrfCoordinator, networkConfig.vrfSubscriptionId);
    }

    function addConsumer(address account, address raffleAddress, address vrfCoordinatorAddress, uint256 subscriptionId)
        public
    {
        VRFCoordinatorV2_5Mock coordinator = VRFCoordinatorV2_5Mock(vrfCoordinatorAddress);

        console.log(
            "Adding Raffle contract: %s to VrfCoordinator: %s on chainId: %s",
            raffleAddress,
            vrfCoordinatorAddress,
            block.chainid
        );

        vm.startBroadcast(account);
        coordinator.addConsumer(subscriptionId, raffleAddress);
        vm.stopBroadcast();
    }

    function run() external {
        addConsumerFromConfig();
    }
}
