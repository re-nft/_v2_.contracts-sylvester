// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

import "OpenZeppelin/openzeppelin-contracts@4.3.0/contracts/token/ERC1155/ERC1155.sol";

contract E1155B is ERC1155 {
    uint256 private tokenId;

    constructor() ERC1155("https://api.bccg.digital/api/bccg/{id}.json") {
        _mint(msg.sender, 1, 10, "");
        _mint(msg.sender, 2, 10, "");
        _mint(msg.sender, 3, 10, "");
        _mint(msg.sender, 4, 10, "");
        _mint(msg.sender, 5, 10, "");
        _mint(msg.sender, 6, 10, "");
        _mint(msg.sender, 7, 10, "");
        _mint(msg.sender, 8, 10, "");
        _mint(msg.sender, 9, 10, "");
        _mint(msg.sender, 10, 10, "");
    }

    function award() public returns (uint256) {
        tokenId++;
        _mint(msg.sender, tokenId, 1, "");
        return tokenId;
    }

    function faucet(uint256 _amount) public {
        require(_amount < 11, "too many");
        tokenId++;
        _mint(msg.sender, tokenId, _amount, "");
    }
}
