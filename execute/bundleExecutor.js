const blindBackrunJSON = require('./utils/BlindBackrun.json')
const ethers = require('ethers')
const Web3EthAbi = require('web3-eth-abi')
const config = require('./utils/config.json')

class BundleExecutor {
    constructor(_signer, _flashbotsBundleProvider, _contractAddress, _bundleAPI, _percentageToKeep) {
        this.signer = _signer
        this.flashBotsBundleProvider = _flashbotsBundleProvider
        this.contract = new ethers.Contract(_contractAddress, blindBackrunJSON, this.signer)
        this.connectionInfo = {
            url: _bundleAPI,
        }
        this.nextID = 1
        this.percentageToKeep = _percentageToKeep
        
        console.log('Successfully created BundleExecutor')
    }

    /**
     * Executes arbitrage by sending bundles to the MatchMaker for a given transaction hash.
     * @param {string} _firstPair - The first pair's address.
     * @param {string} _secondPair - The second pair's address.
     * @param {string} _txHash - The transaction hash to execute the bundles on.
     */
    async execute(_firstPair, _secondPair, _txHash) {
        console.log("Sending bundles to MatchMaker for tx:", _txHash)
        const [bundleOneWithParams, bundleTwoWithParams] = await this.buildBundles(_firstPair, _secondPair, _txHash)
        await this.sendBundleToMatchMaker(bundleOneWithParams, bundleTwoWithParams)
    }

    /**
     * Sends bundles to the MatchMaker.
     * @param {Object} _bundleOneWithParams - The first bundle with parameters.
     * @param {Object} _bundleTwoWithParams - The second bundle with parameters.
     */
    async sendBundleToMatchMaker(_bundleOneWithParams, _bundleTwoWithParams) {
        await Promise.all([
            this.sendBundle(_bundleOneWithParams),
            this.sendBundle(_bundleTwoWithParams)
        ])
    }
    
    // At the moment this function isn't used at all because the MatchMaker doesn't support simulation against searcher bundles yet.
    async simBundle(_bundle) {
        const request = JSON.stringify(this.prepareRelayRequest([_bundle], 'mev_simBundle'))
        const response = await this.request(request)
        return response
    }

    /**
     * Sends a bundle.
     * @param {Object} _bundle - The bundle to sending.
     * @returns {Promise<Object>} The response from sending the bundle.
     */
    async sendBundle(_bundle) {
        const request = JSON.stringify(this.prepareRelayRequest([_bundle], 'mev_sendBundle'))
        const response = await this.request(request)
        console.log("response:", response)
    }

    /**
     * Prepares a relay request with the given method and parameters.
     * @param {Array} _params - The parameters for the relay request.
     * @param {string} _method - The method for the relay request.
     * @returns {Object} The prepared relay request.
     */
    prepareRelayRequest(_params, _method) {  
        return {
            method: _method,
            params: _params,
            id: this.nextID++,
            jsonrpc: '2.0'
        }
    }

    /**
     * Sends a request with the specified payload.
     * @param {string} _request - The request payload.
     * @returns {Promise<Object>} The response from the request.
     */
    async request(_request) {
        this.connectionInfo.headers = {
          'X-Flashbots-Signature': `${await this.signer.address}:${await this.signer.signMessage(ethers.utils.id(_request))}`
        }
        console.log("Making request:", _request)
        let resp = await ethers.utils.fetchJson(this.connectionInfo, _request)
        return resp
      }
    
      /**
     * Builds bundles for the given pair addresses and transaction hash.
     * @dev This function outputs two bundles, one for each potential trade direction. Only one will succeed depending on the direction of the user's trade.
     * @param {string} _firstPair - The first pair's address.
     * @param {string} _secondPair - The second pair's address.
     * @param {string} _txHash - The transaction hash to backrun.
     * @returns {Promise<Array>} An array containing two bundles backrunning the user's _txHash.
     */
    async buildBundles(_firstPair, _secondPair, _txHash) {
        let blockNumber = Number(await this.signer.provider.getBlockNumber())
        console.log("Current block number:", blockNumber)
        console.log("Building bundles")

        let bundleTransactionOptions = {
            gasPrice: (await this.signer.provider.getGasPrice()), // This is *extremely* naive. 
            gasLimit: ethers.BigNumber.from(400000),
            nonce: await this.signer.getTransactionCount(),
        } 

        const types = [
            'address',
            'address',
            'uint256'
        ]
        
        const valuesFirstTrade = [
            _firstPair,
            _secondPair,
            this.percentageToKeep  
        ]

        let paramsFirstTrade = Web3EthAbi.encodeParameters(types, valuesFirstTrade)

        let bundleOneTransaction = await this.contract.populateTransaction.makeFlashLoan(
            config.mainnetWETHAddress,
            ethers.BigNumber.from(10**21).toString(),
            paramsFirstTrade,
            bundleTransactionOptions
        )

        let bundleOne = [
            {hash: _txHash},
            {tx: await this.signer.signTransaction(bundleOneTransaction), canRevert: false},
        ]

        const valuesSecondTrade = [
            _secondPair,
            _firstPair,
            this.percentageToKeep  
        ]

        let paramsSecondTrade = Web3EthAbi.encodeParameters(types, valuesSecondTrade)

        let bundleTwoTransaction = await this.contract.populateTransaction.makeFlashLoan(
            config.mainnetWETHAddress,
            ethers.BigNumber.from(10**21).toString(),
            paramsSecondTrade,
            bundleTransactionOptions
        )       

        let bundleTwo = [
            {hash: _txHash},
            {tx: await this.signer.signTransaction(bundleTwoTransaction), canRevert: false},
        ]
        
        const bundleOneWithParams = this.bundleWithParams(blockNumber + 1, 10, bundleOne)
        const bundleTwoWithParams = this.bundleWithParams(blockNumber + 1, 10, bundleTwo)
        return [bundleOneWithParams, bundleTwoWithParams]
    }
    
    /**
     * Adds parameters to a bundle for the given block number and blocks to try.
     * @notice The version number might need to change in the future. This is the only one that works at the moment.
     * @param {number} _blockNumber - The block number to submit initially for.
     * @param {number} _blocksToTry - The number of blocks to try.
     * @param {Array} _bundle - The bundle to add parameters to.
     * @returns {Object} The bundle with parameters.
     */
    bundleWithParams(_blockNumber, _blocksToTry, _bundle) {
        console.log("Submitting bundles for block:", _blockNumber, "through block:", _blockNumber + _blocksToTry)
        console.log("hexvalue    :", ethers.utils.hexValue(_blockNumber))
        console.log("Other method:", "0x" + _blockNumber.toString(16))
        
        return {
            version:"beta-1", //@NOTICE: This is the only version that works at the moment.
            inclusion: {
                block: ethers.utils.hexValue(_blockNumber),
                maxBlock: ethers.utils.hexValue(_blockNumber + _blocksToTry)
            },
            body: _bundle,
        }
    }
}


module.exports = BundleExecutor