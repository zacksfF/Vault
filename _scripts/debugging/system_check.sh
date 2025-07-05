#!/bin/bash

source ../../.vault_env
source ../../.env

echo "🔧 SYSTEM DIAGNOSTIC"
echo "===================="

# Network check
echo "📡 NETWORK STATUS"
CHAIN_ID=$(cast chain-id --rpc-url $SEPOLIA_RPC_URL 2>/dev/null)
if [ $? -eq 0 ]; then
    echo "✅ Connected to chain ID: $CHAIN_ID"
else
    echo "❌ Network connection failed"
fi
echo ""

# Contract verification
echo "📋 CONTRACT STATUS"
VAULT_CODE=$(cast code $VAULT_ENGINE --rpc-url $SEPOLIA_RPC_URL 2>/dev/null | wc -c)
STABLE_CODE=$(cast code $VAULT_STABLECOIN --rpc-url $SEPOLIA_RPC_URL 2>/dev/null | wc -c)

echo "VaultEngine: $([ $VAULT_CODE -gt 10 ] && echo "✅ Deployed" || echo "❌ Not found")"
echo "VaultStablecoin: $([ $STABLE_CODE -gt 10 ] && echo "✅ Deployed" || echo "❌ Not found")"
echo ""

# User status
echo "👤 USER STATUS"
ETH_BALANCE=$(cast balance $USER_ADDRESS --rpc-url $SEPOLIA_RPC_URL 2>/dev/null)
echo "ETH Balance: $(cast to-ether $ETH_BALANCE) ETH"

HEALTH=$(cast call $VAULT_ENGINE "getHealthFactor(address)" $USER_ADDRESS --rpc-url $SEPOLIA_RPC_URL 2>/dev/null)
echo "Health Factor: $HEALTH"