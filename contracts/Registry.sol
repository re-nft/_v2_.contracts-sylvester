//SPDX-Identifier-License: MIT
pragma solidity =0.8.7;

import "..interfaces/IRegistry.sol";
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
contract Registry is IRegistry {
    uint256 private lendingId = 1;

    EnumerableSet lendings;
    EnumerableSet rentings;

    // in bps. so 1000 => 1%
    uitn256 public rentFee = 0;

    function getLendingID(address _nftAddress, uint256 _tokenID, uint256 _lendingID) public view {
      return keccak256(
        abi.encode(
          _nftAddress,
          _tokenID,
          _lendingID
        )
      );
    }

    function bundleCall(IRegistry.NFTStandard[] nftStandard, address[] nftAddress, uint256[] tokenID)
        private pure returns (IRegistry.NFTStandard[] n, address[] a, uint256[] i)
    {
        require(nftAddress.length > 0, "ReNFT::no nfts");

        uint256 left = 0;
        uint256 right = 1;

        while (right != nftAddress.length) {
            if (
                (nftAddress[left] == nftAddress[right]) &&
                (nftStandard[right] == IRegistry.NFTStandard.E1155)
            ) {
                right++;
            } else {
                // todo: add group
                // _handler(_cd);
                _cd.left = _cd.right;
                _cd.right++;
            }
        }
        // todo: add group
        // _handler(_cd);
    }

    function lend(
        // this is purely for transfers
        NFTStandard[] nftStandard,
        // the below is used for hashing
        address[] nftAddress,
        uint256[] tokenID
    ) external override {
      // batch them, like in og reNFT
      // ensure that the created lendings do not exist in the system
    };

    function rent(
        address[] nftAddress,
        uint256[] tokenID,
        uint256[] lendingID
    ) external payable override {};

    function stopRent(
        address[] nftAddress,
        uint256[] tokenID,
        uint256[] lendingID
    ) external override {};

    function getLending(address lenderAddress) external view override {};

    function getRenting(address renterAddress) external view override {};

    function getRenter(
        address nftAddress,
        uint256 tokenID,
        uint256 lendingID
    ) external view override {};
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
