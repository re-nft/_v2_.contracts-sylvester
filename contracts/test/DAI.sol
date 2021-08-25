// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

import "OpenZeppelin/openzeppelin-contracts@4.3.0/contracts/token/ERC20/ERC20.sol";

contract DAI is ERC20 {
    constructor() ERC20("DAI", "DAI") {
        _mint(msg.sender, 1000 ether);
    }

    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    function faucet() public {
        _mint(msg.sender, 1000 * (10**decimals()));
    }
}