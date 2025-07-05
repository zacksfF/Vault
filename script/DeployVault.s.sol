// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/VaultEngine.sol";
import "../src/VaultStablecoin.sol";
import "./HelperConfig.s.sol";

/**
 * @title DeployVault
 * @author Zakaria Saif
 * @notice Deploys the complete Vault Protocol to Sepolia testnet
 */
contract DeployVault is Script {
    address[] public tokenAddresses;
    address[] public priceFeedAddresses;
    
    function run() external returns (VaultStablecoin, VaultEngine, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        (
            address wethUsdPriceFeed,
            address wbtcUsdPriceFeed,
            address weth,
            address wbtc,
            uint256 deployerKey
        ) = helperConfig.activeNetworkConfig();
        
        tokenAddresses = [weth, wbtc];
        priceFeedAddresses = [wethUsdPriceFeed, wbtcUsdPriceFeed];

        vm.startBroadcast(deployerKey);
        
        // For Sepolia, deploy mock WBTC
        if (block.chainid == 11155111) {
            MockERC20 wbtcMock = new MockERC20("Wrapped Bitcoin", "WBTC", 8, msg.sender, 1000e8);
            console.log("Mock WBTC deployed at:", address(wbtcMock));
            tokenAddresses[1] = address(wbtcMock);
        }
        
        // Deploy VaultStablecoin
        VaultStablecoin vaultStablecoin = new VaultStablecoin(msg.sender);
        console.log("VaultStablecoin deployed at:", address(vaultStablecoin));
        
        // Deploy VaultEngine
        VaultEngine vaultEngine = new VaultEngine(
            tokenAddresses,
            priceFeedAddresses,
            address(vaultStablecoin)
        );
        console.log("VaultEngine deployed at:", address(vaultEngine));
        
        // Transfer ownership
        vaultStablecoin.transferOwnership(address(vaultEngine));
        console.log("Ownership transferred to VaultEngine");
        
        console.log("");
        console.log("Ethereum Sepolia Deployment Summary:");
        console.log("=======================================");
        console.log("- VaultStablecoin:", address(vaultStablecoin));
        console.log("- VaultEngine:", address(vaultEngine));
        console.log("- WETH:", tokenAddresses[0]);
        console.log("- WBTC:", tokenAddresses[1]);
        console.log("- ETH/USD Price Feed:", priceFeedAddresses[0]);
        console.log("- BTC/USD Price Feed:", priceFeedAddresses[1]);
        console.log("- Chain ID:", block.chainid);
        
        vm.stopBroadcast();
        
        return (vaultStablecoin, vaultEngine, helperConfig);
    }
}