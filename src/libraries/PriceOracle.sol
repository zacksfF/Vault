// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "lib/chainlink-brownie-contracts/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import "./VaultErrors.sol";

/**
 * @title PriceOracle
 * @author Zakaria Saif
 * @notice Library for interacting with Chainlink price feeds with stale price protection
 * @dev Provides secure price data fetching with built-in staleness checks
 */
library PriceOracle {
    uint256 private constant TIMEOUT = 3 hours;

    /**
     * @notice Gets the latest price data with staleness validation
     * @param priceFeed Chainlink price feed interface
     * @return roundId The round ID
     * @return price The asset price
     * @return startedAt Timestamp when the round started
     * @return updatedAt Timestamp when the round was last updated
     * @return answeredInRound The round ID of the round in which the answer was computed
     */
    function getLatestPrice(AggregatorV3Interface priceFeed)
        internal
        view
        returns (uint80 roundId, int256 price, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        (roundId, price, startedAt, updatedAt, answeredInRound) = priceFeed.latestRoundData();

        // Check for stale price data
        if (updatedAt == 0 || answeredInRound < roundId) {
            revert VaultErrors.Vault__StalePrice();
        }

        // Check if price is too old
        uint256 secondsSinceUpdate = block.timestamp - updatedAt;
        if (secondsSinceUpdate > TIMEOUT) {
            revert VaultErrors.Vault__StalePrice();
        }

        // Validate price is positive
        if (price <= 0) {
            revert VaultErrors.Vault__InvalidPriceData();
        }

        return (roundId, price, startedAt, updatedAt, answeredInRound);
    }

    /**
     * @notice Gets only the price from the latest round data
     * @param priceFeed Chainlink price feed interface
     * @return price The latest price
     */
    function getPrice(AggregatorV3Interface priceFeed) internal view returns (uint256 price) {
        (, int256 rawPrice,,,) = getLatestPrice(priceFeed);
        return uint256(rawPrice);
    }

    /**
     * @notice Returns the timeout period for price staleness
     * @return timeout The timeout period in seconds
     */
    function getPriceTimeout() internal pure returns (uint256 timeout) {
        return TIMEOUT;
    }
}