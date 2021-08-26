// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

import "OpenZeppelin/openzeppelin-contracts@4.3.0/contracts/token/ERC20/ERC20.sol";
import "OpenZeppelin/openzeppelin-contracts@4.3.0/contracts/token/ERC20/IERC20.sol";
import "OpenZeppelin/openzeppelin-contracts@4.3.0/contracts/token/ERC721/IERC721.sol";
import "OpenZeppelin/openzeppelin-contracts@4.3.0/contracts/token/ERC721/utils/ERC721Holder.sol";
import "OpenZeppelin/openzeppelin-contracts@4.3.0/contracts/token/ERC1155/IERC1155.sol";
import "OpenZeppelin/openzeppelin-contracts@4.3.0/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "OpenZeppelin/openzeppelin-contracts@4.3.0/contracts/token/ERC1155/utils/ERC1155Receiver.sol";

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

contract Registry is
    IRegistry,
    EnumerableSet,
    ERC721Holder,
    ERC1155Receiver,
    ERC1155Holder
{
    using SafeERC20 for ERC20;

    IResolver private resolver;
    address private admin;
    address payable private beneficiary;
    uint256 private lendingId = 1;
    bool public paused = false;

    uint256 public rentFee = 0;

    uint256 private constant SECONDS_IN_DAY = 86400;

    struct Lending {
        address payable lenderAddress;
        uint8 maxRentDuration;
        bytes4 dailyRentPrice;
        uint8 lentAmount;
        uint8 availableAmount;
        IResolver.PaymentToken paymentToken;
    }

    struct Renting {
        address payable renterAddress;
        uint8 rentDuration;
        uint8 rentAmount;
        uint32 rentedAt;
    }

    mapping(bytes32 => Lending) private lendings;
    mapping(bytes32 => Renting) private rentings;

    struct CallData {
        uint256 left;
        uint256 right;
        IRegistry.NFTStandard[] nftStandard;
        address[] nfts;
        uint256[] tokenIds;
        uint256[] lentAmounts;
        uint8[] maxRentDurations;
        bytes4[] dailyRentPrices;
        bytes4[] nftPrices;
        uint256[] lendingIds;
        uint8[] rentDurations;
        IResolver.PaymentToken[] paymentTokens;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "ReNFT::not admin");
        _;
    }

    modifier notPaused() {
        require(!paused, "ReNFT::paused");
        _;
    }

    constructor(
        address resolver,
        address payable beneficiary,
        address admin
    ) {
        ensureIsNotZeroAddr(resolver);
        ensureIsNotZeroAddr(beneficiary);
        ensureIsNotZeroAddr(admin);
        resolver = IResolver(resolver);
        beneficiary = beneficiary;
        admin = admin;
    }

    function bundleCall(function(CallData memory) handler, CallData memory cd)
        private
    {
        require(cd.nfts.length > 0, "ReNFT::no nfts");
        while (cd.right != cd.nfts.length) {
            if (
                (cd.nfts[cd.left] == cd.nfts[cd.right]) &&
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
        address[] memory nfts,
        uint256[] memory tokenIds,
        uint256[] memory lendAmounts,
        uint8[] memory maxRentDurations,
        bytes4[] memory dailyRentPrices,
        bytes4[] memory nftPrices,
        IResolver.PaymentToken[] memory paymentTokens
    ) external override notPaused {
        bundleCall(
            handleLend,
            createLendCallData(
                nfts,
                tokenIds,
                lendAmounts,
                maxRentDurations,
                dailyRentPrices,
                nftPrices,
                paymentTokens
            )
        );
    }

    function rent(
        address[] memory nfts,
        uint256[] memory tokenIds,
        uint256[] memory lendingIds,
        uint8[] memory rentDurations
    ) external override notPaused {
        bundleCall(
            handleRent,
            createRentCallData(nfts, tokenIds, lendingIds, rentDurations)
        );
    }

    function stopRent(
        address[] memory nfts,
        uint256[] memory tokenIds,
        uint256[] memory lendingIds
    ) external override notPaused {
        bundleCall(
            handleStopRent,
            createActionCallData(nfts, tokenIds, lendingIds)
        );
    }

    function stopLend(
        address[] memory nfts,
        uint256[] memory tokenIds,
        uint256[] memory lendingIds
    ) external override notPaused {
        bundleCall(
            handleStopLends,
            createActionCallData(nfts, tokenIds, lendingIds)
        );
    }

    //      .-.     .-.     .-.     .-.     .-.     .-.     .-.     .-.     .-.     .-.
    // `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'

    function handleLend(CallData memory cd) private {
        for (uint256 i = cd.left; i < cd.right; i++) {
            ensureIsLendable(cd, i);

            LendingRenting storage item = lendingRenting[
                keccak256(
                    abi.encodePacked(
                        cd.nfts[cd.left],
                        cd.tokenIds[i],
                        lendingId
                    )
                )
            ];

            ensureIsNull(item.lending);

            bool nftIs721 = is721(cd.nfts[i]);
            item.lending = Lending({
                lenderAddress: payable(msg.sender),
                lentAmount: nftIs721 ? 1 : uint8(cd.lentAmounts[i]),
                maxRentDuration: cd.maxRentDurations[i],
                dailyRentPrice: cd.dailyRentPrices[i],
                nftPrice: cd.nftPrices[i],
                paymentToken: cd.paymentTokens[i]
            });

            emit Lent(
                cd.nfts[cd.left],
                cd.tokenIds[i],
                nftIs721 ? 1 : uint8(cd.lentAmounts[i]),
                lendingId,
                msg.sender,
                cd.maxRentDurations[i],
                cd.dailyRentPrices[i],
                cd.nftPrices[i],
                nftIs721,
                cd.paymentTokens[i]
            );

            lendingId++;
        }

        safeTransfer(
            cd,
            msg.sender,
            address(this),
            sliceArr(cd.tokenIds, cd.left, cd.right, 0),
            sliceArr(cd.lentAmounts, cd.left, cd.right, 0)
        );
    }

    function handleRent(CallData memory cd) private {
        uint256[] memory lentAmounts = new uint256[](cd.right - cd.left);

        for (uint256 i = cd.left; i < cd.right; i++) {
            LendingRenting storage item = lendingRenting[
                keccak256(
                    abi.encodePacked(
                        cd.nfts[cd.left],
                        cd.tokenIds[i],
                        cd.lendingIds[i]
                    )
                )
            ];

            ensureIsNotNull(item.lending);
            ensureIsNull(item.renting);
            ensureIsRentable(item.lending, cd, i, msg.sender);

            uint8 paymentTokenIx = uint8(item.lending.paymentToken);
            ensureTokenNotSentinel(paymentTokenIx);
            address paymentToken = resolver.getPaymentToken(paymentTokenIx);
            uint256 decimals = ERC20(paymentToken).decimals();

            {
                uint256 scale = 10**decimals;
                uint256 rentPrice = cd.rentDurations[i] *
                    unpackPrice(item.lending.dailyRentPrice, scale);
                uint256 nftPrice = item.lending.lentAmount *
                    unpackPrice(item.lending.nftPrice, scale);

                require(rentPrice > 0, "ReNFT::rent price is zero");
                require(nftPrice > 0, "ReNFT::nft price is zero");

                ERC20(paymentToken).safeTransferFrom(
                    msg.sender,
                    address(this),
                    rentPrice + nftPrice
                );
            }

            lentAmounts[i - cd.left] = item.lending.lentAmount;

            item.renting.renterAddress = payable(msg.sender);
            item.renting.rentDuration = cd.rentDurations[i];
            item.renting.rentedAt = uint32(block.timestamp);

            emit Rented(
                cd.lendingIds[i],
                msg.sender,
                cd.rentDurations[i],
                item.renting.rentedAt
            );
        }
    }

    function handleStopRent(CallData memory cd) private {
        uint256[] memory lentAmounts = new uint256[](cd.right - cd.left);
        for (uint256 i = cd.left; i < cd.right; i++) {
            bytes32 identifier = keccak256(
                abi.encodePacked(
                    cd.nfts[cd.left],
                    cd.tokenIds[i],
                    cd.lendingIds[i]
                )
            );
            Renting storage item = rentings[identifier];
            ensureIsNotNull(item.lending);
            ensureIsReturnable(item.renting, msg.sender, block.timestamp);
            uint256 secondsSinceRentStart = block.timestamp -
                item.renting.rentedAt;
            distributePayments(item, secondsSinceRentStart);
            lentAmounts[i - cd.left] = item.lending.lentAmount;
            emit Returned(cd.lendingIds[i], uint32(block.timestamp));
            delete item.renting;

            Lending storage item = lendings[identifier];
            // todo: add to the available amount the amount that was stopped here.
            // todo: the amount returned here, is in the renting struct
        }
    }

    function handleStopLend(CallData memory cd) private {
        uint256[] memory lentAmounts = new uint256[](cd.right - cd.left);
        for (uint256 i = cd.left; i < cd.right; i++) {
            Lending storage item = lendingRenting[
                keccak256(
                    abi.encodePacked(
                        cd.nfts[cd.left],
                        cd.tokenIds[i],
                        cd.lendingIds[i]
                    )
                )
            ];
            require(
                item.lentAmount == item.availableAmount,
                "ReNFT::actively rented"
            );
            ensureIsNotNull(item.lending);
            ensureIsNull(item.renting);
            ensureIsStoppable(item.lending, msg.sender);
            lentAmounts[i - cd.left] = item.lending.lentAmount;
            emit LendingStopped(cd.lendingIds[i], uint32(block.timestamp));
            delete item.lending;
        }
        safeTransfer(
            cd,
            address(this),
            msg.sender,
            sliceArr(cd.tokenIds, cd.left, cd.right, 0),
            sliceArr(lentAmounts, cd.left, cd.right, cd.left)
        );
    }

    //      .-.     .-.     .-.     .-.     .-.     .-.     .-.     .-.     .-.     .-.
    // `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'

    function takeFee(uint256 rent, IResolver.PaymentToken paymentToken)
        private
        returns (uint256 fee)
    {
        fee = rent * rentFee;
        fee /= 10000;
        uint8 paymentTokenIx = uint8(paymentToken);
        ensureTokenNotSentinel(paymentTokenIx);
        ERC20 paymentToken = ERC20(resolver.getPaymentToken(paymentTokenIx));
        paymentToken.safeTransfer(beneficiary, fee);
    }

    function distributePayments(
        IRegistry.Lending memory lending,
        IRegistry.Renting memory renting,
        uint256 secondsSinceRentStart
    ) private {
        uint8 paymentTokenIx = uint8(lending.paymentToken);
        ensureTokenNotSentinel(paymentTokenIx);
        address paymentToken = resolver.getPaymentToken(paymentTokenIx);
        uint256 decimals = ERC20(paymentToken).decimals();

        uint256 scale = 10**decimals;
        uint256 rentPrice = unpackPrice(lending.dailyRentPrice, scale);
        uint256 totalRenterPmtWoCollateral = rentPrice * renting.rentDuration;
        uint256 sendLenderAmt = (secondsSinceRentStart * rentPrice) /
            SECONDS_IN_DAY;
        require(
            totalRenterPmtWoCollateral > 0,
            "ReNFT::total payment wo collateral is zero"
        );
        require(sendLenderAmt > 0, "ReNFT::lender payment is zero");
        uint256 sendRenterAmt = totalRenterPmtWoCollateral - sendLenderAmt;

        uint256 takenFee = takeFee(sendLenderAmt, lending.paymentToken);

        sendLenderAmt -= takenFee;

        ERC20(paymentToken).safeTransfer(lending.lenderAddress, sendLenderAmt);
        ERC20(paymentToken).safeTransfer(renting.renterAddress, sendRenterAmt);
    }

    function safeTransfer(
        CallData memory cd,
        address from,
        address to,
        uint256[] memory tokenIds,
        uint256[] memory lentAmounts
    ) private {
        if (cd.nftStandard[cd.left] == IRegistry.NFTStandard.E721) {
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
                lentAmounts,
                ""
            );
        }
    }

    //      .-.     .-.     .-.     .-.     .-.     .-.     .-.     .-.     .-.     .-.
    // `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'

    function createLendCallData(
        address[] memory nfts,
        uint256[] memory tokenIds,
        uint256[] memory lendAmounts,
        uint8[] memory maxRentDurations,
        bytes4[] memory dailyRentPrices,
        bytes4[] memory nftPrices,
        IResolver.PaymentToken[] memory paymentTokens
    ) private pure returns (CallData memory cd) {
        cd = CallData({
            left: 0,
            right: 1,
            nfts: nfts,
            tokenIds: tokenIds,
            lentAmounts: lendAmounts,
            lendingIds: new uint256[](0),
            rentDurations: new uint8[](0),
            maxRentDurations: maxRentDurations,
            dailyRentPrices: dailyRentPrices,
            nftPrices: nftPrices,
            paymentTokens: paymentTokens
        });
    }

    function createRentCallData(
        address[] memory nfts,
        uint256[] memory tokenIds,
        uint256[] memory lendingIds,
        uint8[] memory rentDurations
    ) private pure returns (CallData memory cd) {
        cd = CallData({
            left: 0,
            right: 1,
            nfts: nfts,
            tokenIds: tokenIds,
            lentAmounts: new uint256[](0),
            lendingIds: lendingIds,
            rentDurations: rentDurations,
            maxRentDurations: new uint8[](0),
            dailyRentPrices: new bytes4[](0),
            nftPrices: new bytes4[](0),
            paymentTokens: new IResolver.PaymentToken[](0)
        });
    }

    function createActionCallData(
        address[] memory nfts,
        uint256[] memory tokenIds,
        uint256[] memory lendingIds
    ) private pure returns (CallData memory cd) {
        cd = CallData({
            left: 0,
            right: 1,
            nfts: nfts,
            tokenIds: tokenIds,
            lentAmounts: new uint256[](0),
            lendingIds: lendingIds,
            rentDurations: new uint8[](0),
            maxRentDurations: new uint8[](0),
            dailyRentPrices: new bytes4[](0),
            nftPrices: new bytes4[](0),
            paymentTokens: new IResolver.PaymentToken[](0)
        });
    }

    function unpackPrice(bytes4 price, uint256 scale)
        private
        pure
        returns (uint256)
    {
        ensureIsUnpackablePrice(price, scale);

        uint16 whole = uint16(bytes2(price));
        uint16 decimal = uint16(bytes2(price << 16));
        uint256 decimalScale = scale / 10000;

        if (whole > 9999) {
            whole = 9999;
        }
        if (decimal > 9999) {
            decimal = 9999;
        }

        uint256 w = whole * scale;
        uint256 d = decimal * decimalScale;
        uint256 price = w + d;

        return price;
    }

    function sliceArr(
        uint256[] memory arr,
        uint256 fromIx,
        uint256 toIx,
        uint256 arrOffset
    ) private pure returns (uint256[] memory r) {
        r = new uint256[](toIx - fromIx);
        for (uint256 i = fromIx; i < toIx; i++) {
            r[i - fromIx] = arr[i - arrOffset];
        }
    }

    //      .-.     .-.     .-.     .-.     .-.     .-.     .-.     .-.     .-.     .-.
    // `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'

    function ensureIsNotZeroAddr(address addr) private pure {
        require(addr != address(0), "ReNFT::zero address");
    }

    function ensureIsZeroAddr(address addr) private pure {
        require(addr == address(0), "ReNFT::not a zero address");
    }

    function ensureIsNull(Lending memory lending) private pure {
        ensureIsZeroAddr(lending.lenderAddress);
        require(lending.maxRentDuration == 0, "ReNFT::duration not zero");
        require(lending.dailyRentPrice == 0, "ReNFT::rent price not zero");
        require(lending.nftPrice == 0, "ReNFT::nft price not zero");
    }

    function ensureIsNotNull(Lending memory lending) private pure {
        ensureIsNotZeroAddr(lending.lenderAddress);
        require(lending.maxRentDuration != 0, "ReNFT::duration zero");
        require(lending.dailyRentPrice != 0, "ReNFT::rent price is zero");
        require(lending.nftPrice != 0, "ReNFT::nft price is zero");
    }

    function ensureIsNull(Renting memory renting) private pure {
        ensureIsZeroAddr(renting.renterAddress);
        require(renting.rentDuration == 0, "ReNFT::duration not zero");
        require(renting.rentedAt == 0, "ReNFT::rented at not zero");
    }

    function ensureIsNotNull(Renting memory renting) private pure {
        ensureIsNotZeroAddr(renting.renterAddress);
        require(renting.rentDuration != 0, "ReNFT::duration is zero");
        require(renting.rentedAt != 0, "ReNFT::rented at is zero");
    }

    function ensureIsLendable(CallData memory cd, uint256 i) private pure {
        require(cd.lentAmounts[i] > 0, "ReNFT::lend amount is zero");
        require(cd.lentAmounts[i] <= type(uint8).max, "ReNFT::not uint8");
        require(cd.maxRentDurations[i] > 0, "ReNFT::duration is zero");
        require(cd.maxRentDurations[i] <= type(uint8).max, "ReNFT::not uint8");
        require(uint32(cd.dailyRentPrices[i]) > 0, "ReNFT::rent price is zero");
        require(uint32(cd.nftPrices[i]) > 0, "ReNFT::nft price is zero");
    }

    function ensureIsRentable(
        Lending memory lending,
        CallData memory cd,
        uint256 i,
        address msgSender
    ) private pure {
        require(msgSender != lending.lenderAddress, "ReNFT::cant rent own nft");
        require(cd.rentDurations[i] <= type(uint8).max, "ReNFT::not uint8");
        require(cd.rentDurations[i] > 0, "ReNFT::duration is zero");
        require(
            cd.rentDurations[i] <= lending.maxRentDuration,
            "ReNFT::rent duration exceeds allowed max"
        );
    }

    function ensureIsReturnable(
        Renting memory renting,
        address msgSender,
        uint256 blockTimestamp
    ) private pure {
        require(renting.renterAddress == msgSender, "ReNFT::not renter");
        require(
            !isPastReturnDate(renting, blockTimestamp),
            "ReNFT::past return date"
        );
    }

    function ensureIsStoppable(Lending memory lending, address msgSender)
        private
        pure
    {
        require(lending.lenderAddress == msgSender, "ReNFT::not lender");
    }

    function ensureIsUnpackablePrice(bytes4 price, uint256 scale) private pure {
        require(uint32(price) > 0, "ReNFT::invalid price");
        require(scale >= 10000, "ReNFT::invalid scale");
    }

    function ensureTokenNotSentinel(uint8 paymentIx) private pure {
        require(paymentIx > 0, "ReNFT::token is sentinel");
    }

    function isPastReturnDate(Renting memory renting, uint256 nowTime)
        private
        pure
        returns (bool)
    {
        require(nowTime > renting.rentedAt, "ReNFT::now before rented");
        return
            nowTime - renting.rentedAt > renting.rentDuration * SECONDS_IN_DAY;
    }

    //      .-.     .-.     .-.     .-.     .-.     .-.     .-.     .-.     .-.     .-.
    // `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'

    function setRentFee(uint256 rentFee) external onlyAdmin {
        require(rentFee < 10000, "ReNFT::fee exceeds 100pct");
        rentFee = rentFee;
    }

    function setBeneficiary(address payable newBeneficiary) external onlyAdmin {
        beneficiary = newBeneficiary;
    }

    function setPaused(bool newPaused) external onlyAdmin {
        paused = newPaused;
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
