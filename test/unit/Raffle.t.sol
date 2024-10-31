// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";

import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {Raffle, RaffleEvents} from "src/Raffle.sol";

contract RaffleTest is Test, RaffleEvents {
    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_PLAYER_BALANCE = 1000 ether;
    uint256 entranceFee;
    uint256 interval;
    uint256 vrfSubscriptionId;
    address vrfCoordinator;
    bytes32 keyHash;
    Raffle raffle;
    HelperConfig helperConfig;

    function setUp() external {
        DeployRaffle deployRaffle = new DeployRaffle();
        (raffle, helperConfig) = deployRaffle.deployRaffle();
        HelperConfig.NetworkConfig memory networkConfig = helperConfig.getNetworkConfig();
        entranceFee = networkConfig.entranceFee;
        interval = networkConfig.interval;
        vrfSubscriptionId = networkConfig.vrfSubscriptionId;
        vrfCoordinator = networkConfig.vrfCoordinator;
        keyHash = networkConfig.keyHash;
        vm.deal(PLAYER, STARTING_PLAYER_BALANCE);
    }

    function testRaffleInitializesInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    function testRaffleRevertsYouDoNotPayEnough() public {
        // Arrange
        vm.prank(PLAYER);
        vm.deal(PLAYER, STARTING_PLAYER_BALANCE);
        uint256 bet = 0.0001 ether; // minumum entrance fee is 0.001 ether

        // Act
        vm.expectRevert(abi.encodeWithSelector(Raffle.Raffle__InvalidEntranceFee.selector, bet, entranceFee));
        raffle.enterRaffle{value: bet}();

        // Assert
    }

    function testRaffleAddsPlayerToPlayersArray() public {
        // Arrange
        vm.prank(PLAYER);
        uint256 bet = 1 ether;

        // Act
        raffle.enterRaffle{value: bet}();

        // Assert
        assertEq(raffle.getNumberOfPlayers(), 1);
        assert(raffle.getPlayer(0) == PLAYER);
    }

    function testRaffleEmitsEnteredEvent() public {
        // Arrange
        vm.prank(PLAYER);
        uint256 bet = 1 ether;
        vm.expectEmit(true, false, false, false, address(raffle));
        emit Raffle__Entered(PLAYER, bet);

        // Act
        raffle.enterRaffle{value: bet}();

        // Assert
    }

    function testRaffleDontAllowPlayerToEnterRaffleWhileCalculatingWinner() public {
        // Arrange
        vm.prank(PLAYER);
        uint256 bet = 1 ether;
        raffle.enterRaffle{value: bet}();

        // Act
        vm.warp(block.timestamp + interval + 1); // Advance vm block time by interval + 1 seconds
        vm.roll(block.number + 1); // advance to next block
        raffle.performUpkeep("");

        // Assert
        vm.expectRevert(Raffle.Raffle__RaffleClosed.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: bet}();

        // Assert
    }
}
