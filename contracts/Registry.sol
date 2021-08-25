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
    address public immutable admin;
    address payable public beneficiary;

    bool public paused = false;

    IResolver public immutable resolverAddress;

    struct CallData {
        uint256 left;
        uint256 right;
        IRegistry.NFTStandard[] nftStandard;
        address[] nftAddress;
        uint256[] tokenID;
        uint8[] maxRentDuration;
        uint32[] dailyRentPrice;
        uint16[] lendAmount;
        IResolver.PaymentToken[] paymentToken;
        uint16[] rentAmount;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "ReNFT::not admin");
        _;
    }

    modifier notPaused() {
        require(!paused, "ReNFT::paused");
        _;
    }

    constructor(IResolver _resolverAddress) {
        resolverAddress = _resolverAddress;
        admin = msg.sender;
    }

    function bundleCall(function(CallData memory) handler, CallData memory cd)
        private
    {
        require(cd.nftAddress.length > 0, "ReNFT::no nfts");
        while (cd.right != cd.nftAddress.length) {
            if (
                (cd.nftAddress[cd.left] == cd.nftAddress[cd.right]) &&
                (cd.nftStandard[cd.right] == IRegistry.NFTStandard.E1155)
            ) {
                cd.right++;
            } else {
                handler(cd);
                cd.left = cd.right;
                cd.right++;
            }
        }
        handler(cd);
    }

    function lend(
        IRegistry.NFTStandard[] memory nftStandard,
        address[] memory nftAddress,
        uint256[] memory tokenID,
        uint8[] memory maxRentDuration,
        uint32[] memory dailyRentPrice,
        uint16[] memory lendAmount,
        IResolver.PaymentToken[] memory paymentToken
    ) external override {
        // batch them, like in og reNFT
        // ensure that the created lendings do not exist in the system
        bundleCall(
            handleLend,
            CallData({
                left: 0,
                right: 1,
                nftStandard: nftStandard,
                nftAddress: nftAddress,
                tokenID: tokenID,
                maxRentDuration: maxRentDuration,
                dailyRentPrice: dailyRentPrice,
                lendAmount: lendAmount,
                paymentToken: paymentToken,
                rentAmount: new uint16[](0)
            })
        );
    }

    function handleLend(CallData memory cd) private {
        for (uint256 i = cd.left; i < cd.right; i++) {
            IRegistry.Lending memory lending = IRegistry.Lending({
                nftStandard: cd.nftStandard[i],
                lenderAddress: payable(address(msg.sender)),
                maxRentDuration: cd.maxRentDuration[i],
                dailyRentPrice: cd.dailyRentPrice[i],
                lendAmount: cd.lendAmount[i],
                availableAmount: cd.lendAmount[i],
                paymentToken: cd.paymentToken[i]
            });
            add(lending, lendingID);
            lendingID++;
        }
        // finally, transfer the NFTs into this contract
    }

    // function rent(
    //     uint256[] lendingID
    // ) external payable override {};

    // function stopLend(uint256[] lendingID) external override {};

    // function stopRent(
    //     uint256[] rentingID
    // ) external override {};

    // function getLending(address lenderAddress) external view override {};

    // function getRenting(address renterAddress) external view override {};

    // function getRenter(
    //     address nftAddress,
    //     uint256 tokenID,
    //     uint256 lendingID
    // ) external view override {};

    //      .-.     .-.     .-.     .-.     .-.     .-.     .-.     .-.     .-.     .-.
    // `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'

    function safeTransfer(
        CallData memory cd,
        address from,
        address to,
        uint256[] memory tokenIds,
        uint256[] memory amounts
    ) private {
        if (cd.nftStandard[cd.left]) {
            IERC721(cd.nfts[cd.left]).transferFrom(
                from,
                to,
                cd.tokenIds[cd.left]
            );
        } else {
            IERC1155(cd.nfts[cd.left]).safeBatchTransferFrom(
                from,
                to,
                tokenIds,
                amounts,
                ""
            );
        }
    }

    function sliceArr(
        uint256[] memory _arr,
        uint256 _fromIx,
        uint256 _toIx,
        uint256 _arrOffset
    ) private pure returns (uint256[] memory r) {
        r = new uint256[](_toIx - _fromIx);
        for (uint256 i = _fromIx; i < _toIx; i++) {
            r[i - _fromIx] = _arr[i - _arrOffset];
        }
    }

    //      .-.     .-.     .-.     .-.     .-.     .-.     .-.     .-.     .-.     .-.
    // `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'

    function setRentFee(uint256 _rentFee) external onlyAdmin {
        require(_rentFee < 10000, "ReNFT::fee exceeds 100pct");
        rentFee = _rentFee;
    }

    function setBeneficiary(address payable newBeneficiary) external onlyAdmin {
        beneficiary = newBeneficiary;
    }

    function setPaused(bool _paused) external onlyAdmin {
        paused = _paused;
    }
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
