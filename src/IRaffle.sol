// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IRaffle {
    function raffleEnds(uint256[] calldata randomWords) external;
}
