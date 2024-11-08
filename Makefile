-include .env

build :; forge build

test :; forge test

install :; forge install cyfrin/foundry-devops@0.2.3 --no-commit && \
forge install smartcontractkit/chainlink-brownie-contracts@1.3.0 --no-commit && \
forge install foundry-rs/forge-std@v1.8.2 --no-commit

deploy-sepolia :
	forge script script/DeployRaffle.s.sol:DeployRaffle --rpc-url ${SEPOLIA_RPC_URL} --account sepoliaDeployPK --broadcast --verify --etherscan-api-key ${ETHERSCAN_API_KEY} -vvvvv --slow

deploy-fuji :
	forge script script/DeployRaffle.s.sol:DeployRaffle --rpc-url ${FUJI_RPC_URL} --account sepoliaDeployPK --broadcast --verify --etherscan-api-key ${ETHERSCAN_API_KEY} -vvvvv --slow
	
deploy-local :; forge script script/DeployRaffle.s.sol:DeployRaffle --broadcast -vvvv
