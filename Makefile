-include .env

deploy-sepolia :; forge script script/DeployRaffle.s.sol:DeployRaffle --rpc-url $(SEPOLIA_RPC_URL) --account sepoliaDeployPK --broadcast --verify --etherscan-api-key $(SEPOLIA_ETHERSCAN_API_KEY) -vvvvv
deploy-local :; forge script script/DeployRaffle.s.sol:DeployRaffle --broadcast -vvvv
fund-subscription-sepolia :; forge script script/Interactions.s.sol --tc FundSubscription --rpc-url ${SEPOLIA_RPC_URL} --account sepoliaDeployPK --broadcast