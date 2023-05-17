const yargs = require('yargs');
const ethers = require('ethers')
const EventSource = require('eventsource');
const PoolManager = require('./poolManager.js')
const BundleExecutor = require('./bundleExecutor.js')
const { FlashbotsBundleProvider} = require('@flashbots/ethers-provider-bundle')
const config = require('./utils/config.json')
require('dotenv').config();

async function main() {
    // Parse the command line argument for the network to use
    const argv = yargs(process.argv.slice(2))
    .usage('Usage: $0 [options]')
    .example('$0 -n network', 'Execute bundles on mainnet')
    .options({
        network: {
            alias: 'n',
            describe: 'The network (mainnet, goerli) to use for',
            demandOption: true,
            type: 'string'
        },
    })
    
    .help()
    .argv;
    const provider = new ethers.providers.JsonRpcProvider(process.env.rpcUrl)
    const signer = new ethers.Wallet(process.env.privateKey, provider)
    const flashbotsBundleProvider = await FlashbotsBundleProvider.create(provider, signer)
    const poolManager = new PoolManager(provider, argv.network)

    console.log("Loaded wallet with address:", signer.address)

    let MatchMaker, bundleExecutor;

    if (argv.network == 'mainnet') {
        MatchMaker = new EventSource(config.mainnetMatchMaker)
        bundleExecutor = new BundleExecutor(signer, flashbotsBundleProvider, process.env.executorContractAddress, config.mainnetBundleAPI, config.percentageToKeep)
    } else if (argv.network == 'goerli') {
        MatchMaker = new EventSource(config.goerliMatchMaker)
        bundleExecutor = new BundleExecutor(signer, flashbotsBundleProvider, process.env.executorContractAddress, config.goerliBundleAPI, config.percentageToKeep)
    }

    MatchMaker.onmessage = async (event) => {
        // Handle the incoming event
        const data = JSON.parse(event.data)
        console.log("New transaction with hash:", data.hash)

        if (data.logs == null) {return}

        // Loop through all the logs in the transaction
        console.log("Transaction has logs, parsing them")
        for (let i = 0; i < data.logs.length; i++) {
            console.log(data.logs[i])
            if (data.logs[i].topics[0] != config.syncTopic) {continue} // Skip if it isn't a sync event
            const firstPair = data.logs[i].address // Get the address of the first pair, which is the address the logs are coming from
    
            console.log("Transaction trading on Uniswap v2 pool detected! Pool address:", firstPair)
    
            const [token0, token1, factoryToCheck] = await poolManager.checkPool(firstPair) // Get the pool and the other factory we need to check
            if (token0 == false || token1 == false || factoryToCheck == false) {return} // These are false if the pool does not have a WETH pair
            
            const secondPair = await poolManager.checkFactory(factoryToCheck, token0, token1) // Check if the other factory has the pool too
            if (secondPair == false) {return} // If it doesn't, stop here
    
            await bundleExecutor.execute(firstPair, secondPair, data.hash) // Execute the bundle if we've made it this far
        }

    };
    MatchMaker.onerror = (error) => {
        // Handle the error
        console.error(error);
    }
}

main()