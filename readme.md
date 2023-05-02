# simple-blind-arbitrage
This repository contains a simple, mechanical system for blindly submitting atomic arbitrage opportunities to the Flashbots MEV-Share mathcmaker. For more details on MEV-Share please see this [beta launch announcement](https://collective.flashbots.net/t/announcing-mev-share-beta/1650) and the [docs](https://docs.flashbots.net/flashbots-mev-share/overview). For high level design details see [the design document on the Flashbots Forum](https://collective.flashbots.net/t/mev-share-programmably-private-orderflow-to-share-mev-with-users/1264).

Although user trade details are hidden by default to prevent frontrunning, this script can atomically backrun Uniswap v2 transactions form the Matchmaker **by calculating the optimal arbitrage between two Uniswap v2 pools entirely on-chain**. Off-chain logic is relatively simple and no trade details are needed beyond the pool that the user is trading on to discover and attempt to execute atomic arbitrage opportunities.

Contained in this repository are two things. First, a [smart contract](/src/blindBackrun.sol) that attempts to execute an atomic arbitrage between two Uniswap v2 pools. Second, a [script](/execute/index.js) that listens to the Flashbots MEV-Share Matchmaker and submits attempted arbitrages.

This script is intended to be used as an example of blind atomic MEV and how to integrate with the Flashbots MEV-Share Matchmaker. Please do your own research and understand the code before using it or putting your money in it. We hope that you will use this code to build your own MEV strategies and share them with the community.

### Installation

1. Clone the repository:
```bash
git clone https://github.com/yourusername/simple-blind-arbitrage.git
```

2. Change to the project directory:
```bash
cd simple-blind-arbitrage/execute
```

3. Install the required dependencies:
```bash
npm install
```

Note that this repo also uses [Foundry](https://github.com/foundry-rs/foundry).

### Setup
1. Deploy the [smart contract](/src/blindBackrun.sol) using your preferred method. The dependencies may need to be changed if not using Foundry. Further, you must provide the WETH address on your deployment network as a constructor argument. Finally, please note the account that deploys the contract is the only one that can execute arbitrages.
2. Transfer WETH to your contract.
3. Setup your .env file by copying the template and filling it out. 

```makefile
rpcUrl=<YOUR_RPC_URL>
privateKey=<YOUR_PRIVATE_KEY>
executorContractAddress=<CONTRACT_ADDRESS>
```
Replace <YOUR_RPC_URL> with the URL of your Ethereum RPC provider, <YOUR_PRIVATE_KEY> with the private key of the Ethereum address you want to use for executing the transactions, and <CONTRACT_ADDRESS> with the address of the deployed BlindBackrun smart contract from above.

By default this bot bids 50% of its profits to `block.coinbase` but this can be configured by changing `percentageToKeep` in the [config file](./execute/utils/config.json). After a short time after open sourcing it is likely that you will need to increase `percentageToKeep` for your bundles to be competitive.

### Usage
To start listening to the Flashbots MEV-Share Matchmaker and submitting blind arbitrage transactions, run the following command:
```bash
node index.js -n <network>
```
Replace <network> with either mainnet or goerli depending on the network you want to use. 

### Testing
A test in Foundry for the smart contract is provided. Please test using a fork of Goerli, from the root folder please run `forge test -f <GOERLI_RPC_URL>` and run with `-vv` to display `console.log()`s with relevant information during execution.

If you would like to test the monitoring and execution script, please configure for Goerli and run `node index.js -n goerli`.

### Prerequisites
Before using this tool, make sure you have the following software installed on your system:

* Node.js (version 14.x or higher)
* npm (usually comes with Node.js)
* Foundry is optional for smart contract development/testing/deployment

### Security
The tool requires a private key for signing transactions. Make sure you don't share your private key or .env file with anyone or commit it to a public repository.

### Contributing, improvements, and further work
Contributions are welcome! If you'd like to contribute to this project, feel free to open a pull request. `simple-blind-arbitrage` is a starting point that can be extended to encompass other MEV strategies. Here are a few improvements we would like to see:
- Extending the bot to arb across more pools than two.
- Using a [specialized smart contract to more efficiently query the chain](https://github.com/flashbots/simple-arbitrage/blob/master/contracts/UniswapFlashQuery.sol) for information. All the calls made off-chain can in theory be replaced with a single call.
- Loading all Uniswap v2 pairs upfront instead of checking for them at runtime.
- Using flashloans instead of relying on upfront capital.
- Checking for pools from other Uniswap v2 forks beyond Uniswap and Sushiswap.
- Arbing coins that are not WETH (DAI, USDC, etc).
- Integrating other DEXes.
- Submitting with custom hints that allow other searchers to build on your bundles while retaining bundle privacy.

### License
This project is licensed under the MIT License - see the LICENSE file for details.