#!/bin/bash

source ../../.env

echo "⚙️ LOCAL VAULT OPERATIONS"
echo "========================="

# Check if contracts are set
if [ -z "$VAULT_ENGINE" ]; then
    echo "❌ Contract addresses not set in .env"
    echo "🚀 Deploy first: make deploy-local"
    exit 1
fi

echo "📋 Contract Addresses:"
echo "VaultEngine: $VAULT_ENGINE"
echo "VaultStablecoin: $VAULT_STABLECOIN"
echo "WETH: $WETH"
echo "WBTC: $WBTC"
echo ""

# Quick operations functions
get_tokens() {
    echo "🪙 Getting test tokens..."
    cast send $WETH "faucet(uint256)" 20000000000000000000 --rpc-url $LOCAL_RPC_URL --private-key $ANVIL_PRIVATE_KEY
    cast send $WBTC "faucet(uint256)" 200000000 --rpc-url $LOCAL_RPC_URL --private-key $ANVIL_PRIVATE_KEY
    echo "✅ Tokens acquired!"
}

deposit_collateral() {
    local amount=${1:-3000000000000000000}  # Default 3 WETH
    echo "🏦 Depositing $amount wei WETH..."
    
    cast send $WETH "approve(address,uint256)" $VAULT_ENGINE $amount --rpc-url $LOCAL_RPC_URL --private-key $ANVIL_PRIVATE_KEY
    cast send $VAULT_ENGINE "depositCollateral(address,uint256)" $WETH $amount --rpc-url $LOCAL_RPC_URL --private-key $ANVIL_PRIVATE_KEY
    echo "✅ Deposit complete!"
}

mint_stablecoin() {
    local amount=${1:-1000000000000000000000}  # Default 1000 vUSD
    echo "🏭 Minting $amount wei vUSD..."
    
    cast send $VAULT_ENGINE "mintStablecoin(uint256)" $amount --rpc-url $LOCAL_RPC_URL --private-key $ANVIL_PRIVATE_KEY
    echo "✅ Minting complete!"
}

check_status() {
    echo "📊 VAULT STATUS"
    echo "==============="
    echo "WETH Balance: $(cast call $WETH "balanceOf(address)" $ANVIL_USER --rpc-url $LOCAL_RPC_URL)"
    echo "WBTC Balance: $(cast call $WBTC "balanceOf(address)" $ANVIL_USER --rpc-url $LOCAL_RPC_URL)"
    echo "vUSD Balance: $(cast call $VAULT_STABLECOIN "balanceOf(address)" $ANVIL_USER --rpc-url $LOCAL_RPC_URL)"
    echo "Health Factor: $(cast call $VAULT_ENGINE "getHealthFactor(address)" $ANVIL_USER --rpc-url $LOCAL_RPC_URL)"
    echo "Collateral Value: $(cast call $VAULT_ENGINE "getCollateralValue(address)" $ANVIL_USER --rpc-url $LOCAL_RPC_URL)"
}

# Interactive menu
echo "🎯 Available operations:"
echo "1. get_tokens"
echo "2. deposit_collateral [amount]"
echo "3. mint_stablecoin [amount]"
echo "4. check_status"
echo ""
echo "💡 Example: deposit_collateral 5000000000000000000"
echo "💡 Or just call functions directly!"