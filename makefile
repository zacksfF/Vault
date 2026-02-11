# Vault Protocol Makefile
-include .env

.PHONY: all test clean deploy-local deploy-sepolia install snapshot format anvil help

# Default Anvil key for local development
DEFAULT_ANVIL_KEY := 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
ANVIL_USER := 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266

help: ## Show this help message
	@echo " Vault Protocol Development Commands"
	@echo "====================================="
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "%-20s %s\n", $$1, $$2}'

all: clean remove install update build ## Clean, install, and build everything

# Environment setup
install: ## Install dependencies
	forge install chainaccess/foundry-devops@0.0.11 --no-commit
	forge install smartcontractkit/chainlink-brownie-contracts@0.6.1 --no-commit
	forge install openzeppelin/openzeppelin-contracts@v4.8.3 --no-commit

clean: ## Clean the repo
	forge clean

remove: ## Remove modules
	rm -rf .gitmodules && rm -rf .git/modules/* && rm -rf lib && touch .gitmodules && git add . && git commit -m "modules"

update: ## Update dependencies
	forge update

build: ## Build contracts
	forge build

test: ## Run tests
	forge test

snapshot: ## Create gas snapshot
	forge snapshot

format: ## Format code
	forge fmt

# Anvil local blockchain
anvil: ## Start Anvil local blockchain
	@echo " Starting Anvil local blockchain..."
	@anvil --host 0.0.0.0 --port 8545 --chain-id 31337

anvil-bg: ## Start Anvil in background
	@echo " Starting Anvil in background..."
	@anvil --host 0.0.0.0 --port 8545 --chain-id 31337 > anvil.log 2>&1 &
	@echo "Anvil PID: $$!"

stop-anvil: ## Stop Anvil
	@pkill -f anvil || echo "Anvil not running"

# Local deployment
deploy-local: ## Deploy to local Anvil
	@echo " Deploying to local Anvil..."
	@forge script script/DeployVault.s.sol:DeployVault \
		--rpc-url $(LOCAL_RPC_URL) \
		--private-key $(ANVIL_PRIVATE_KEY) \
		--broadcast -v

# Production deployment  
deploy-sepolia: ## Deploy to Sepolia testnet
	@echo " Deploying to Sepolia..."
	@forge script script/DeployVault.s.sol:DeployVault \
		--rpc-url $(SEPOLIA_RPC_URL) \
		--private-key $(PRIVATE_KEY) \
		--broadcast \
		--verify \
		--etherscan-api-key $(ETHERSCAN_API_KEY) \
		-vvv

# Quick operations
setup-local: ## Setup local environment with contracts
	@echo "🔧 Setting up local environment..."
	@make deploy-local
	@echo " Local deployment complete!"
	@echo " Don't forget to update contract addresses in .env"

status: ## Show current status
	@echo " VAULT PROTOCOL STATUS"
	@echo "======================="
	@echo "Network: Local Anvil"
	@echo "RPC: $(LOCAL_RPC_URL)"
	@echo "User: $(ANVIL_USER)"
	@if [ -n "$(VAULT_ENGINE)" ]; then \
		echo "VaultEngine: $(VAULT_ENGINE)"; \
		echo "VaultStablecoin: $(VAULT_STABLECOIN)"; \
		echo "WETH: $(WETH)"; \
		echo "WBTC: $(WBTC)"; \
	else \
		echo " Contract addresses not set in .env"; \
	fi

check-balance: ## Check ETH balance
	@echo " ETH Balance: $$(cast balance $(ANVIL_USER) --rpc-url $(LOCAL_RPC_URL) | head -c 10) wei"

# Testing shortcuts
test-basic: ## Run basic user journey test
	@cd _scripts/testing && ./test_local_journey.sh

test-all: ## Run all tests
	@cd _scripts/testing && ./run_all_tests.sh

# Monitoring
monitor: ## Start health monitor
	@cd _scripts/monitoring && ./local_monitor.sh

dashboard: ## Show balance dashboard
	@cd _scripts/monitoring && ./balance_dashboard.sh

# Emergency
emergency: ## Emergency tools
	@cd _scripts/debugging && ./emergency_tools.sh