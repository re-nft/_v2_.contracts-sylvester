// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

import "./IResolver.sol";

//              @@@@@@@@@@@@@@@@        ,@@@@@@@@@@@@@@@@
//              @@@,,,,,,,,,,@@@        ,@@&,,,,,,,,,,@@@
//         @@@@@@@@,,,,,,,,,,@@@@@@@@&  ,@@&,,,,,,,,,,@@@@@@@@
//         @@@**********@@@@@@@@@@@@@&  ,@@@@@@@@**********@@@
//         @@@**********@@@@@@@@@@@@@&  ,@@@@@@@@**********@@@@@@@@
//         @@@**********@@@@@@@@@@@@@&       .@@@**********@@@@@@@@
//    @@@@@@@@**********@@@@@@@@@@@@@&       .@@@**********@@@@@@@@
//    @@@**********@@@@@@@@@@@@@&            .@@@@@@@@**********@@@
//    @@@**********@@@@@@@@@@@@@&            .@@@@@@@@**********@@@@@@@@
//    @@@@@@@@**********@@@@@@@@&            .@@@**********@@@@@@@@@@@@@
//    @@@@@@@@//////////@@@@@@@@&            .@@@//////////@@@@@@@@@@@@@
//         @@@//////////@@@@@@@@&            .@@@//////////@@@@@@@@@@@@@
//         @@@//////////@@@@@@@@&       ,@@@@@@@@//////////@@@@@@@@@@@@@
//         @@@%%%%%/////(((((@@@&       ,@@@(((((/////%%%%%@@@@@@@@
//         @@@@@@@@//////////@@@@@@@@&  ,@@@//////////@@@@@@@@@@@@@
//              @@@%%%%%%%%%%@@@@@@@@&  ,@@@%%%%%%%%%%@@@@@@@@@@@@@
//              @@@@@@@@@@@@@@@@@@@@@&  ,@@@@@@@@@@@@@@@@@@@@@@@@@@
//                   @@@@@@@@@@@@@@@@&        @@@@@@@@@@@@@@@@
//                   @@@@@@@@@@@@@@@@&        @@@@@@@@@@@@@@@@

interface IRegistry {
    // todo: use bytes for the price, because different tokens have different scales
    event Lend(
        bool is721,
        address indexed lenderAddress,
        address indexed nftAddress,
        uint256 indexed tokenID,
        uint256 lendingID,
        uint8 maxRentDuration,
        uint32 dailyRentPrice,
        uint16 lendAmount,
        IResolver.PaymentToken paymentToken
    );

    event Rent(
        address indexed renterAddress,
        uint256 indexed lendingID,
        uint256 indexed rentingID,
        uint16 rentAmount,
        uint8 rentDuration,
        uint32 rentedAt
    );

    event StopLend(uint256 indexed lendingID, uint32 stoppedAt);

    event StopRent(uint256 indexed rentingID, uint32 stoppedAt);

    enum NFTStandard {
        E721,
        E1155
    }

    struct CallData {
        uint256 left;
        uint256 right;
        IRegistry.NFTStandard[] nftStandard;
        address[] nftAddress;
        uint256[] tokenID;
        uint256[] lendAmount;
        uint8[] maxRentDuration;
        bytes4[] dailyRentPrice;
        uint256[] lendingID;
        uint8[] rentDuration;
        IResolver.PaymentToken[] paymentToken;
    }

    // 2, 162, 170, 202, 218, 234, 242
    struct Lending {
        NFTStandard nftStandard;
        address payable lenderAddress;
        uint8 maxRentDuration;
        uint32 dailyRentPrice;
        uint16 lendAmount;
        uint16 availableAmount;
        IResolver.PaymentToken paymentToken;
    }

    // 180, 212
    struct Renting {
        address payable renterAddress;
        uint8 rentDuration;
        uint32 rentedAt;
        uint16 rentAmount;
    }

    // creates the lending structs and adds them to the enumerable set
    function lend(
        IRegistry.NFTStandard[] memory nftStandard,
        address[] memory nftAddress,
        uint256[] memory tokenID,
        uint8[] memory maxRentDuration,
        uint32[] memory dailyRentPrice,
        uint16[] memory lendAmount,
        IResolver.PaymentToken[] memory paymentToken
    ) external;

    function stopLend(uint256[] memory lendingID) external;

    // // creates the renting structs and adds them to the enumerable set
    function rent(uint256[] lendingID) external payable;

    function stopRent(uint256[] rentingID) external;
}

//              @@@@@@@@@@@@@@@@        ,@@@@@@@@@@@@@@@@
//              @@@,,,,,,,,,,@@@        ,@@&,,,,,,,,,,@@@
//         @@@@@@@@,,,,,,,,,,@@@@@@@@&  ,@@&,,,,,,,,,,@@@@@@@@
//         @@@**********@@@@@@@@@@@@@&  ,@@@@@@@@**********@@@
//         @@@**********@@@@@@@@@@@@@&  ,@@@@@@@@**********@@@@@@@@
//         @@@**********@@@@@@@@@@@@@&       .@@@**********@@@@@@@@
//    @@@@@@@@**********@@@@@@@@@@@@@&       .@@@**********@@@@@@@@
//    @@@**********@@@@@@@@@@@@@&            .@@@@@@@@**********@@@
//    @@@**********@@@@@@@@@@@@@&            .@@@@@@@@**********@@@@@@@@
//    @@@@@@@@**********@@@@@@@@&            .@@@**********@@@@@@@@@@@@@
//    @@@@@@@@//////////@@@@@@@@&            .@@@//////////@@@@@@@@@@@@@
//         @@@//////////@@@@@@@@&            .@@@//////////@@@@@@@@@@@@@
//         @@@//////////@@@@@@@@&       ,@@@@@@@@//////////@@@@@@@@@@@@@
//         @@@%%%%%/////(((((@@@&       ,@@@(((((/////%%%%%@@@@@@@@
//         @@@@@@@@//////////@@@@@@@@&  ,@@@//////////@@@@@@@@@@@@@
//              @@@%%%%%%%%%%@@@@@@@@&  ,@@@%%%%%%%%%%@@@@@@@@@@@@@
//              @@@@@@@@@@@@@@@@@@@@@&  ,@@@@@@@@@@@@@@@@@@@@@@@@@@
//                   @@@@@@@@@@@@@@@@&        @@@@@@@@@@@@@@@@
//                   @@@@@@@@@@@@@@@@&        @@@@@@@@@@@@@@@@
