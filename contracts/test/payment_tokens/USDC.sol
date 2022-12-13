// SPDX-License-Identifier: MIT
pragma solidity =0.8.6;

import "OpenZeppelin/openzeppelin-contracts@4.3.0/contracts/token/ERC20/ERC20.sol";

contract USDC is ERC20 {
    constructor() ERC20("USDC", "USDC") {}

    function decimals() public view virtual override returns (uint8) {
        return 6;
    }

    function faucet() public {
        _mint(msg.sender, 1000 * (10 ** decimals()));
    }
}
