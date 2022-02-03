// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract E721 is Ownable, ERC721Enumerable {
    uint256 private counter = 0;

    constructor() ERC721("E721", "E721") {}

    function faucet() public {
        counter++;
        _mint(msg.sender, counter);
    }
}
