# Vault: A Decentralized Stablecoin Protocol  

Vault is a **decentralized, overcollateralized stablecoin protocol** built on **Ethereum**. It allows users to deposit **WETH (Wrapped Ether) and WBTC (Wrapped Bitcoin)** as collateral to mint a **USD-pegged stablecoin**, ensuring a secure and trustless financial ecosystem.  

## 🚀 Features  

- **🔹 Overcollateralized Stability** – Users must provide more collateral than they mint, ensuring the stablecoin remains fully backed.  
- **🔹 Decentralized & Trustless** – Governed by smart contracts, eliminating intermediaries.  
- **🔹 Efficient Liquidations** – Automatic liquidation mechanisms prevent undercollateralization.  
- **🔹 Seamless Redemption** – Burn stablecoins anytime to reclaim WETH/WBTC collateral.  
- **🔹 Gas-Optimized & Scalable** – Built with Solidity and Foundry for efficient execution.  
- **🔹 On-Chain Transparency** – All transactions and collateral ratios are verifiable on-chain.  

## 📜 How It Works  

1. **Deposit Collateral** – Users deposit WETH/WBTC into Vault.  
2. **Mint Stablecoins** – Based on the collateral ratio, users mint USD-pegged stablecoins.  
3. **Maintain Collateralization** – Users must keep their collateral above the minimum threshold.  
4. **Redemption & Liquidation** – If collateral falls below the required level, liquidations occur.  







# Getting Started
### Clone the Repository  
```sh
git clone https://github.com/zacksfF/Vault.git  
cd Vault
forge build 
```

## Usage
----
### **Run Local Node**  
```sh
make anvil
```

### **Deploy**  
```sh
make deploy
```

### **Deploy to Sepolia**  
Set up **.env** variables, then:  
```sh
make deploy ARGS="--network sepolia"
```

## **🧪 Testing**  
```sh
forge test       # Run tests  
forge coverage   # Generate coverage report  
forge snapshot   # Estimate gas costs  
```

## **🔧 Scripts**  

### **Interact with Contracts (Sepolia Example)**  

1. **Get WETH**  
```sh
cast send <WETH_CONTRACT> "deposit()" --value 0.1ether --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
```

2. **Approve WETH**  
```sh
cast send <WETH_CONTRACT> "approve(address,uint256)" <VAULT_CONTRACT> 1ether --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
```

3. **Deposit & Mint Stablecoin**  
```sh
cast send <VAULT_CONTRACT> "depositCollateralAndMintDsc(address,uint256,uint256)" <WETH_CONTRACT> 0.1ether 0.01ether --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
```

## **📌 Formatting & Linting**  
```sh
forge fmt      # Format code  
slither .      # Run security analysis  
```

## **📄 Additional Commands**  
```sh
make clean      # Clean project  
make build      # Compile contracts  
make update     # Update dependencies  
```

# Auditing in progress
