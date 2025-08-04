-include .env

.PHONY: all test clean deploy help install format anvil

DEFAULT_ANVIL_KEY := 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

help:
	@echo "Usage:"
	@echo "  make deploy [ARGS=...]\n    example: make deploy ARGS=\"--network amoy\""
	@echo ""
	@echo "  make fund [ARGS=...]\n    example: make deploy ARGS=\"--network amoy\""

all: clean install update build

# Clean the repo
clean  :; forge clean

install :; forge install OpenZeppelin/openzeppelin-contracts && forge install smartcontractkit/chainlink-brownie-contracts && forge install cyfrin/foundry-devops && forge install foundry-rs/forge-std

# Update Dependencies
update:; forge update

build:; forge build

test:; forge test

format :; forge fmt

anvil :; anvil -m 'test test test test test test test test test test test junk' --steps-tracing --block-time 10

createAccount:
	@cast wallet import --interactive default

NETWORK_ARGS := --rpc-url http://localhost:8545 --private-key $(DEFAULT_ANVIL_KEY) --broadcast

ifeq ($(findstring --network amoy,$(ARGS)),--network amoy)
	NETWORK_ARGS := --rpc-url $(AMOY_RPC_URL) --account $(ACCOUNT) --broadcast --verify --verifier custom --verifier-api-key $(ETHERSCAN_API_KEY) --verifier-url https://api.etherscan.io/v2/api?chainid=80002
endif

deploy:
	@forge script script/DeployProposalVoting.s.sol:DeployProposalVoting $(NETWORK_ARGS)

createProposal:
	@forge script script/Interactions.s.sol:CreateProposal $(NETWORK_ARGS)

voteProposal:
	@forge script script/Interactions.s.sol:VoteProposal $(NETWORK_ARGS)

getProposals:
	@forge script script/Interactions.s.sol:GetProposals $(NETWORK_ARGS)

setAutomationForwarder:
	@forge script script/Interactions.s.sol:SetAutomationForwarder $(NETWORK_ARGS)