pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/TokenForTesting.sol";
import "../src/blindBackrunDebug.sol";
import "openzeppelin/token/ERC20/IERC20.sol";
import "openzeppelin/token/ERC20/ERC20.sol";

error Unauthorized();

interface IUniswapFactory {
    function getPair(address tokenA, address tokenB) external view returns (address pair);
}

interface IUniswapV2Router {
    function swapExactETHForTokens(
        uint amountOutMin, 
        address[] calldata path,
        address to, 
        uint deadline
    ) external payable returns (uint[] memory amounts);
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
}

contract BlindBackrunTest is Test {
    using SafeMath for uint256;
    struct PairReserves {
        uint256 reserve0;
        uint256 reserve1;
        uint256 price;
        bool isWETHZero;
    }

    BlindBackrun public blindBackrun;
 
    address uniswapV2RouterAddress = address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    address sushiswapRouterAddress = address(0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F);
    IUniswapV2Router public uniswapv2Router = IUniswapV2Router(uniswapV2RouterAddress);
    IUniswapV2Router public sushiswapRouter = IUniswapV2Router(sushiswapRouterAddress);

    address uniswapv2FactoryAddress = address(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f);
    address sushiswapFactoryAddress = address(0xC0AEe478e3658e2610c5F7A4A2E1777cE9e4f2Ac);
    IUniswapFactory public uniswapFactory = IUniswapFactory(uniswapv2FactoryAddress);
    IUniswapFactory public sushiswapFactory = IUniswapFactory(sushiswapFactoryAddress);
    
    address wethTokenAddress = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    address usdcTokenAddress = address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    address usdtTokenAddress = address(0xdAC17F958D2ee523a2206206994597C13D831ec7);

    IWETH WETH = IWETH(wethTokenAddress);
  
    function setUp() public {
        blindBackrun = new BlindBackrun(wethTokenAddress); // WETH address on 
        vm.deal(address(msg.sender), 1e25);
        WETH.deposit{value: 1e23}();
        WETH.transfer(address(blindBackrun), 1e23);
    }

    function test_arbitrageCalculation() public view {
        IPairReserves.PairReserves memory firstPairData = getFakePairData(true);
        IPairReserves.PairReserves memory secondPairData = getFakePairData(false);
        uint amountIn2 = blindBackrun.getAmountIn(firstPairData, secondPairData);
        console.log("amountIn:", amountIn2);
    }

    function test_arbitrageCalculationFlipped() public view {
        IPairReserves.PairReserves memory firstPairData = getFlippedFakePairData(true);
        IPairReserves.PairReserves memory secondPairData = getFlippedFakePairData(false);
        uint amountIn2 = blindBackrun.getAmountIn(firstPairData, secondPairData);
        console.log("amountIn:", amountIn2);
    }

    function test_createPairAndArb() public {
        ERC20 newToken = new TokenForTesting(18);

        newToken.approve(
            address(uniswapv2Router),
            1e18
        );

        newToken.approve(
            address(sushiswapRouter),
            10e18
        );

        // add liquidity to the new token
        uniswapv2Router.addLiquidityETH{value: 1e18}(
            address(newToken),
            1e18,
            1e18,
            1e18,
            address(this),
            block.timestamp + 15
        );

        sushiswapRouter.addLiquidityETH{value: 1e18}(
            address(newToken),
            10e18,
            10e18,
            1e18,
            address(this),
            block.timestamp + 15
        );

        address firstPair = uniswapFactory.getPair(address(newToken), wethTokenAddress);
        address secondPair = sushiswapFactory.getPair(address(newToken), wethTokenAddress);

        blindBackrun.executeArbitrage(secondPair, firstPair, 80);
    }

    function test_createPairAndArbSmallDecimals() public {
        ERC20 newToken = new TokenForTesting(4);

        newToken.approve(
            address(uniswapv2Router),
            1e4
        );

        newToken.approve(
            address(sushiswapRouter),
            10e4
        );

        // add liquidity to the new token
        uniswapv2Router.addLiquidityETH{value: 1e18}(
            address(newToken),
            1e4,
            1e4,
            1e18,
            address(this),
            block.timestamp + 15
        );

        sushiswapRouter.addLiquidityETH{value: 1e18}(
            address(newToken),
            10e4,
            10e4,
            1e18,
            address(this),
            block.timestamp + 15
        );

        address firstPair = uniswapFactory.getPair(address(newToken), wethTokenAddress);
        address secondPair = sushiswapFactory.getPair(address(newToken), wethTokenAddress);

        blindBackrun.executeArbitrage(secondPair, firstPair, 80);
    }

    function test_createPairAndArbLargeDecimals() public {
        ERC20 newToken = new TokenForTesting(20);

        newToken.approve(
            address(uniswapv2Router),
            1e20
        );

        newToken.approve(
            address(sushiswapRouter),
            10e20
        );

        // add liquidity to the new token
        uniswapv2Router.addLiquidityETH{value: 1e18}(
            address(newToken),
            1e20,
            1e20,
            1e18,
            address(this),
            block.timestamp + 15
        );

        sushiswapRouter.addLiquidityETH{value: 1e18}(
            address(newToken),
            10e20,
            10e20,
            1e18,
            address(this),
            block.timestamp + 15
        );

        address firstPair = uniswapFactory.getPair(address(newToken), wethTokenAddress);
        address secondPair = sushiswapFactory.getPair(address(newToken), wethTokenAddress);

        blindBackrun.executeArbitrage(secondPair, firstPair, 80);
    }

    function test_mainnetArbLarge() public {
        address[] memory path = new address[](2);
        path[0] = wethTokenAddress;
        path[1] = usdcTokenAddress; //usdc 

        // make a swap to imbalance the pools
        uniswapv2Router.swapExactETHForTokens{value: 1e20}(
            0, 
            path, 
            address(this), 
            block.timestamp + 15
        );
       
        address firstPair = uniswapFactory.getPair(usdcTokenAddress, wethTokenAddress);
        address secondPair = sushiswapFactory.getPair(usdcTokenAddress, wethTokenAddress);

        blindBackrun.executeArbitrage(secondPair, firstPair, 80);
    }

    function test_mainnetArbMedium() public {
        address[] memory path = new address[](2);
        path[0] = wethTokenAddress;
        path[1] = usdtTokenAddress; //usdc 

        // make a swap to imbalance the pools
        uniswapv2Router.swapExactETHForTokens{value: 1e20}(
            0, 
            path, 
            address(this), 
            block.timestamp + 15
        );
       
        address firstPair = uniswapFactory.getPair(usdtTokenAddress, wethTokenAddress);
        address secondPair = sushiswapFactory.getPair(usdtTokenAddress, wethTokenAddress);

        // blindBackrun.executeArbitrage(firstPair, secondPair, 80);
        blindBackrun.executeArbitrage(secondPair, firstPair, 80);
    }

    function test_RevertWhen_CallerIsNotOwner() public {
        vm.expectRevert('Ownable: caller is not the owner');
        vm.prank(address(0));
        blindBackrun.withdrawWETHToOwner();
    }

    function getFlippedFakePairData(bool first) internal pure returns (IPairReserves.PairReserves memory){
        uint256 reserve0; 
        uint256 reserve1;
        if (first){
            reserve1 = 17221979511711;
            reserve0 = 9022829950419911882261;
        } else {
            reserve1 = 24221870080988;
            reserve0 = 29260889455340067009671;
        }

        uint256 price;

        bool isWETHZero = true;

        price = reserve0.mul(1e18).div(reserve1);

        return IPairReserves.PairReserves(reserve0, reserve1, price, isWETHZero);
    }


    function getFakePairData(bool first) internal pure returns (IPairReserves.PairReserves memory){
        uint256 reserve0; 
        uint256 reserve1;
        if (first){
            reserve0 = 17221979511711000000000;
            reserve1 = 9022829950419911882261;
        } else {
            reserve0 = 24221870080988000000000;
            reserve1 = 29260889455340067009671;
        }

        uint256 price;

        bool isWETHZero = false;

        price = reserve0.mul(1e18).div(reserve1);

        return IPairReserves.PairReserves(reserve0, reserve1, price, isWETHZero);
    }
}
