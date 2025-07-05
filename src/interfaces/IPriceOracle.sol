// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "lib/chainlink-brownie-contracts/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

/**
 * @title IPriceOracle
 * @author Zakaria Saif
 * @notice Interface for price oracle functionality
 */
interface IPriceOracle {
    /**
     * @notice Gets the latest price for a token
     * @param priceFeed The Chainlink price feed
     * @return price The latest price
     */
    function getPrice(AggregatorV3Interface priceFeed) external view returns (uint256 price);

    /**
     * @notice Gets the latest round data with staleness check
     * @param priceFeed The Chainlink price feed
     * @return roundId The round ID
     * @return price The price
     * @return startedAt When the round started
     * @return updatedAt When the round was updated
     * @return answeredInRound The round the answer was computed
     */
    function getLatestPrice(AggregatorV3Interface priceFeed)
        external
        view
        returns (uint80 roundId, int256 price, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);

    /**
     * @notice Gets the timeout for price staleness
     * @return timeout The timeout in seconds
     */
    function getPriceTimeout() external pure returns (uint256 timeout);
}