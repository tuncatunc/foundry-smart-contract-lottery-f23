// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {SubscriptionConsumer} from "./SubscriptionConsumer.sol";

/**
 * @title Raffle Contract
 * @author Tunca Tunc
 * @notice This contract is for crearing sample raffle
 * @dev implements Chainlink VRFv2.5
 */
import {IRaffle} from "./IRaffle.sol";

contract Raffle is IRaffle {
    /**
     * Errors
     */
    error Raffle__InvalidEntranceFee(uint256 entranceFee, uint256 minimumEntranceFee);
    error Raffle__NotEnoughTimePassed(uint256 lastTimeStamp, uint256 interval);
    error Raffle__TransferFailed(address player, uint256 amount);
    error Raffle__RaffleClosed();

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

    uint256 private constant VRF_SUBSCRIPTION_ID =
        17184522417954535456058647781288809196340310866013225809895981208296795930336;
    /**
     * Events
     */

    event Raffle__Entered(address indexed player, uint256 entranceFee);
    event Raffle__WinnerPicked(address indexed winner, uint256 prize);

    constructor(uint256 entranceFee, uint256 interval) {
        s_raffleState = RaffleState.OPEN;
        i_entranceFee = entranceFee;
        i_interval = interval;
        s_lastTimeStamp = block.timestamp;
        s_chainlinkVRF = new SubscriptionConsumer(VRF_SUBSCRIPTION_ID, address(this));
    }

    function enterRaffle() external payable validEntranceFee raffleOpen {
        s_players.push(payable(msg.sender));
        emit Raffle__Entered(msg.sender, msg.value);
    }

    /**
     *
     */
    function pickWinner() external enoughTimePassed {
        // 1. Get a random number
        // 2. Use the random number to pick a winner
        // 3. Be automatically called

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

    modifier enoughTimePassed() {
        if (block.timestamp - s_lastTimeStamp < i_interval) {
            revert Raffle__NotEnoughTimePassed(s_lastTimeStamp, i_interval);
        }
        _;
    }

    modifier raffleOpen() {
        if (s_raffleState == RaffleState.CLOSED) {
            revert Raffle__RaffleClosed();
        }
        _;
    }

    function raffleEnds(uint256[] calldata randomWords) external override {
        uint256 winnerIndex = randomWords[0] % s_players.length;
        address payable winner = s_players[winnerIndex];
        s_recentWinner = winner;

        s_lastTimeStamp = block.timestamp;

        // Reset the raffle state, so that it can be opened again
        s_raffleState = RaffleState.OPEN;

        // Reset the players array
        delete s_players;
        (bool success,) = winner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__TransferFailed(winner, address(this).balance);
        }

        emit Raffle__WinnerPicked(winner, address(this).balance);
    }
}
