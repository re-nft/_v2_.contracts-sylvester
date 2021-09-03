// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

import "OpenZeppelin/openzeppelin-contracts@4.3.0/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "OpenZeppelin/openzeppelin-contracts@4.3.0/contracts/access/Ownable.sol";

contract E721 is Ownable, ERC721Enumerable {
    uint256 private counter = 0;

    constructor() ERC721("E721", "E721") {}

    function faucet() public {
        counter++;
        _mint(msg.sender, counter);
    }
}
