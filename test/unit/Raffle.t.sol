// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {Test, Vm, console} from "forge-std/Test.sol";

import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {Raffle, RaffleEvents} from "src/Raffle.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts@1.2.0/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

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
    uint256 public raffleEntraceFee;

    function setUp() external {
        DeployRaffle deployRaffle = new DeployRaffle();
        (raffle, helperConfig) = deployRaffle.deployRaffle();
        HelperConfig.NetworkConfig memory networkConfig = helperConfig.getNetworkConfig();
        entranceFee = networkConfig.entranceFee;
        interval = networkConfig.interval;
        vrfSubscriptionId = networkConfig.vrfSubscriptionId;
        vrfCoordinator = networkConfig.vrfCoordinator;
        keyHash = networkConfig.keyHash;
        raffleEntraceFee = networkConfig.entranceFee;
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

    function testRafflePerformUpkeepRevertsWhenIntervalHasNotPassed() public {
        // Arrange
        vm.prank(PLAYER);
        uint256 bet = 1 ether;
        raffle.enterRaffle{value: bet}();

        // Act
        vm.warp(block.timestamp + interval - 1); // Advance vm block time by interval - 1 seconds
        vm.roll(block.number + 1); // advance to next block

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle__UpkeepNotNeeded.selector,
                raffle.getRaffleState(),
                address(raffle).balance,
                raffle.getNumberOfPlayers()
            )
        );
        raffle.performUpkeep("");
    }

    function testRaffleEntranceFeeIsCorrect() public view {
        // Arrange
        // Act
        // Assert
        assertEq(raffle.getEntranceFee(), 0.001 ether);
    }

    function testRaffleIntervalIsCorrect() public view {
        // Arrange
        // Act
        // Assert
        assertEq(raffle.getInterval(), 60);
    }

    function testRaffleRaffleEndsWhenPerformUpkeepIsCalled() public {
        // Arrange
        vm.prank(PLAYER);
        uint256 bet = 1 ether;
        raffle.enterRaffle{value: bet}();

        // Act
        vm.warp(block.timestamp + interval + 1); // Advance vm block time by interval + 1 seconds
        vm.roll(block.number + 1); // advance to next block
        raffle.performUpkeep("");

        // Assert
        assert(raffle.getRaffleState() == Raffle.RaffleState.CLOSED);
    }

    function testRaffleCheckUpkeepReturnsFalseWhenNoBalance() public {
        // Arrange

        // Act
        vm.warp(block.timestamp + interval + 1); // Advance vm block time by interval + 1 seconds
        vm.roll(block.number + 1); // advance to next block

        // Assert
        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        assert(!upkeepNeeded);
    }

    modifier raffleEntered() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: raffleEntraceFee}();
        vm.warp(block.timestamp + interval + 1); // Advance vm block time by interval + 1 seconds
        vm.roll(block.number + 1); // advance to next block
        _;
    }

    modifier skipFork() {
        if (block.chainid != 31337) {
            return;
        }
        _;
    }

    function testRaffleFullfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(uint256 randomRequestId)
        public
        raffleEntered
        skipFork
    {
        // Arrange
        // Act / Assert
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(randomRequestId, address(raffle));
    }

    function testRaffleFullfillRandomWordsPickAWinnerAndResetsRaffleState() public raffleEntered skipFork {
        address expectedWinner = address(1);

        // Arrange
        uint256 additionalEnterances = 9;
        uint256 startIndex = 1;

        for (uint256 i = startIndex; i < additionalEnterances + startIndex; i++) {
            address player = address(uint160(i));
            hoax(player, 1 ether);

            raffle.enterRaffle{value: raffleEntraceFee}();
        }
        uint256 startingBalance = expectedWinner.balance;

        // Act
        vm.recordLogs();
        raffle.performUpkeep(""); // emits request id
        Vm.Log[] memory logs = vm.getRecordedLogs();

        console.logBytes32(logs[1].topics[1]);
        bytes32 requestId = logs[1].topics[1];

        // Perform raffle, select a winner and transfer rewards
        // Mock coordinator random words is 0, 1
        console.log("fulfillRandomWords requestId", uint256(requestId));
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(uint256(requestId), address(raffle));

        // Assert
        address recentWinner = raffle.getRecentWinner();
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        uint256 winnerBalance = recentWinner.balance;
        // uint256 endingTimestamp = raffle.getLatestTimestamp();
        uint256 prize = raffleEntraceFee * (additionalEnterances) + raffleEntraceFee;
        // uint256 numPlayers = raffle.getNumberOfPlayers();
        (bool fullfilled, uint256[] memory randomWords) = raffle.getRequestStatus(uint256(requestId));

        assert(fullfilled);
        assertEq(randomWords.length, 1); // 1 random words
        assertEq(recentWinner, expectedWinner);
        assert(raffleState == Raffle.RaffleState.OPEN);
        assertEq(winnerBalance, startingBalance + prize);
        // assert(endingTimestamp > startingTimeStamp);
        // assertEq(numPlayers, 0);
    }

    function testRaffleFullfillRandomWordsRevertsIfRequestIdDoesntExist() public skipFork {
        // Arrange
        // Act
        // Assert
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(0, address(raffle));
    }

    function testRaffleUpkeepReturnsFalseIfEnoughTimeHasntPassed() public view {
        // Arrange
        // Act
        // Assert
        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        assert(!upkeepNeeded);
    }

    function testRafflePerformUpkeepCanOnlyBeRunIfCheckUpkeepIsTrue() public raffleEntered {
        // Arrange
        // Act
        // Assert

        raffle.performUpkeep("");
        // If not reverted, then it passed
        assert(true);
    }

    function testRaffleUpkeepReturnsTrueIfEnoughTimeHasPassed() public raffleEntered {
        // Arrange
        // Act
        vm.warp(block.timestamp + interval + 1); // Advance vm block time by interval + 1 seconds

        // Assert
        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        assert(upkeepNeeded);
    }

    function testRaffleGetRecentWinnerTest() public view {
        // Arrange
        // Act
        // Assert
        assertEq(raffle.getRecentWinner(), address(0));
    }

    function testRaffleGetLastestTimestampTest() public view {
        // Arrange
        // Act
        // Assert
        assertEq(raffle.getLatestTimestamp(), block.timestamp);
    }

    function testRaffleCannotEnterClosedRaffle() public raffleEntered {
        // Arrange
        raffle.performUpkeep("");

        // Act
        vm.expectRevert(Raffle.Raffle__RaffleClosed.selector);
        raffle.enterRaffle{value: raffleEntraceFee}();
    }
}
