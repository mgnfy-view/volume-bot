all :  remove install build

clean :; forge clean

remove :; rm -rf .gitmodules && rm -rf .git/modules/* && rm -rf lib && touch .gitmodules && git add . && git commit -m "modules"

install :; forge install foundry-rs/forge-std --no-commit && forge install openzeppelin/openzeppelin-contracts --no-commit && forge install aave/aave-v3-core --no-commit && forge install uniswap/v2-periphery --no-commit

update :; forge update

compile :; forge compile

build :; forge build

test :; forge test --fork-url ${RPC_URL}

snapshot :; forge snapshot

format-sol :; forge fmt

anvil :; anvil --fork-url ${RPC_URL}

precommit :; forge fmt && git add .