// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {SubscriptionConsumer} from "./SubscriptionConsumer.sol";
import {AutomationCompatibleInterface} from "@chainlink/contracts@1.2.0/v0.8/automation/AutomationCompatible.sol";

/**
 * @title Raffle Contract
 * @author Tunca Tunc
 * @notice This contract is for crearing sample raffle
 * @dev implements Chainlink VRFv2.5
 */
import {IRaffle} from "./IRaffle.sol";

contract Raffle is IRaffle, AutomationCompatibleInterface {
    /**
     * Errors
     */
    error Raffle__InvalidEntranceFee(uint256 entranceFee, uint256 minimumEntranceFee);
    error Raffle__TransferFailed(address player, uint256 amount);
    error Raffle__RaffleClosed();
    error Raffle__UpkeepNotNeeded(RaffleState state, uint256 balance, uint256 noPlayers);

    /**
     * Type Declarations
     */
    enum RaffleState {
        OPEN,
        CLOSED
    }

    /**
     * State Variables
     */
    uint256 private immutable i_entranceFee;
    SubscriptionConsumer public s_chainlinkVRF;

    // Duration of lottery in seconds
    uint256 private immutable i_interval;
    uint256 private s_lastTimeStamp;
    address payable[] private s_players;
    address private s_recentWinner;
    RaffleState private s_raffleState;

    // uint256 private immutable i_VRF_SUBSCRIPTION_ID = 17184522417954535456058647781288809196340310866013225809895981208296795930336;
    /**
     * Events
     */
    event Raffle__Entered(address indexed player, uint256 entranceFee);
    event Raffle__WinnerPicked(address indexed winner, uint256 prize);

    constructor(
        uint256 entranceFee,
        uint256 interval,
        uint256 _vrfSubscriptionId,
        address _vrfCoordinator,
        bytes32 _keyHash
    ) {
        s_raffleState = RaffleState.OPEN;
        i_entranceFee = entranceFee;
        i_interval = interval;
        s_lastTimeStamp = block.timestamp;
        s_chainlinkVRF = new SubscriptionConsumer(_vrfSubscriptionId, address(this), _vrfCoordinator, _keyHash);
    }

    /**
     * The lottery is ready to have a winner picked
     * 1. Interval has passed
     * 2. The lottery is open
     * 3. The contract has ETH to pay for the winner
     * 4. There is at least one player
     */
    function checkUpkeep(bytes memory /*checkData*/ )
        public
        view
        override
        returns (bool upkeepNeeded, bytes memory performData)
    {
        bool hasIntervalPassed = block.timestamp - s_lastTimeStamp >= i_interval;
        bool isRaffleOpen = s_raffleState == RaffleState.OPEN;
        bool hasPlayers = s_players.length > 0;
        bool hasBalance = address(this).balance > 0;
        upkeepNeeded = hasIntervalPassed && isRaffleOpen && hasPlayers && hasBalance;

        return (upkeepNeeded, "");
    }

    function enterRaffle() external payable validEntranceFee raffleOpen {
        s_players.push(payable(msg.sender));
        emit Raffle__Entered(msg.sender, msg.value);
    }

    /**
     *
     */
    function performUpkeep(bytes calldata /*performData*/ ) external {
        // 1. Get a random number
        // 2. Use the random number to pick a winner
        // 3. Be automatically called
        (bool upkeepNeeded,) = checkUpkeep("");

        if (!upkeepNeeded) {
            revert Raffle__UpkeepNotNeeded(s_raffleState, address(this).balance, s_players.length);
        }

        // Change raffle state to closed so no one can enter
        s_raffleState = RaffleState.CLOSED;
        // Get a random number from Chainlnk VRF
        s_chainlinkVRF.requestRandomWords(false);
    }

    /**
     * Getter Functions
     */
    function getEntranceFee() public view returns (uint256) {
        return i_entranceFee;
    }

    function getInterval() public view returns (uint256) {
        return i_interval;
    }

    modifier validEntranceFee() {
        if (msg.value < i_entranceFee) {
            revert Raffle__InvalidEntranceFee(msg.value, i_entranceFee);
        }
        _;
    }

    modifier raffleOpen() {
        if (s_raffleState == RaffleState.CLOSED) {
            revert Raffle__RaffleClosed();
        }
        _;
    }

    // CEI: Check, Effects, Interact
    function raffleEnds(uint256[] calldata randomWords) external override {
        // Checks
        // Effects (Changes contract internal states)
        uint256 winnerIndex = randomWords[0] % s_players.length;
        address payable winner = s_players[winnerIndex];
        s_recentWinner = winner;

        s_lastTimeStamp = block.timestamp;

        // Reset the raffle state, so that it can be opened again
        s_raffleState = RaffleState.OPEN;
        emit Raffle__WinnerPicked(winner, address(this).balance);

        // Reset the players array
        delete s_players;
        (bool success,) = winner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__TransferFailed(winner, address(this).balance);
        }
    }
}
