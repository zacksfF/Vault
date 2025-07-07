// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "./interfaces/IVaultStablecoin.sol";
import "./libraries/VaultErrors.sol";

/**
 * @title VaultStablecoin
 * @author Zakaria Saif
 * @notice Vault Protocol's USD-pegged decentralized stablecoin
 * @dev This contract represents the stablecoin token used in the Vault Protocol.
 *      It's designed to maintain a $1.00 peg through overcollateralization.
 *      Only the VaultEngine contract can mint and burn tokens.
 */
contract VaultStablecoin is ERC20Burnable, Ownable, IVaultStablecoin {
    uint256 public constant MAX_DAILY_MINT = 1000000e18; // 1M vUSD daily limit
    uint256 public lastMintTimestamp;
    uint256 public dailyMintAmount;

    /**
     * @notice Initializes the Vault Stablecoin
     * @param initialOwner Address that will own this contract (should be VaultEngine)
     */
    constructor(address initialOwner) 
        ERC20("Vault USD", "vUSD") 
        Ownable(initialOwner) 
    {
        if (initialOwner == address(0)) {
            revert VaultErrors.Vault__ZeroAddress();
        }
    }

    /**
     * @notice Mints new stablecoins to a specified address
     * @param to Address to mint tokens to
     * @param amount Amount of tokens to mint
     * @return success True if minting was successful
     * @dev Only the owner (VaultEngine) can call this function
     */
    function mint(address to, uint256 amount) external onlyOwner returns (bool success) {
        if (to == address(0)) {
            revert VaultErrors.Vault__ZeroAddress();
        }
        if (amount == 0) {
            revert VaultErrors.Vault__ZeroAmount();
        }

        // Reset daily counter if needed
        if (block.timestamp > lastMintTimestamp + 1 days) {
            dailyMintAmount = 0;
            lastMintTimestamp = block.timestamp;
        }

        // Check daily mint limit
        require(dailyMintAmount + amount <= MAX_DAILY_MINT, "Daily mint limit exceeded");
        dailyMintAmount += amount;

        // Check total supply growth rate
        uint256 currentSupply = totalSupply();
        require(amount <= currentSupply / 100, "Cannot mint more than 1% of supply at once");
        
        _mint(to, amount);
        return true;
    }

    /**
     * @notice Burns stablecoins from the caller's balance
     * @param amount Amount of tokens to burn
     * @dev Overrides the parent burn function to add validation
     */
    function burn(uint256 amount) public override(ERC20Burnable, IVaultStablecoin) {
        if (amount == 0) {
            revert VaultErrors.Vault__ZeroAmount();
        }
        if (balanceOf(msg.sender) < amount) {
            revert VaultErrors.Vault__InsufficientBalance();
        }
        
        super.burn(amount);
    }

    /**
     * @notice Burns stablecoins from a specified address with allowance
     * @param from Address to burn tokens from
     * @param amount Amount of tokens to burn
     * @dev Overrides the parent burnFrom function, only owner can call without allowance
     */
    function burnFrom(address from, uint256 amount) public override(ERC20Burnable, IVaultStablecoin) {
        if (amount == 0) {
            revert VaultErrors.Vault__ZeroAmount();
        }
        if (from == address(0)) {
            revert VaultErrors.Vault__ZeroAddress();
        }
        if (balanceOf(from) < amount) {
            revert VaultErrors.Vault__InsufficientBalance();
        }

        // If caller is the owner, bypass allowance check
        if (msg.sender == owner()) {
            _burn(from, amount);
        } else {
            // Use parent function which checks allowance
            super.burnFrom(from, amount);
        }
    }
}