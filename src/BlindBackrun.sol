pragma solidity ^0.8.19;

import "openzeppelin/token/ERC20/IERC20.sol";
import "./BlindBackrunLogic.sol";
import "./IWETH.sol";

// This contract is only callable by the deployer/owner, relying on internally held WETH balance
contract BlindBackrun is BlindBackrunLogic {
    constructor(IWETH _wethAddress) BlindBackrunLogic(_wethAddress) {}

    function executeArbitrage(
        address firstPairAddress,
        address secondPairAddress,
        uint percentageToPayToCoinbase
    ) external onlyOwner {
        _executeArbitrage(firstPairAddress, secondPairAddress, percentageToPayToCoinbase);
    }
}
