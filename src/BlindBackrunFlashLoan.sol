pragma solidity ^0.8.19;

import "openzeppelin/token/ERC20/IERC20.sol";
import "forge-std/console.sol";
import "./BlindBackrunLogic.sol";
import "./IWETH.sol";

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
     * call returns, the recipient must have transferred `amounts` back or else the entire flash loan will revert. If
     * Balancer implements a fee, this contract will need to be redeployed to include that fee when paying back loan
     *
     * While this contract is `Ownable`, the owner can only help recover locked assets. Many users can operate on this
     * contract as it does not rely on owning WETH or accumulating any balances.
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

contract BlindBackrunFlashLoan is BlindBackrunLogic, IFlashLoanRecipient {
    IVault private constant vault =
        IVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);

    constructor(IWETH _wethAddress) BlindBackrunLogic(_wethAddress) {}

    // This function is just a convenience function, you can accomplish the same goal by calling the vault.flashLoan
    // directly as the top-level destination of your ethereum transaction
    function makeFlashLoan(
        IERC20[] memory tokens,
        uint256[] memory amounts,
        bytes memory userData
    ) external {
        vault.flashLoan(this, tokens, amounts, userData);
    }

    function receiveFlashLoan(
        IERC20[] memory tokens,
        uint256[] memory amounts,
        uint256[] memory feeAmounts,
        bytes memory userData
    ) external {
        tokens;feeAmounts; // suppress warnings about unused variables by referencing them
        require(
            msg.sender == address(vault),
            "FlashLoanRecipient: caller is not the vault"
        );
        console.log("receiveFlashLoan");

        (
            address firstPairAddress,
            address secondPairAddress,
            uint256 percentageToPayToCoinbase
        ) = abi.decode(userData, (address, address, uint256));

        _executeArbitrage(
            secondPairAddress,
            firstPairAddress,
            percentageToPayToCoinbase
        );

        // This contract will not work if balancer implements a flash loan fee as we are not adding "feeAmounts[0]" below
        WETH.transfer(
            address(vault),
            amounts[0]
        );
    }
}
