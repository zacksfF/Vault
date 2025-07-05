// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title VaultErrors
 * @author Zakaria Saif
 * @notice Centralized error definitions for the Vault Protocol
 * @dev All custom errors used across the protocol are defined here
 */

library VaultErrors{
    // General errors
    error Vault__ZeroAmount();
    error Vault__ZeroAddress();
    error Vault__TransferFailed();
    error Vault__InsufficientBalance();

    // Collateral errors
    error Vault__TokenNotSupported();
    error Vault__CollateralAddressesAndPriceFeedsMismatch();
    error Vault__InsufficientCollateral();

    // Health factor errors
    error Vault__HealthFactorBelowMinimum(uint256 healthFactor);
    error Vault__HealthFactorNotImproved();
    error Vault__PositionHealthy();

    // Minting errors
    error Vault__MintingFailed();
    error Vault__BurningFailed();
    
    // Oracle errors
    error Vault__StalePrice();
    error Vault__InvalidPriceData();
}