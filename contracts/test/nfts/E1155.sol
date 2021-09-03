// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

import "OpenZeppelin/openzeppelin-contracts@4.3.0/contracts/token/ERC1155/ERC1155.sol";

contract E1155 is ERC1155 {
    uint256 private tokenId;

    constructor() ERC1155("https://api.bccg.digital/api/bccg/{id}.json") {}

    function faucet() public {
        tokenId++;
        _mint(msg.sender, tokenId, 10, "");
    }
}
