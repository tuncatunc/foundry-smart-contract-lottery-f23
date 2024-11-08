// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {Test, Vm, console2} from "forge-std/Test.sol";
import {AutomationCompatibleInterface} from "@chainlink/contracts@1.2.0/v0.8/automation/AutomationCompatible.sol";
import {VRFConsumerBaseV2Plus} from "@chainlink/contracts@1.2.0/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts@1.2.0/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

/**
 * @title Raffle Contract
 * @author Tunca Tunc
 * @notice This contract is for creating simple raffle
 * @dev implements Chainlink VRFv2.5
 */
abstract contract RaffleEvents {
    /**
     * Events
     */
    event Raffle__Entered(address indexed player, uint256 entranceFee);
    event Raffle__WinnerPicked(address indexed winner, uint256 prize);
    event Raffle__RequestSent(uint256 indexed requestId, uint32 numWords);
    event Raffle__RequestFulfilled(uint256 requestId, uint256[] randomWords);
}

contract Raffle is AutomationCompatibleInterface, RaffleEvents, VRFConsumerBaseV2Plus {
    /**
     * Errors
     */
    error Raffle__InvalidEntranceFee(uint256 entranceFee, uint256 minimumEntranceFee);
    error Raffle__TransferFailed(address player, uint256 amount);
    error Raffle__RaffleClosed();
    error Raffle__UpkeepNotNeeded(RaffleState state, uint256 balance, uint256 noPlayers);
    error Raffle__RequestNotFound(uint256 requestId);

    /**
     * Type Declarations
     */
    enum RaffleState {
        OPEN,
        CLOSED
    }

    struct RequestStatus {
        bool fulfilled; // whether the request has been successfully fulfilled
        bool exists; // whether a requestId exists
        uint256[] randomWords;
    }

    /**
     * State Variables
     */
    uint256 private immutable i_entranceFee;

    mapping(uint256 => RequestStatus) public s_requests; /* requestId --> requestStatus */

    // Duration of lottery in seconds
    uint256 private immutable i_interval;
    uint256 private s_lastTimeStamp;
    address payable[] private s_players;
    address private s_recentWinner;
    RaffleState private s_raffleState;

    // Your subscription ID.
    uint256 public s_subscriptionId;

    // Past request IDs.
    uint256[] public requestIds;
    uint256 public lastRequestId;

    // The gas lane to use, which specifies the maximum gas price to bump to.
    // For a list of available gas lanes on each network,
    // see https://docs.chain.link/docs/vrf/v2-5/supported-networks
    // bytes32 public keyHash = 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae;
    bytes32 public keyHash;

    // Depends on the number of requested values that you want sent to the
    // fulfillRandomWords() function. Storing each word costs about 20,000 gas,
    // so 100,000 is a safe default for this example contract. Test and adjust
    // this limit based on the network that you select, the size of the request,
    // and the processing of the callback request in the fulfillRandomWords()
    // function.
    uint32 public callbackGasLimit = 100000;

    // The default is 3, but you can set this higher.
    uint16 public requestConfirmations = 3;

    // For this example, retrieve 2 random values in one request.
    // Cannot exceed VRFCoordinatorV2_5.MAX_NUM_WORDS.
    uint32 public numWords = 1;

    // uint256 private immutable i_VRF_SUBSCRIPTION_ID = 17184522417954535456058647781288809196340310866013225809895981208296795930336;

    constructor(
        uint256 entranceFee,
        uint256 interval,
        uint256 _vrfSubscriptionId,
        address _vrfCoordinator,
        bytes32 _keyHash
    ) VRFConsumerBaseV2Plus(_vrfCoordinator) {
        s_raffleState = RaffleState.OPEN;
        s_subscriptionId = _vrfSubscriptionId;
        keyHash = _keyHash;
        i_entranceFee = entranceFee;
        i_interval = interval;
        s_lastTimeStamp = block.timestamp;
        // s_chainlinkVRF = new SubscriptionConsumer(_vrfSubscriptionId, address(this), _vrfCoordinator, _keyHash);
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
        requestRandomWords(true);
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

    function getRaffleState() public view returns (RaffleState) {
        return s_raffleState;
    }

    function getNumberOfPlayers() public view returns (uint256) {
        return s_players.length;
    }

    function getPlayer(uint256 index) public view returns (address) {
        return s_players[index];
    }

    function getRecentWinner() public view returns (address) {
        return s_recentWinner;
    }

    function getLatestTimestamp() public view returns (uint256) {
        return s_lastTimeStamp;
    }

    // Assumes the subscription is funded sufficiently.
    // @param enableNativePayment: Set to `true` to enable payment in native tokens, or
    // `false` to pay in LINK
    function requestRandomWords(bool enableNativePayment) internal returns (uint256 requestId) {
        // Will revert if subscription is not set and funded.
        requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: keyHash,
                subId: s_subscriptionId,
                requestConfirmations: requestConfirmations,
                callbackGasLimit: callbackGasLimit,
                numWords: numWords,
                extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: enableNativePayment}))
            })
        );
        s_requests[requestId] = RequestStatus({randomWords: new uint256[](0), exists: true, fulfilled: false});
        requestIds.push(requestId);
        lastRequestId = requestId;
        emit Raffle__RequestSent(requestId, numWords);
    }

    /**
     * @dev This is the function that Chainlink VRF node
     * calls to send the money to the random winner.
     */
    function fulfillRandomWords(uint256 _requestId, uint256[] calldata _randomWords) internal override {
        s_requests[_requestId].fulfilled = true;
        s_requests[_requestId].randomWords = _randomWords;
        emit Raffle__RequestFulfilled(_requestId, _randomWords);
        raffleEnds(_randomWords);
    }

    function getRequestStatus(uint256 _requestId)
        external
        view
        returns (bool fulfilled, uint256[] memory randomWords)
    {
        RequestStatus memory request = s_requests[_requestId];
        return (request.fulfilled, request.randomWords);
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
    function raffleEnds(uint256[] calldata randomWords) internal {
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
