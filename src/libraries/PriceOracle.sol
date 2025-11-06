// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "lib/chainlink-brownie-contracts/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import "./VaultErrors.sol";
import "./VaultMath.sol";

/**
 * @title PriceOracle
 * @author Zakaria Saif
 * @notice Library for interacting with Chainlink price feeds with stale price protection
 * @dev Provides secure price data fetching with built-in staleness checks
 */
library PriceOracle {
    uint256 private constant TIMEOUT = 3 hours;
    uint256 constant STALE_BLOCK_THRESHOLD = 240; // ~1 hour at 15s blocks
    

    /**
     * @notice Gets the latest price data with staleness validation
     * @param priceFeed Chainlink price feed interface
     * @return price The latest asset price with additional feed precision
     */
    function getLatestPrice(AggregatorV3Interface priceFeed) internal view returns (uint256) {
        (uint80 roundId, int256 price, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) = priceFeed.latestRoundData();
        
        // Validate price data
        if (price <= 0) revert("Invalid price");
        if (answeredInRound < roundId) revert("Stale price");
        
        // Check timestamp staleness
        if (block.timestamp < updatedAt) revert("Timestamp in future");
        uint256 ageInSeconds = block.timestamp - updatedAt;
        if (ageInSeconds > TIMEOUT) revert("Price too stale (time)");
        
        // Optional: Check block-based staleness
        uint256 blockAge = (block.timestamp - updatedAt) / 15; // Approximate block age
        if (blockAge > STALE_BLOCK_THRESHOLD) revert("Price too stale (blocks)");
        
        return uint256(price) * VaultMath.ADDITIONAL_FEED_PRECISION;
    }


    /**
     * @notice Gets only the price from the latest round data
     * @param priceFeed Chainlink price feed interface
     * @return price The latest price
     */
    function getPrice(AggregatorV3Interface priceFeed) internal view returns (uint256 price) {
        return getLatestPrice(priceFeed);
    }

    /**
     * @notice Returns the timeout period for price staleness
     * @return timeout The timeout period in seconds
     */
    function getPriceTimeout() internal pure returns (uint256 timeout) {
        return TIMEOUT;
    }
}