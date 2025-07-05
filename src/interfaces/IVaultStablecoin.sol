// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

/**
 * @title IVaultStablecoin
 * @author Zakaria Saif
 * @notice Interface for the Vault Protocol's USD-pegged stablecoin
 */
interface IVaultStablecoin is IERC20 {
    /**
     * @notice Mints new stablecoins to a specified address
     * @param to Address to mint tokens to
     * @param amount Amount of tokens to mint
     * @return success True if minting was successful
     */
    function mint(address to, uint256 amount) external returns (bool success);

    /**
     * @notice Burns stablecoins from the caller's balance
     * @param amount Amount of tokens to burn
     */
    function burn(uint256 amount) external;

    /**
     * @notice Burns stablecoins from a specified address
     * @param from Address to burn tokens from
     * @param amount Amount of tokens to burn
     */
    function burnFrom(address from, uint256 amount) external;
}