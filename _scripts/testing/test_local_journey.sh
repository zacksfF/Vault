#!/bin/bash

source ../../.env

echo "🧪 LOCAL VAULT TESTING"
echo "======================"

# Check environment
if [ -z "$VAULT_ENGINE" ]; then
    echo "❌ Contract addresses not set!"
    echo "🚀 Deploy first: make deploy-local"
    exit 1
fi

PASSED=0
FAILED=0

test_result() {
    if [ $1 -eq 0 ]; then
        echo "✅ $2"
        ((PASSED++))
    else
        echo "❌ $2"
        ((FAILED++))
    fi
}

echo "Starting comprehensive local test..."

# Test 1: Get tokens
echo "Test 1: Getting test tokens..."
cast send $WETH "faucet(uint256)" 20000000000000000000 --rpc-url $LOCAL_RPC_URL --private-key $ANVIL_PRIVATE_KEY > /dev/null 2>&1
test_result $? "WETH token acquisition"

cast send $WBTC "faucet(uint256)" 200000000 --rpc-url $LOCAL_RPC_URL --private-key $ANVIL_PRIVATE_KEY > /dev/null 2>&1
test_result $? "WBTC token acquisition"

# Test 2: Approve tokens
echo "Test 2: Approving tokens..."
cast send $WETH "approve(address,uint256)" $VAULT_ENGINE 10000000000000000000 --rpc-url $LOCAL_RPC_URL --private-key $ANVIL_PRIVATE_KEY > /dev/null 2>&1
test_result $? "WETH approval"

# Test 3: Deposit collateral
echo "Test 3: Depositing collateral..."
cast send $VAULT_ENGINE "depositCollateral(address,uint256)" $WETH 5000000000000000000 --rpc-url $LOCAL_RPC_URL --private-key $ANVIL_PRIVATE_KEY > /dev/null 2>&1
test_result $? "WETH collateral deposit"

# Test 4: Mint stablecoins
echo "Test 4: Minting stablecoins..."
cast send $VAULT_ENGINE "mintStablecoin(uint256)" 2000000000000000000000 --rpc-url $LOCAL_RPC_URL --private-key $ANVIL_PRIVATE_KEY > /dev/null 2>&1
test_result $? "vUSD minting"

# Test 5: Burn stablecoins
echo "Test 5: Burning stablecoins..."
cast send $VAULT_ENGINE "burnStablecoin(uint256)" 500000000000000000000 --rpc-url $LOCAL_RPC_URL --private-key $ANVIL_PRIVATE_KEY > /dev/null 2>&1
test_result $? "vUSD burning"

# Test 6: Redeem collateral
echo "Test 6: Redeeming collateral..."
cast send $VAULT_ENGINE "redeemCollateral(address,uint256)" $WETH 1000000000000000000 --rpc-url $LOCAL_RPC_URL --private-key $ANVIL_PRIVATE_KEY > /dev/null 2>&1
test_result $? "Collateral redemption"

echo ""
echo "🎯 LOCAL TEST RESULTS"
echo "====================="
echo "Passed: $PASSED"
echo "Failed: $FAILED"
echo "Total:  $((PASSED + FAILED))"

if [ $FAILED -eq 0 ]; then
    echo "🎉 ALL LOCAL TESTS PASSED!"
else
    echo "⚠️ Some tests failed"
fi

echo ""
echo "📊 Final Status:"
echo "vUSD Balance: $(cast call $VAULT_STABLECOIN "balanceOf(address)" $ANVIL_USER --rpc-url $LOCAL_RPC_URL)"
echo "Health Factor: $(cast call $VAULT_ENGINE "getHealthFactor(address)" $ANVIL_USER --rpc-url $LOCAL_RPC_URL)"