#!/bin/bash

source ../../.env

echo "📊 LOCAL VAULT MONITOR"
echo "======================"

monitor_local() {
    while true; do
        clear
        echo "🏠 LOCAL VAULT MONITOR - $(date)"
        echo "================================"
        echo ""
        
        if [ -n "$VAULT_ENGINE" ]; then
            # Health Factor
            HEALTH=$(cast call $VAULT_ENGINE "getHealthFactor(address)" $ANVIL_USER --rpc-url $LOCAL_RPC_URL 2>/dev/null)
            echo "📊 Health Factor: $HEALTH"
            
            # Balances
            echo ""
            echo "💰 Token Balances:"
            echo "ETH: $(cast balance $ANVIL_USER --rpc-url $LOCAL_RPC_URL)"
            echo "WETH: $(cast call $WETH "balanceOf(address)" $ANVIL_USER --rpc-url $LOCAL_RPC_URL 2>/dev/null)"
            echo "WBTC: $(cast call $WBTC "balanceOf(address)" $ANVIL_USER --rpc-url $LOCAL_RPC_URL 2>/dev/null)"
            echo "vUSD: $(cast call $VAULT_STABLECOIN "balanceOf(address)" $ANVIL_USER --rpc-url $LOCAL_RPC_URL 2>/dev/null)"
            
            # Vault metrics
            echo ""
            echo "🏦 Vault Metrics:"
            echo "Collateral Value: $(cast call $VAULT_ENGINE "getCollateralValue(address)" $ANVIL_USER --rpc-url $LOCAL_RPC_URL 2>/dev/null)"
            echo "WETH Deposited: $(cast call $VAULT_ENGINE "getCollateralBalanceOfUser(address,address)" $ANVIL_USER $WETH --rpc-url $LOCAL_RPC_URL 2>/dev/null)"
        else
            echo "❌ Contract addresses not set in .env"
            echo "🚀 Deploy first: make deploy-local"
        fi
        
        echo ""
        echo "🔄 Refreshing every 10 seconds... (Ctrl+C to stop)"
        sleep 10
    done
}

monitor_local