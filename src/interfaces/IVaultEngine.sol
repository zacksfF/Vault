// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IVaultEngine
 * @author Zakaria Saif
 * @notice Interface for the main Vault Protocol engine
 */
interface IVaultEngine {
    // Events
    event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);
    event CollateralRedeemed(address indexed from, address indexed to, address indexed token, uint256 amount);
    event StablecoinMinted(address indexed user, uint256 amount);
    event StablecoinBurned(address indexed user, uint256 amount);
    event UserLiquidated(address indexed liquidatedUser, address indexed liquidator, address indexed collateralToken, uint256 debtCovered, uint256 collateralLiquidated);

    // Core functions
    function depositCollateral(address tokenCollateralAddress, uint256 amountCollateral) external;
    function redeemCollateral(address tokenCollateralAddress, uint256 amountCollateral) external;
    function mintStablecoin(uint256 amountToMint) external;
    function burnStablecoin(uint256 amountToBurn) external;
    function liquidate(address collateralToken, address user, uint256 debtToCover) external;

    // View functions
    function getHealthFactor(address user) external view returns (uint256);
    function getAccountInformation(address user) external view returns (uint256 totalStablecoinMinted, uint256 collateralValueInUsd);
    function getCollateralValue(address user) external view returns (uint256);
    function getSupportedTokens() external view returns (address[] memory);
}