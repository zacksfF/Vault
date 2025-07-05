# Vault Protocol

**A decentralized, overcollateralized stablecoin protocol built on Ethereum**

## What is Vault?

Vault Protocol allows users to deposit **WETH** and **WBTC** as collateral to mint **vUSD**, a USD-pegged stablecoin. The protocol ensures stability through **200% overcollateralization** and **automatic liquidation** mechanisms.

## How It Works

```
1. Deposit Collateral (WETH/WBTC) → 2. Mint vUSD (up to 50% of collateral value) → 3. Maintain Health Factor > 1.0
```

- **Deposit**: Lock WETH or WBTC as collateral
- **Mint**: Create vUSD stablecoins (max 50% of collateral value)
- **Health Factor**: Must stay above 1.0 to avoid liquidation
- **Liquidation**: 10% bonus for liquidators who restore protocol health

## Technical Architecture

| Component | Purpose |
|-----------|---------|
| **VaultEngine** | Core protocol logic, collateral management |
| **VaultStablecoin (vUSD)** | ERC20 stablecoin token pegged to USD |
| **PriceOracle** | Chainlink price feeds with staleness protection |
| **MockERC20** | Test tokens for development |

## Key Parameters

- **Liquidation Threshold**: 50% (200% overcollateralization)
- **Liquidation Bonus**: 10%
- **Minimum Health Factor**: 1.0
- **Supported Collateral**: WETH, WBTC
- **Price Feeds**: Chainlink ETH/USD, BTC/USD

## Quick Start

### **Local Development**
```bash
# Start local blockchain
make anvil

# Deploy contracts
make deploy-local

# Run tests
make test-basic
```

### **Basic Operations**
```bash
# Get test tokens
cast send $WETH "faucet(uint256)" 10000000000000000000 --rpc-url $LOCAL_RPC_URL --private-key $ANVIL_PRIVATE_KEY

# Deposit collateral
cast send $WETH "approve(address,uint256)" $VAULT_ENGINE 5000000000000000000 --rpc-url $LOCAL_RPC_URL --private-key $ANVIL_PRIVATE_KEY
cast send $VAULT_ENGINE "depositCollateral(address,uint256)" $WETH 3000000000000000000 --rpc-url $LOCAL_RPC_URL --private-key $ANVIL_PRIVATE_KEY

# Mint stablecoins
cast send $VAULT_ENGINE "mintStablecoin(uint256)" 1000000000000000000000 --rpc-url $LOCAL_RPC_URL --private-key $ANVIL_PRIVATE_KEY
```

## Contract Addresses (Local)

Update your `.env` after deployment:
```bash
VAULT_ENGINE=0x...
VAULT_STABLECOIN=0x...
WETH=0x...
WBTC=0x...
```

## 🛡️ Security Features

- **Reentrancy Protection**: All state-changing functions protected
- **Price Feed Validation**: 3-hour staleness timeout
- **Overcollateralization**: 200% minimum ratio
- **Liquidation Mechanism**: Automatic position closure
- **Access Control**: Owner-based minting restrictions

## 🎯 Make Commands

| Command | Description |
|---------|-------------|
| `make anvil` | Start local blockchain |
| `make deploy-local` | Deploy to local Anvil |
| `make test-basic` | Run basic functionality tests |
| `make monitor` | Real-time vault monitoring |
| `make status` | Check contract status |


## ⚡ Example Usage

```bash
# Complete user journey
make deploy-local           # Deploy contracts
make test-basic            # Test all functions
make monitor               # Watch your positions
```