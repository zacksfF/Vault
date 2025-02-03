-include .env

.PHONY: all test clean deploy fund help install snapshot format anvil 

DEFAULT_ANVILT_KEU := 0x..........


help 


all: 

# clean the repo 
clean: 

# remove modules 
remove: 

install: 

#update Dependecies 
update: 

# build 
build: 

# test 

# coverage
coverage: 

# snapshot
snapshot: 

# format 
format: 

anvil:

NETWORK_ARGS := --rpc-url http://localhost:8545 --private-key $(DEFAULT_ANVIL_KEY) --broadcast

ifeq ($(findstring --network sepolia,$(ARGS)),--network sepolia)
	NETWORK_ARGS := --rpc-url $(SEPOLIA_RPC_URL) --private-key $(PRIVATE_KEY) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvvv
endif

deploy:
	@forge script script/DeployDSC.s.sol:DeployDSC $(NETWORK_ARGS)