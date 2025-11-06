// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title MockPriceFeed
 * @author Zakaria Saif
 * @notice Mock Chainlink price feed for testing
 * @dev Simulates AggregatorV3Interface for testing price oracle functionality
 */
contract MockPriceFeed {
    uint256 public constant version = 4;
    uint8 public decimals;
    
    uint80 private latestRound;
    mapping(uint80 => int256) private answers;
    mapping(uint80 => uint256) private timestamps;
    mapping(uint80 => uint256) private startedAts;
    mapping(uint80 => uint80) private roundAnsweredIds; // Which round answered this round

    constructor(uint8 _decimals, int256 _initialAnswer) {
        decimals = _decimals;
        // Initialize first round with valid data
        _initializeRound(1, _initialAnswer, block.timestamp, block.timestamp, 1);
    }
    
    function _initializeRound(
        uint80 roundId,
        int256 answer,
        uint256 timestamp,
        uint256 startedAt,
        uint80 answeredInRound
    ) internal {
        latestRound = roundId;
        answers[roundId] = answer;
        timestamps[roundId] = timestamp;
        startedAts[roundId] = startedAt;
        roundAnsweredIds[roundId] = answeredInRound;
    }

    // Helper for tests to simulate specific scenarios
    function setRoundData(
        uint80 roundId,
        int256 answer,
        uint256 timestamp,
        uint256 startedAt,
        uint80 answeredInRound
    ) public {
        require(roundId > 0, "Invalid round ID");
        answers[roundId] = answer;
        timestamps[roundId] = timestamp;
        startedAts[roundId] = startedAt;
        roundAnsweredIds[roundId] = answeredInRound;
        
        if (roundId >= latestRound) {
            latestRound = roundId;
        }
    }

    function getRoundData(uint80 roundId)
        external
        view
        returns (uint80, int256, uint256, uint256, uint80)
    {
        return (
            roundId,
            answers[roundId],
            startedAts[roundId],
            timestamps[roundId],
            roundAnsweredIds[roundId]
        );
    }

    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        roundId = latestRound;
        answer = answers[roundId];
        startedAt = startedAts[roundId];
        updatedAt = timestamps[roundId];
        answeredInRound = roundAnsweredIds[roundId];
    }

    function description() external pure returns (string memory) {
        return "v0.8/Mock";
    }
}