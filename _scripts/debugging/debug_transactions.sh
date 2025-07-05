#!/bin/bash

source ../../.vault_env
source ../../.env

echo "🔍 TRANSACTION DEBUGGER"
echo "======================="

# Check transaction status
check_tx() {
    local tx_hash=$1
    echo "Checking transaction: $tx_hash"
    
    if cast receipt $tx_hash --rpc-url $SEPOLIA_RPC_URL > /dev/null 2>&1; then
        echo "✅ Transaction confirmed"
        cast receipt $tx_hash --rpc-url $SEPOLIA_RPC_URL
    else
        echo "⏳ Transaction pending or failed"
    fi
}

# Simulate operation to check for revert
simulate_mint() {
    local amount=${1:-1000000000000000000000}
    echo "🔍 Simulating mint of $amount vUSD..."
    
    if cast call $VAULT_ENGINE "mintStablecoin(uint256)" $amount --rpc-url $SEPOLIA_RPC_URL --from $USER_ADDRESS; then
        echo "✅ Simulation successful"
    else
        echo "❌ Simulation failed - check health factor and collateral"
    fi
}

# Gas estimation
estimate_gas() {
    echo "⛽ GAS ESTIMATES"
    echo "Deposit: $(cast estimate $VAULT_ENGINE "depositCollateral(address,uint256)" $WETH 1000000000000000000 --rpc-url $SEPOLIA_RPC_URL --from $USER_ADDRESS 2>/dev/null || echo "Failed") gas"
    echo "Mint: $(cast estimate $VAULT_ENGINE "mintStablecoin(uint256)" 100000000000000000000 --rpc-url $SEPOLIA_RPC_URL --from $USER_ADDRESS 2>/dev/null || echo "Failed") gas"
}

# Interactive debugger
echo "Available commands:"
echo "1. check_tx <hash> - Check transaction status"
echo "2. simulate_mint [amount] - Simulate minting"
echo "3. estimate_gas - Show gas estimates"
echo ""
echo "Usage: ./debug_transactions.sh"
echo "Then call functions manually or modify script for your needs"