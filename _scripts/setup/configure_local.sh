#!/bin/bash

echo "🏠 LOCAL ANVIL ENVIRONMENT SETUP"
echo "================================"

# Set local environment variables
cat > ../../.vault_local << 'EOF'
# Local Anvil Contract Addresses (update after deployment)
export VAULT_ENGINE=
export VAULT_STABLECOIN=
export WETH=
export WBTC=
export LOCAL_RPC_URL=http://localhost:8545
export ANVIL_PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
export ANVIL_USER=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
EOF

echo "Local environment configured!"
echo "📋 Run: source .vault_local"
echo "🚀 Start Anvil: make anvil"
echo "🏗️ Deploy: make deploy-local"