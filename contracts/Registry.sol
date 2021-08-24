// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

import "./interfaces/IRegistry.sol";
import "./EnumerableSet.sol";

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

// ideally registry supports both
// (i)  signatures
// (ii) direct lending (for contract interaction)
contract Registry is IRegistry, EnumerableSet {
    uint256 public lendingID = 1;
    uint256 public rentingID = 1;

    // in bps. so 1000 => 1%
    uint256 public rentFee = 0;

    IResolver public immutable resolverAddress;

    constructor(IResolver _resolverAddress) {
        resolverAddress = _resolverAddress;
    }

    // function bundleArgs(
    //     IRegistry.NFTStandard[] memory nftStandard,
    //     address[] memory nftAddress,
    //     uint256[] memory tokenID
    // )
    //     private
    //     pure
    //     returns (
    //         IRegistry.NFTStandard[] calldata n,
    //         address[] calldata a,
    //         uint256[] calldata i
    //     )
    // {
    //     require(nftAddress.length > 0, "ReNFT::no nfts");

    //     uint256 left = 0;
    //     uint256 right = 1;

    //     while (right != nftAddress.length) {
    //         if (
    //             (nftAddress[left] == nftAddress[right]) &&
    //             (nftStandard[right] == IRegistry.NFTStandard.E1155)
    //         ) {
    //             right++;
    //         } else {
    //             n.push(nftStandard[left]);
    //             a.push(nftAddress[left]);
    //             i.push(tokenID[left]);

    //             left = right;
    //             right++;
    //         }
    //     }

    //     n.push(nftStandard[left]);
    //     a.push(nftAddress[left]);
    //     i.push(tokenID[left]);
    // }

    function lend(
        // this is purely for transfers
        IRegistry.NFTStandard[] memory nftStandard,
        // the below is used for hashing
        address[] memory nftAddress,
        uint256[] memory tokenID
    ) external override {
        // batch them, like in og reNFT
        // ensure that the created lendings do not exist in the system
        IRegistry.Lending memory lending = IRegistry.Lending({
            nftStandard: IRegistry.NFTStandard.E721,
            lenderAddress: payable(address(msg.sender)),
            maxRentDuration: 1,
            dailyRentPrice: 10000000,
            lentAmount: 1,
            availableAmount: 1,
            paymentToken: IResolver.PaymentToken.USDC
        });

        add(lending, lendingID);

        lendingID++;
    }

    // function rent(
    //     address[] nftAddress,
    //     uint256[] tokenID,
    //     uint256[] lendingID
    // ) external payable override {};

    // function stopRent(
    //     address[] nftAddress,
    //     uint256[] tokenID,
    //     uint256[] lendingID
    // ) external override {};

    // function getLending(address lenderAddress) external view override {};

    // function getRenting(address renterAddress) external view override {};

    // function getRenter(
    //     address nftAddress,
    //     uint256 tokenID,
    //     uint256 lendingID
    // ) external view override {};
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
