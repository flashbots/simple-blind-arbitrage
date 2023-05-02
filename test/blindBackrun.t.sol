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
    BlindBackrun public blindBackrun;
    TokenForTesting public testToken;

    address wethTokenAddress = address(0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6);
    IWETH WETH = IWETH(wethTokenAddress);

    address uniswapV2RouterAddress = address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    address sushiswapRouterAddress = address(0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506);

    address uniswapv2FactoryAddress = address(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f);
    address sushiswapFactoryAddress = address(0xc35DADB65012eC5796536bD9864eD8773aBc74C4);

    IUniswapV2Router public uniswapv2Router = IUniswapV2Router(uniswapV2RouterAddress);
    IUniswapV2Router public sushiswapRouter = IUniswapV2Router(sushiswapRouterAddress);
    
    IUniswapFactory public uniswapFactory = IUniswapFactory(uniswapv2FactoryAddress);
    IUniswapFactory public sushiswapFactory = IUniswapFactory(sushiswapFactoryAddress);
    
    function setUp() public {
        blindBackrun = new BlindBackrun(0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6); // WETH address on goerli
        vm.deal(address(blindBackrun), 1e22);
        WETH.deposit{value: 1e19}();
        WETH.transfer(address(blindBackrun), 1e19);
        testToken = new TokenForTesting();
    }

    function test_newArb() public {
        testToken.approve(address(uniswapv2Router), 1e19);
        testToken.approve(address(sushiswapRouter), 1e18);

        uniswapv2Router.addLiquidityETH{value: 1e18}(address(testToken), 1e19, 1, 1, msg.sender, 1e20);
        sushiswapRouter.addLiquidityETH{value: 1e18}(address(testToken), 1e18, 1, 1, msg.sender, 1e20);

        address firstPair = uniswapFactory.getPair(address(testToken), wethTokenAddress);
        address secondPair = sushiswapFactory.getPair(address(testToken), wethTokenAddress);

        blindBackrun.executeArbitrage(firstPair, secondPair, 80);
    }

    function test_RevertWhen_CallerIsNotOwner() public {
        vm.expectRevert('Ownable: caller is not the owner');
        vm.prank(address(0));
        blindBackrun.withdrawWETHToOwner();
    }
}
