#!/bin/bash

echo "🏠 LOCAL VAULT DEPLOYMENT"
echo "========================"

# Check if Anvil is running
if ! curl -s -X POST -H "Content-Type: application/json" \
   --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' \
   http://localhost:8545 > /dev/null; then
    echo "❌ Anvil not running!"
    echo "🚀 Start with: make anvil"
    exit 1
fi

# Load environment
source ../../.env

echo "🔧 Deploying to local Anvil..."
echo "RPC: $LOCAL_RPC_URL"
echo "User: $ANVIL_USER"

# Deploy contracts
forge script ../../script/DeployVault.s.sol:DeployVault \
    --rpc-url $LOCAL_RPC_URL \
    --private-key $ANVIL_PRIVATE_KEY \
    --broadcast \
    -v

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ DEPLOYMENT SUCCESSFUL!"
    echo ""
    echo "📋 UPDATE YOUR .env WITH THESE ADDRESSES:"
    echo "Check the deployment output above for contract addresses"
    echo ""
    echo "🎯 NEXT STEPS:"
    echo "1. Update VAULT_ENGINE, VAULT_STABLECOIN, WETH, WBTC in .env"
    echo "2. Run: make status"
    echo "3. Test with: make test-basic"
else
    echo "❌ Deployment failed!"
fi