// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

contract E1155 is ERC1155 {
    uint256 private tokenId;

    constructor() ERC1155("ipfs://QmV9D99vYY1MB1L3RhmGJ35TrUCmF12KRxw3cdXdH4JSze/") {}

    function faucet() public {
        tokenId++;
        _mint(msg.sender, tokenId, 3, "");
    }
}
