pragma solidity ^0.8.0;

import "openzeppelin/token/ERC20/IERC20.sol";
import "openzeppelin/access/Ownable.sol";
import "openzeppelin/utils/math/SafeMath.sol";
import "forge-std/console.sol";
import "./BlindBackrunDebug.sol";

interface IVault {
    function flashLoan(
        IFlashLoanRecipient recipient,
        IERC20[] memory tokens,
        uint256[] memory amounts,
        bytes memory userData
    ) external;
}

interface IFlashLoanRecipient {
    /**
     * @dev When `flashLoan` is called on the Vault, it invokes the `receiveFlashLoan` hook on the recipient.
     *
     * At the time of the call, the Vault will have transferred `amounts` for `tokens` to the recipient. Before this
     * call returns, the recipient must have transferred `amounts` plus `feeAmounts` for each token back to the
     * Vault, or else the entire flash loan will revert.
     *
     * `userData` is the same value passed in the `IVault.flashLoan` call.
     */
    function receiveFlashLoan(
        IERC20[] memory tokens,
        uint256[] memory amounts,
        uint256[] memory feeAmounts,
        bytes memory userData
    ) external;
}

contract BlindBackrunFL is BlindBackrun, IFlashLoanRecipient {
    IVault private constant vault = IVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);

    // constructor(uint8 _decimals) ERC20("tokenForTesting", "TFT") {
    //     _mint(msg.sender, 1e22);
    //     TokenDecimals = _decimals;
    // }
    constructor(address _wethAddress) BlindBackrun(_wethAddress) {}

    function makeFlashLoan(
        IERC20[] memory tokens,
        uint256[] memory amounts,
        bytes memory userData
    ) external onlyOwner {
        vault.flashLoan(this, tokens, amounts, userData);
    }

    function receiveFlashLoan(
        IERC20[] memory tokens,
        uint256[] memory amounts,
        uint256[] memory feeAmounts,
        bytes memory userData
    ) external {
        require(msg.sender == address(vault), "FlashLoanRecipient: caller is not the vault");
        console.log("receiveFlashLoan");

        (
            address firstPairAddress,
            address secondPairAddress,
            uint256 percentageToPayToCoinbase
        ) 
            = abi.decode(
                userData, 
            (
                address,
                address,
                uint256
            )
        );
        executeArbitrage(secondPairAddress, firstPairAddress, percentageToPayToCoinbase);
        IWETH(WETH_ADDRESS).transfer(address(vault), amounts[0]+(feeAmounts[0]));
    }

}
