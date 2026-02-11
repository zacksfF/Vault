// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./VaultErrors.sol";

/**
 * @title VaultMath
 * @author Zakaria Saif
 * @notice Mathematical calculations and constants for the Vault Protocol
 * @dev Handles all mathematical operations with proper precision
 */
library VaultMath{
    // Protocol constants
    uint256 public constant LIQUIDATION_THRESHOLD = 50; // 200% overcollateralization required
    uint256 public constant LIQUIDATION_BONUS = 10; // 10% bonus for liquidators
    uint256 public constant LIQUIDATION_PRECISION = 100;
    uint256 public constant MIN_HEALTH_FACTOR = 1e18;
    uint256 public constant PRECISION = 1e18;
    uint256 public constant FEED_PRECISION = 1e8;
    uint256 public constant ADDITIONAL_FEED_PRECISION = 1e10;

    /**
     * @notice Calculates the health factor for a user's position
     * @param totalStablecoinMinted Total amount of stablecoins minted by user
     * @param collateralValueInUsd Total collateral value in USD
     * @return healthFactor The calculated health factor
     */

    function calculateHealthFactor(uint256 collateralValueInUsd, uint256 totalStablecoinMinted)
        internal
        pure
        returns (uint256 healthFactor)
    {
        if (totalStablecoinMinted == 0) return type(uint256).max;
        
        uint256 collateralAdjustedForThreshold = 
            (collateralValueInUsd * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        
        return (collateralAdjustedForThreshold * PRECISION) / totalStablecoinMinted;
    }

    /**
     * @notice Converts USD amount to token amount using price feed data
     * @param usdAmount Amount in USD (18 decimals)
     * @param tokenPriceInUsd Token price in USD (8 decimals from Chainlink)
     * @return tokenAmount Equivalent token amount
     */
    function getTokenAmountFromUsd(uint256 usdAmount, uint256 tokenPriceInUsd) 
        internal 
        pure 
        returns (uint256 tokenAmount)
    {
        return (usdAmount * PRECISION) / (tokenPriceInUsd * ADDITIONAL_FEED_PRECISION);
    }

    /**
     * @notice Converts token amount to USD value using price feed data
     * @param amount Amount of tokens (18 decimals)
     * @param tokenPriceInUsd Token price in USD (18 decimals, already scaled by PriceOracle)
     */
    function getUsdValue(address /* token */, uint256 amount, uint256 tokenPriceInUsd)
        public
        pure
        returns (uint256)
    {
        return (amount * tokenPriceInUsd) / PRECISION;
    }

    /**
     * @notice Calculates liquidation bonus amount
     * @param debtToCover Amount of debt being covered
     * @param tokenPriceInUsd Price of the collateral token
     * @return bonusAmount Bonus amount in tokens
     */
    function calculateLiquidationBonus(uint256 debtToCover, uint256 tokenPriceInUsd)
        internal
        pure
        returns (uint256 bonusAmount)
    {
        uint256 collateralAmount = getTokenAmountFromUsd(debtToCover, tokenPriceInUsd);
        return (collateralAmount * LIQUIDATION_BONUS) / LIQUIDATION_PRECISION;
    }

    // Add minimum amount validation and proper precision handling
    function calculateCollateralAdjustedForThreshold(uint256 collateralValueInUsd)
        internal pure returns (uint256) {

        // Ensure minimum collateral value to prevent precision issues
        require(collateralValueInUsd >= LIQUIDATION_PRECISION, "Collateral too small");

        // Use higher precision arithmetic
        uint256 threshold = (collateralValueInUsd * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;

        // Ensure result is never zero if input is non-zero
        require(threshold > 0 || collateralValueInUsd == 0, "Threshold calculation error");

        return threshold;
    }

    // Alternative: Use SafeMath with scaling
    function calculateCollateralAdjustedForThresholdSafe(uint256 collateralValueInUsd)
        internal pure returns (uint256) {

        if (collateralValueInUsd == 0) return 0;

        // Scale up calculation to maintain precision
        uint256 scaledResult = (collateralValueInUsd * LIQUIDATION_THRESHOLD * 1e18) / (LIQUIDATION_PRECISION * 1e18);

        return scaledResult;
    }

}