// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

import "OpenZeppelin/openzeppelin-contracts@4.3.0/contracts/token/ERC20/ERC20.sol";
import "OpenZeppelin/openzeppelin-contracts@4.3.0/contracts/token/ERC20/IERC20.sol";
import "OpenZeppelin/openzeppelin-contracts@4.3.0/contracts/token/ERC20/utils/SafeERC20.sol";
import "OpenZeppelin/openzeppelin-contracts@4.3.0/contracts/token/ERC721/IERC721.sol";
import "OpenZeppelin/openzeppelin-contracts@4.3.0/contracts/token/ERC721/utils/ERC721Holder.sol";
import "OpenZeppelin/openzeppelin-contracts@4.3.0/contracts/token/ERC1155/IERC1155.sol";
import "OpenZeppelin/openzeppelin-contracts@4.3.0/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "OpenZeppelin/openzeppelin-contracts@4.3.0/contracts/token/ERC1155/utils/ERC1155Receiver.sol";

import "./interfaces/IRegistry.sol";

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

contract Registry is IRegistry, ERC721Holder, ERC1155Receiver, ERC1155Holder {
    using SafeERC20 for ERC20;

    IResolver private resolver;
    address private admin;
    address payable private beneficiary;
    uint256 private lendingId = 1;
    bool public paused = false;
    uint256 public rentFee = 0;
    uint256 private constant SECONDS_IN_DAY = 86400;
    mapping(bytes32 => Lending) private lendings;
    mapping(bytes32 => Renting) private rentings;

    modifier onlyAdmin() {
        require(msg.sender == admin, "ReNFT::not admin");
        _;
    }

    modifier notPaused() {
        require(!paused, "ReNFT::paused");
        _;
    }

    constructor(
        address newResolver,
        address payable newBeneficiary,
        address newAdmin
    ) {
        ensureIsNotZeroAddr(newResolver);
        ensureIsNotZeroAddr(newBeneficiary);
        ensureIsNotZeroAddr(newAdmin);
        resolver = IResolver(newResolver);
        beneficiary = newBeneficiary;
        admin = newAdmin;
    }

    function lend(
        IRegistry.NFTStandard[] memory nftStandard,
        address[] memory nftAddress,
        uint256[] memory tokenID,
        uint256[] memory lendAmount,
        uint8[] memory maxRentDuration,
        bytes4[] memory dailyRentPrice,
        IResolver.PaymentToken[] memory paymentToken
    ) external override notPaused {
        bundleCall(
            handleLend,
            createLendCallData(
                nftStandard,
                nftAddress,
                tokenID,
                lendAmount,
                maxRentDuration,
                dailyRentPrice,
                paymentToken
            )
        );
    }

    function stopLend(
        address[] memory nftAddress,
        uint256[] memory tokenID,
        uint256[] memory lendingID
    ) external override notPaused {
        bundleCall(
            handleStopLend,
            createActionCallData(nftAddress, tokenID, lendingID)
        );
    }

    function rent(
        address[] memory nftAddress,
        uint256[] memory tokenID,
        uint256[] memory lendingID,
        uint8[] memory rentDuration
    ) external override notPaused {
        bundleCall(
            handleRent,
            createRentCallData(nftAddress, tokenID, lendingID, rentDuration)
        );
    }

    function stopRent(
        address[] memory nftAddress,
        uint256[] memory tokenID,
        uint256[] memory lendingID
    ) external override notPaused {
        bundleCall(
            handleStopRent,
            createActionCallData(nftAddress, tokenID, lendingID)
        );
    }

    //      .-.     .-.     .-.     .-.     .-.     .-.     .-.     .-.     .-.     .-.
    // `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'

    function handleLend(IRegistry.CallData memory cd) private {
        for (uint256 i = cd.left; i < cd.right; i++) {
            ensureIsLendable(cd, i);
            IRegistry.Lending storage lending = lendings[
                keccak256(
                    abi.encodePacked(
                        cd.nftAddress[cd.left],
                        cd.tokenID[i],
                        cd.lendingID[i]
                    )
                )
            ];
            ensureIsNull(lending);
            bool is721 = cd.nftStandard[i];
            lending = Lending({
                lenderAddress: payable(msg.sender),
                lentAmount: is721 ? 1 : uint8(cd.lendAmount[i]),
                maxRentDuration: cd.maxRentDuration[i],
                dailyRentPrice: cd.dailyRentPrice[i],
                nftPrice: cd.nftPrice[i],
                paymentToken: cd.paymentToken[i]
            });
            emit IRegistry.Lent(
                cd.nftAddress[cd.left],
                cd.tokenID[i],
                is721 ? 1 : uint8(cd.lendAmount[i]),
                cd.lendingID[i],
                msg.sender,
                cd.maxRentDuration[i],
                cd.dailyRentPrice[i],
                cd.nftPrice[i],
                is721,
                cd.paymentToken[i]
            );
            lendingId++;
        }
        safeTransfer(
            cd,
            msg.sender,
            address(this),
            sliceArr(cd.tokenID, cd.left, cd.right, 0),
            sliceArr(cd.lendAmount, cd.left, cd.right, 0)
        );
    }

    function handleRent(IRegistry.CallData memory cd) private {
        uint256[] memory lentAmounts = new uint256[](cd.right - cd.left);
        for (uint256 i = cd.left; i < cd.right; i++) {
            bytes32 identifier = keccak256(
                abi.encodePacked(
                    cd.nftAddress[cd.left],
                    cd.tokenID[i],
                    cd.lendingID[i]
                )
            );
            IRegistry.Lending storage lending = lendings[identifier];
            IRegistry.Renting storage renting = rentings[identifier];
            ensureIsNotNull(lending);
            ensureIsNull(renting);
            ensureIsRentable(lending, cd, i, msg.sender);
            uint8 paymentTokenIx = uint8(lending.paymentToken);
            ensureTokenNotSentinel(paymentTokenIx);
            address paymentToken = resolver.getPaymentToken(paymentTokenIx);
            uint256 decimals = ERC20(paymentToken).decimals();
            {
                uint256 scale = 10**decimals;
                uint256 rentPrice = cd.rentDuration[i] *
                    unpackPrice(lending.dailyRentPrice, scale);
                require(rentPrice > 0, "ReNFT::rent price is zero");
                ERC20(paymentToken).safeTransferFrom(
                    msg.sender,
                    address(this),
                    rentPrice
                );
            }
            lentAmounts[i - cd.left] = lending.lendAmount;
            renting.renterAddress = payable(msg.sender);
            renting.rentDuration = cd.rentDuration[i];
            renting.rentedAt = uint32(block.timestamp);
            emit IRegistry.Rented(
                cd.lendingID[i],
                msg.sender,
                cd.rentDuration[i],
                renting.rentedAt
            );
        }
    }

    function handleStopRent(IRegistry.CallData memory cd) private {
        uint256[] memory lentAmounts = new uint256[](cd.right - cd.left);
        for (uint256 i = cd.left; i < cd.right; i++) {
            bytes32 identifier = keccak256(
                abi.encodePacked(
                    cd.nftAddress[cd.left],
                    cd.tokenID[i],
                    cd.lendingID[i]
                )
            );
            IRegistry.Lending storage lending = lendings[identifier];
            IRegistry.Renting storage renting = rentings[identifier];
            ensureIsNotNull(lending);
            ensureIsReturnable(renting, msg.sender, block.timestamp);
            uint256 secondsSinceRentStart = block.timestamp - renting.rentedAt;
            distributePayments(lending, renting, secondsSinceRentStart);
            lentAmounts[i - cd.left] = lending.lentAmount;
            emit IRegistry.StopRent(cd.lendingID[i], uint32(block.timestamp));
            delete renting;
            // todo: add to the available amount the amount that was stopped here.
            // todo: the amount returned here, is in the renting struct
        }
    }

    function handleStopLend(IRegistry.CallData memory cd) private {
        uint256[] memory lentAmounts = new uint256[](cd.right - cd.left);
        for (uint256 i = cd.left; i < cd.right; i++) {
            bytes32 identifier = keccak256(
                abi.encodePacked(
                    cd.nftAddress[cd.left],
                    cd.tokenID[i],
                    cd.lendingID[i]
                )
            );
            Lending storage lending = lendings[identifier];
            Renting storage renting = rentings[identifier];
            require(
                lending.lentAmount == lending.availableAmount,
                "ReNFT::actively rented"
            );
            ensureIsNotNull(lending);
            ensureIsNull(renting);
            ensureIsStoppable(lending, msg.sender);
            lentAmounts[i - cd.left] = lending.lentAmount;
            emit IRegistry.StopLend(cd.lendingID[i], uint32(block.timestamp));
            delete lending;
        }
        safeTransfer(
            cd,
            address(this),
            msg.sender,
            sliceArr(cd.tokenID, cd.left, cd.right, 0),
            sliceArr(lentAmounts, cd.left, cd.right, cd.left)
        );
    }

    //      .-.     .-.     .-.     .-.     .-.     .-.     .-.     .-.     .-.     .-.
    // `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'

    function bundleCall(
        function(IRegistry.CallData memory) handler,
        IRegistry.CallData memory cd
    ) private {
        require(cd.nftAddress.length > 0, "ReNFT::no nfts");
        while (cd.right != cd.nfts.length) {
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

    function takeFee(uint256 rentAmt, IResolver.PaymentToken paymentToken)
        private
        returns (uint256 fee)
    {
        fee = rentAmt * rentFee;
        fee /= 10000;
        uint8 paymentTokenIx = uint8(paymentToken);
        ensureTokenNotSentinel(paymentTokenIx);
        ERC20 pmtToken = ERC20(resolver.getPaymentToken(paymentTokenIx));
        pmtToken.safeTransfer(beneficiary, fee);
    }

    function distributePayments(
        IRegistry.Lending memory lending,
        IRegistry.Renting memory renting,
        uint256 secondsSinceRentStart
    ) private {
        uint8 paymentTokenIx = uint8(lending.paymentToken);
        ensureTokenNotSentinel(paymentTokenIx);
        address pmtToken = resolver.getPaymentToken(paymentTokenIx);
        uint256 decimals = ERC20(pmtToken).decimals();
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
        ERC20(pmtToken).safeTransfer(lending.lenderAddress, sendLenderAmt);
        ERC20(pmtToken).safeTransfer(renting.renterAddress, sendRenterAmt);
    }

    function safeTransfer(
        CallData memory cd,
        address from,
        address to,
        uint256[] memory tokenID,
        uint256[] memory lendAmount
    ) private {
        if (cd.nftStandard[cd.left] == IRegistry.NFTStandard.E721) {
            IERC721(cd.nftAddress[cd.left]).transferFrom(
                from,
                to,
                cd.tokenID[cd.left]
            );
        } else {
            IERC1155(cd.nftAddress[cd.left]).safeBatchTransferFrom(
                from,
                to,
                tokenID,
                lendAmount,
                ""
            );
        }
    }

    //      .-.     .-.     .-.     .-.     .-.     .-.     .-.     .-.     .-.     .-.
    // `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'

    function createLendCallData(
        IRegistry.NFTStandard[] memory nftStandard,
        address[] memory nftAddress,
        uint256[] memory tokenID,
        uint256[] memory lendAmount,
        uint8[] memory maxRentDuration,
        bytes4[] memory dailyRentPrice,
        IResolver.PaymentToken[] memory paymentToken
    ) private pure returns (CallData memory cd) {
        cd = CallData({
            left: 0,
            right: 1,
            nftStandard: nftStandard,
            nftAddress: nftAddress,
            tokenID: tokenID,
            lendAmount: lendAmount,
            lendingID: new uint256[](0),
            rentDuration: new uint8[](0),
            maxRentDuration: maxRentDuration,
            dailyRentPrice: dailyRentPrice,
            paymentToken: paymentToken
        });
    }

    function createRentCallData(
        address[] memory nftAddress,
        uint256[] memory tokenID,
        uint256[] memory lendingID,
        uint8[] memory rentDuration
    ) private pure returns (CallData memory cd) {
        cd = CallData({
            left: 0,
            right: 1,
            nftStandard: new IRegistry.NFTStandard[](0),
            nftAddress: nftAddress,
            tokenID: tokenID,
            lentAmounts: new uint256[](0),
            lendingID: lendingID,
            rentDuration: rentDuration,
            maxRentDuration: new uint8[](0),
            dailyRentPrice: new bytes4[](0),
            paymentToken: new IResolver.PaymentToken[](0)
        });
    }

    function createActionCallData(
        address[] memory nftAddress,
        uint256[] memory tokenID,
        uint256[] memory lendingID
    ) private pure returns (CallData memory cd) {
        cd = CallData({
            left: 0,
            right: 1,
            nftStandard: new IRegistry.NFTStandard[](0),
            nftAddress: nftAddress,
            tokenID: tokenID,
            lendAmount: new uint256[](0),
            lendingID: lendingID,
            rentDuration: new uint8[](0),
            maxRentDuration: new uint8[](0),
            dailyRentPrice: new bytes4[](0),
            paymentToken: new IResolver.PaymentToken[](0)
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
        uint256 fullPrice = w + d;
        return fullPrice;
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

    function setRentFee(uint256 newRentFee) external onlyAdmin {
        require(newRentFee < 10000, "ReNFT::fee exceeds 100pct");
        rentFee = newRentFee;
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
