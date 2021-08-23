//SPDX-Identifier-License: MIT
pragma solidity =0.8.7;

interface IRegistry {
    enum NFTStandard {
        E721,
        E1155
    }

    // creates the lending structs
    function lend(
        NFTStandard[] nftStandard,
        uint256[] tokenIDs,
        address[] nftAddress
    ) external;
}
