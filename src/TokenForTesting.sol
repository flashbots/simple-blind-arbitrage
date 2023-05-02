pragma solidity ^0.8.15;
import "openzeppelin/token/ERC20/ERC20.sol";

contract TokenForTesting is ERC20 {
    constructor() ERC20("tokenForTesting", "TFT") {
        _mint(msg.sender, 1e22);
    }
}