const { sqrt } = require("mathjs")

async function main() {

//     pair: 0x06da0fd433C1A5d7a4faa01111c044910A184553
//   reserve0: 5223477654411854874230
//   reserve1: 9531599938393
//   pair: 0x0d4a11d5EEaaC28EC3F61d100daF4d40471f1852
//   reserve0: 16565267689260437996912
//   reserve1: 29810100686159

    let [firstPair, secondPair] = await getPairsForETHUSDTTest()

    console.log("firstPair:", firstPair)

    let amountIn = newGetOptimalPositionSizeDoubleHop(firstPair, secondPair)
    console.log("amountIn:", amountIn.toString())
}

function getPairsForETHUSDTTest() {
    let firstPair = {
        reserve0 : 5223477654411854874230,
        reserve1 : 9531599938393
    }

    let secondPair = {
        reserve0: 16565267689260437996912,
        reserve1: 29810100686159
    }
    return [firstPair, secondPair]
}

function getPairsForETHUSDCTest() {
    let firstPair = {
        reserve0 : 16720388640448,
        reserve1 : 9324009724506788807549
    }

    let secondPair = {
        reserve0: 29577866519235,
        reserve1: 16692735360143160851015
    }
    return firstPair, secondPair
}

function newGetOptimalPositionSizeDoubleHop(
        firstPairReserves,
        secondPairReserves
    ) {
        // reserve 0 = usdc
        // reserve 1 = weth
        const uniswappyFee = 0.997

        let firstPairPrice = firstPairReserves['reserve0']/firstPairReserves['reserve1']
        let secondPairPrice = secondPairReserves['reserve1']/secondPairReserves['reserve0']

        console.log('firstPairPrice:', firstPairPrice.toString())
        console.log('secondPairPrice:', secondPairPrice.toString())
        
        const numerator = sqrt(uniswappyFee * uniswappyFee * firstPairPrice * secondPairPrice) - 1
        console.log('numberator presqrt:', uniswappyFee * uniswappyFee * firstPairPrice * secondPairPrice)
        console.log('numerator:', numerator.toString())
        const denominatorPart1 = (uniswappyFee)/firstPairReserves['reserve1']
        console.log('denom part1:', denominatorPart1.toString())
        const denominatorPart2 = (uniswappyFee * uniswappyFee * firstPairPrice)/secondPairReserves['reserve0']
        console.log('denom part2:', denominatorPart2.toString())
        const denominator = denominatorPart1 + denominatorPart2
        console.log('denom:', denominator.toString())
        const amountIn = Math.floor(numerator/denominator)
        return amountIn
    }
    
    
    /**
     * Function for finding the optimal position size of WETH to trade in a double hop scenario.
     * E.g. given two WETH/DAI pairs find the optimal amount of WETH to trade such that the amount of WETH you get out is maximized.
     * @param {reserves} firstPairReserves the reserves of a pair. This assumes the reserves are WETH and SwapToken, and are in the format output by getReserves() on the Uniswap DAO
     * @param {reserves} secondPairReserves the reserves of a pair. This assumes the reserves are WETH and SwapToken, and are in the format output by getReserves() on the Uniswap DAO
     * @param {address} swapTokenAddress an address of a token being swapped for in a reserve
     */
function getOptimalPositionSizeDoubleHop(firstPairReserves, secondPairReserves, swapTokenAddress){
        const uniswappyFee = 0.997

        let firstPairPrice = firstPairReserves[swapTokenAddress]/firstPairReserves[constants.WETH_ADDRESS]
        let secondPairPrice = secondPairReserves[constants.WETH_ADDRESS]/secondPairReserves[swapTokenAddress]

        const numerator = sqrt(uniswappyFee * uniswappyFee * firstPairPrice * secondPairPrice) - 1
        const denominatorPart1 = (uniswappyFee)/firstPairReserves[constants.WETH_ADDRESS]
        const denominatorPart2 = (uniswappyFee * uniswappyFee * firstPairPrice)/secondPairReserves[swapTokenAddress]
        const denominator = denominatorPart1 + denominatorPart2
        const amountIn = Math.floor(numerator/denominator)
        return amountIn
    }

main()