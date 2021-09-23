# reNFT Registry

reNFT registry is a collateral-free NFT P2P rent solution. Lender's NFT goes into the registry contract, whilst the renter gets assigned the renter role when the rent commences.

This protocol supports 1155 and 721 NFTs. You can lend a mixture of 721s and 1155s in a single transaction. A completmentary reNFT SDK library figures out the best way to pass the arguments to the smart contract to take benefit of the 1155s batchTransfer function to allow for the lowest possible gas for the user.

## Development

This repository uses [brownie eth](https://eth-brownie.readthedocs.io/en/stable/) as a smart contract development framework.

To deploy the contracts in a local blockchain, run

`brownie console`

From there you can `run('script_name_in_scripts_folder')` to deploy the pipeline.

To get access to a particular contract you have deployed, run `registry = Registry.at('address_where_registry_was_deployed')`

The above gives you the tools to actively test your contract. Brownie allows you to do more cool things, like forking the mainnet and deploying your contract, and testing its interaction with live contracts. Although, this is not required for our purposes.

To run the tests, simply run `brownie test`.

If you would like to deploy the contracts to a testnet, you can write `brownie run <name_of_script_in_scripts_folder> --network ropsten`, for example.

If you would like to verify the contract (this will show the contract code on Etherscan), you need to first get Etherscan API, and then using that env variable, start a console like so `ETHERSCAP_API=... brownie console --network ropsten`. When you are in there, get the instance of a contract `registry = Registry.at('contract_address')` and finally, `Registry.publish_source(registry)`.
