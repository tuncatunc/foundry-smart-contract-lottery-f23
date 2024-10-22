-include .env

deploy-sepolia :; forge script script/DeployRaffle.s.sol:DeployRaffle --rpc-url $(SEPOLIA_RPC_URL) --private-key $(SEPOLIA_PRIVATE_KEY) --broadcast --verify --etherscan-api-key $(SEPOLIA_ETHERSCAN_API_KEY) -vvvv 
deploy-local :; forge script script/DeployRaffle.s.sol:DeployRaffle --broadcast -vvvv