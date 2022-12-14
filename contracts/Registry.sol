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
    uint256 private lendingID = 1;
    uint256 private rentingID = 1;
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

    constructor(address newResolver, address payable newBeneficiary, address newAdmin) {
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
        uint8[] memory paymentToken,
        bool[] memory willAutoRenew
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
                paymentToken,
                willAutoRenew
            )
        );
    }

    function stopLend(
        IRegistry.NFTStandard[] memory nftStandard,
        address[] memory nftAddress,
        uint256[] memory tokenID,
        uint256[] memory _lendingID
    ) external override notPaused {
        bundleCall(handleStopLend, createActionCallData(nftStandard, nftAddress, tokenID, _lendingID, new uint256[](0)));
    }

    function rent(
        IRegistry.NFTStandard[] memory nftStandard,
        address[] memory nftAddress,
        uint256[] memory tokenID,
        uint256[] memory _lendingID,
        uint8[] memory rentDuration,
        uint256[] memory rentAmount
    ) external payable override notPaused {
        bundleCall(
            handleRent, createRentCallData(nftStandard, nftAddress, tokenID, _lendingID, rentDuration, rentAmount)
        );
    }

    function stopRent(
        IRegistry.NFTStandard[] memory nftStandard,
        address[] memory nftAddress,
        uint256[] memory tokenID,
        uint256[] memory _lendingID,
        uint256[] memory _rentingID
    ) external override notPaused {
        bundleCall(handleStopRent, createActionCallData(nftStandard, nftAddress, tokenID, _lendingID, _rentingID));
    }

    function claimRent(
        IRegistry.NFTStandard[] memory nftStandard,
        address[] memory nftAddress,
        uint256[] memory tokenID,
        uint256[] memory _lendingID,
        uint256[] memory _rentingID
    ) external override notPaused {
        bundleCall(handleClaimRent, createActionCallData(nftStandard, nftAddress, tokenID, _lendingID, _rentingID));
    }

    //      .-.     .-.     .-.     .-.     .-.     .-.     .-.     .-.     .-.     .-.
    // `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'

    function handleLend(IRegistry.CallData memory cd) private {
        for (uint256 i = cd.left; i < cd.right; i++) {
            ensureIsLendable(cd, i);
            bytes32 identifier = keccak256(abi.encodePacked(cd.nftAddress[cd.left], cd.tokenID[i], lendingID));
            IRegistry.Lending storage lending = lendings[identifier];
            ensureIsNull(lending);
            ensureTokenNotSentinel(uint8(cd.paymentToken[i]));
            bool is721 = cd.nftStandard[i] == IRegistry.NFTStandard.E721;
            uint16 _lendAmount = uint16(cd.lendAmount[i]);
            if (is721) require(_lendAmount == 1, "ReNFT::lendAmount should be equal to 1");
            lendings[identifier] = IRegistry.Lending({
                nftStandard: cd.nftStandard[i],
                lenderAddress: payable(msg.sender),
                maxRentDuration: cd.maxRentDuration[i],
                dailyRentPrice: cd.dailyRentPrice[i],
                lendAmount: _lendAmount,
                availableAmount: _lendAmount,
                paymentToken: cd.paymentToken[i],
                willAutoRenew: cd.willAutoRenew[i]
            });
            emit IRegistry.Lend(
                is721,
                msg.sender,
                cd.nftAddress[cd.left],
                cd.tokenID[i],
                lendingID,
                cd.maxRentDuration[i],
                cd.dailyRentPrice[i],
                _lendAmount,
                cd.paymentToken[i],
                cd.willAutoRenew[i]
                );
            lendingID++;
        }
        safeTransfer(
            cd,
            msg.sender,
            address(this),
            sliceArr(cd.tokenID, cd.left, cd.right, 0),
            sliceArr(cd.lendAmount, cd.left, cd.right, 0)
        );
    }

    function handleStopLend(IRegistry.CallData memory cd) private {
        uint256[] memory lentAmounts = new uint256[](cd.right - cd.left);
        for (uint256 i = cd.left; i < cd.right; i++) {
            bytes32 lendingIdentifier =
                keccak256(abi.encodePacked(cd.nftAddress[cd.left], cd.tokenID[i], cd.lendingID[i]));
            Lending storage lending = lendings[lendingIdentifier];
            ensureIsNotNull(lending);
            ensureIsStoppable(lending, msg.sender);
            require(cd.nftStandard[i] == lending.nftStandard, "ReNFT::invalid nft standard");
            require(lending.lendAmount == lending.availableAmount, "ReNFT::actively rented");
            lentAmounts[i - cd.left] = lending.lendAmount;
            emit IRegistry.StopLend(cd.lendingID[i], uint32(block.timestamp), lending.lendAmount);
            delete lendings[lendingIdentifier];
        }
        safeTransfer(
            cd,
            address(this),
            msg.sender,
            sliceArr(cd.tokenID, cd.left, cd.right, 0),
            sliceArr(lentAmounts, cd.left, cd.right, cd.left)
        );
    }

    function handleRent(IRegistry.CallData memory cd) private {
        for (uint256 i = cd.left; i < cd.right; i++) {
            bytes32 lendingIdentifier =
                keccak256(abi.encodePacked(cd.nftAddress[cd.left], cd.tokenID[i], cd.lendingID[i]));
            bytes32 rentingIdentifier = keccak256(abi.encodePacked(cd.nftAddress[cd.left], cd.tokenID[i], rentingID));
            IRegistry.Lending storage lending = lendings[lendingIdentifier];
            IRegistry.Renting storage renting = rentings[rentingIdentifier];
            ensureIsNotNull(lending);
            ensureIsNull(renting);
            ensureIsRentable(lending, cd, i, msg.sender);
            require(cd.nftStandard[i] == lending.nftStandard, "ReNFT::invalid nft standard");
            require(cd.rentAmount[i] <= lending.availableAmount, "ReNFT::invalid rent amount");
            uint8 paymentTokenIx = uint8(lending.paymentToken);
            address paymentToken = resolver.getPaymentToken(paymentTokenIx);
            uint256 decimals = ERC20(paymentToken).decimals();
            {
                uint256 scale = 10 ** decimals;
                uint256 rentPrice = cd.rentAmount[i] * cd.rentDuration[i] * unpackPrice(lending.dailyRentPrice, scale);
                require(rentPrice > 0, "ReNFT::rent price is zero");
                ERC20(paymentToken).safeTransferFrom(msg.sender, address(this), rentPrice);
            }
            rentings[rentingIdentifier] = IRegistry.Renting({
                renterAddress: payable(msg.sender),
                rentAmount: uint16(cd.rentAmount[i]),
                rentDuration: cd.rentDuration[i],
                rentedAt: uint32(block.timestamp)
            });
            lendings[lendingIdentifier].availableAmount -= uint16(cd.rentAmount[i]);
            emit IRegistry.Rent(
                msg.sender, cd.lendingID[i], rentingID, uint16(cd.rentAmount[i]), cd.rentDuration[i], renting.rentedAt
                );
            rentingID++;
        }
    }

    function handleStopRent(IRegistry.CallData memory cd) private {
        for (uint256 i = cd.left; i < cd.right; i++) {
            bytes32 lendingIdentifier =
                keccak256(abi.encodePacked(cd.nftAddress[cd.left], cd.tokenID[i], cd.lendingID[i]));
            bytes32 rentingIdentifier =
                keccak256(abi.encodePacked(cd.nftAddress[cd.left], cd.tokenID[i], cd.rentingID[i]));
            IRegistry.Lending storage lending = lendings[lendingIdentifier];
            IRegistry.Renting storage renting = rentings[rentingIdentifier];
            ensureIsNotNull(lending);
            ensureIsNotNull(renting);
            ensureIsReturnable(renting, msg.sender, block.timestamp);
            require(cd.nftStandard[i] == lending.nftStandard, "ReNFT::invalid nft standard");
            require(renting.rentAmount <= lending.lendAmount, "ReNFT::critical error");
            uint256 secondsSinceRentStart = block.timestamp - renting.rentedAt;
            distributePayments(lending, renting, secondsSinceRentStart);
            manageWillAutoRenew(
                lending, renting, cd.nftAddress[cd.left], cd.nftStandard[cd.left], cd.tokenID[i], cd.lendingID[i]
            );
            emit IRegistry.StopRent(cd.rentingID[i], uint32(block.timestamp));
            delete rentings[rentingIdentifier];
        }
    }

    function handleClaimRent(CallData memory cd) private {
        for (uint256 i = cd.left; i < cd.right; i++) {
            bytes32 lendingIdentifier =
                keccak256(abi.encodePacked(cd.nftAddress[cd.left], cd.tokenID[i], cd.lendingID[i]));
            bytes32 rentingIdentifier =
                keccak256(abi.encodePacked(cd.nftAddress[cd.left], cd.tokenID[i], cd.rentingID[i]));
            IRegistry.Lending storage lending = lendings[lendingIdentifier];
            IRegistry.Renting storage renting = rentings[rentingIdentifier];
            ensureIsNotNull(lending);
            ensureIsNotNull(renting);
            ensureIsClaimable(renting, block.timestamp);
            distributeClaimPayment(lending, renting);
            manageWillAutoRenew(
                lending, renting, cd.nftAddress[cd.left], cd.nftStandard[cd.left], cd.tokenID[i], cd.lendingID[i]
            );
            emit IRegistry.RentClaimed(cd.rentingID[i], uint32(block.timestamp));
            delete rentings[rentingIdentifier];
        }
    }

    //      .-.     .-.     .-.     .-.     .-.     .-.     .-.     .-.     .-.     .-.
    // `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'

    function manageWillAutoRenew(
        IRegistry.Lending storage lending,
        IRegistry.Renting storage renting,
        address nftAddress,
        IRegistry.NFTStandard nftStandard,
        uint256 tokenID,
        uint256 lendingID
    ) private {
        if (lending.willAutoRenew == false) {
            // No automatic renewal, stop the lending (or a portion of it) completely!

            // We must be careful here, because the lending might be for an ERC1155 token, which means
            // that the renting.rentAmount might not be the same as the lending.lendAmount. In this case, we
            // must NOT delete the lending, but only decrement the lending.lendAmount by the renting.rentAmount.
            // Notice: this is only possible for an ERC1155 tokens!
            if (lending.lendAmount > renting.rentAmount) {
                // update lending lendAmount to reflect NOT renewing the lending
                // Do not update lending.availableAmount, because the assets will not be lent out again
                lending.lendAmount -= renting.rentAmount;
                // return the assets to the lender
                IERC1155(nftAddress).safeTransferFrom(
                    address(this), lending.lenderAddress, tokenID, uint256(renting.rentAmount), ""
                );
            }
            // If the lending is for an ERC721 token, then the renting.rentAmount is always the same as the
            // lending.lendAmount, and we can delete the lending. If the lending is for an ERC1155 token and
            // the renting.rentAmount is the same as the lending.lendAmount, then we can also delete the
            // lending.
            else if (lending.lendAmount == renting.rentAmount) {
                // return the assets to the lender
                if (nftStandard == IRegistry.NFTStandard.E721) {
                    IERC721(nftAddress).transferFrom(address(this), lending.lenderAddress, tokenID);
                } else {
                    IERC1155(nftAddress).safeTransferFrom(
                        address(this), lending.lenderAddress, tokenID, uint256(renting.rentAmount), ""
                    );
                }
                delete lendings[keccak256(abi.encodePacked(nftAddress, tokenID, lendingID))];
            }
            // StopLend event but only the amount that was not renewed (or all of it)
            emit IRegistry.StopLend(lendingID, uint32(block.timestamp), renting.rentAmount);
        } else {
            // automatic renewal, make the assets available to be lent out again
            lending.availableAmount += renting.rentAmount;
        }
    }

    function bundleCall(function(IRegistry.CallData memory) handler, IRegistry.CallData memory cd) private {
        require(cd.nftAddress.length > 0, "ReNFT::no nfts");
        while (cd.right != cd.nftAddress.length) {
            if (
                (cd.nftAddress[cd.left] == cd.nftAddress[cd.right])
                    && (cd.nftStandard[cd.right] == IRegistry.NFTStandard.E1155)
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

    function takeFee(uint256 rentAmt, ERC20 token) private returns (uint256 fee) {
        fee = rentAmt * rentFee;
        fee /= 10000;
        token.safeTransfer(beneficiary, fee);
    }

    function distributePayments(
        IRegistry.Lending memory lending,
        IRegistry.Renting memory renting,
        uint256 secondsSinceRentStart
    ) private {
        uint8 paymentTokenIx = uint8(lending.paymentToken);
        ERC20 paymentToken = ERC20(resolver.getPaymentToken(paymentTokenIx));
        uint256 decimals = paymentToken.decimals();
        uint256 scale = 10 ** decimals;
        uint256 rentPrice = renting.rentAmount * unpackPrice(lending.dailyRentPrice, scale);
        uint256 totalRenterPmt = rentPrice * renting.rentDuration;
        uint256 sendLenderAmt = (secondsSinceRentStart * rentPrice) / SECONDS_IN_DAY;
        require(totalRenterPmt > 0, "ReNFT::total renter payment is zero");
        require(sendLenderAmt > 0, "ReNFT::lender payment is zero");
        uint256 sendRenterAmt = totalRenterPmt - sendLenderAmt;
        if (rentFee != 0) {
            uint256 takenFee = takeFee(sendLenderAmt, paymentToken);
            sendLenderAmt -= takenFee;
        }
        paymentToken.safeTransfer(lending.lenderAddress, sendLenderAmt);
        if (sendRenterAmt > 0) {
            paymentToken.safeTransfer(renting.renterAddress, sendRenterAmt);
        }
    }

    function distributeClaimPayment(IRegistry.Lending memory lending, IRegistry.Renting memory renting) private {
        uint8 paymentTokenIx = uint8(lending.paymentToken);
        ERC20 paymentToken = ERC20(resolver.getPaymentToken(paymentTokenIx));
        uint256 decimals = paymentToken.decimals();
        uint256 scale = 10 ** decimals;
        uint256 rentPrice = renting.rentAmount * unpackPrice(lending.dailyRentPrice, scale);
        uint256 finalAmt = rentPrice * renting.rentDuration;
        uint256 takenFee = 0;
        if (rentFee != 0) {
            takenFee = takeFee(finalAmt, paymentToken);
        }
        paymentToken.safeTransfer(lending.lenderAddress, finalAmt - takenFee);
    }

    function safeTransfer(
        CallData memory cd,
        address from,
        address to,
        uint256[] memory tokenID,
        uint256[] memory lendAmount
    ) private {
        if (cd.nftStandard[cd.left] == IRegistry.NFTStandard.E721) {
            IERC721(cd.nftAddress[cd.left]).transferFrom(from, to, cd.tokenID[cd.left]);
        } else {
            IERC1155(cd.nftAddress[cd.left]).safeBatchTransferFrom(from, to, tokenID, lendAmount, "");
        }
    }

    //      .-.     .-.     .-.     .-.     .-.     .-.     .-.     .-.     .-.     .-.
    // `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'

    function getLending(address nftAddress, uint256 tokenID, uint256 _lendingID)
        external
        view
        returns (uint8, address, uint8, bytes4, uint16, uint16, uint8)
    {
        bytes32 identifier = keccak256(abi.encodePacked(nftAddress, tokenID, _lendingID));
        IRegistry.Lending storage lending = lendings[identifier];
        return (
            uint8(lending.nftStandard),
            lending.lenderAddress,
            lending.maxRentDuration,
            lending.dailyRentPrice,
            lending.lendAmount,
            lending.availableAmount,
            uint8(lending.paymentToken)
        );
    }

    function getRenting(address nftAddress, uint256 tokenID, uint256 _rentingID)
        external
        view
        returns (address, uint16, uint8, uint32)
    {
        bytes32 identifier = keccak256(abi.encodePacked(nftAddress, tokenID, _rentingID));
        IRegistry.Renting storage renting = rentings[identifier];
        return (renting.renterAddress, renting.rentAmount, renting.rentDuration, renting.rentedAt);
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
        uint8[] memory paymentToken,
        bool[] memory willAutoRenew
    ) private pure returns (CallData memory cd) {
        cd = CallData({
            left: 0,
            right: 1,
            nftStandard: nftStandard,
            nftAddress: nftAddress,
            tokenID: tokenID,
            lendAmount: lendAmount,
            lendingID: new uint256[](0),
            rentingID: new uint256[](0),
            rentDuration: new uint8[](0),
            rentAmount: new uint256[](0),
            maxRentDuration: maxRentDuration,
            dailyRentPrice: dailyRentPrice,
            paymentToken: paymentToken,
            willAutoRenew: willAutoRenew
        });
    }

    function createRentCallData(
        IRegistry.NFTStandard[] memory nftStandard,
        address[] memory nftAddress,
        uint256[] memory tokenID,
        uint256[] memory _lendingID,
        uint8[] memory rentDuration,
        uint256[] memory rentAmount
    ) private pure returns (CallData memory cd) {
        cd = CallData({
            left: 0,
            right: 1,
            nftStandard: nftStandard,
            nftAddress: nftAddress,
            tokenID: tokenID,
            lendAmount: new uint256[](0),
            lendingID: _lendingID,
            rentingID: new uint256[](0),
            rentDuration: rentDuration,
            rentAmount: rentAmount,
            maxRentDuration: new uint8[](0),
            dailyRentPrice: new bytes4[](0),
            paymentToken: new uint8[](0),
            willAutoRenew: new bool[](0)
        });
    }

    function createActionCallData(
        IRegistry.NFTStandard[] memory nftStandard,
        address[] memory nftAddress,
        uint256[] memory tokenID,
        uint256[] memory _lendingID,
        uint256[] memory _rentingID
    ) private pure returns (CallData memory cd) {
        cd = CallData({
            left: 0,
            right: 1,
            nftStandard: nftStandard,
            nftAddress: nftAddress,
            tokenID: tokenID,
            lendAmount: new uint256[](0),
            lendingID: _lendingID,
            rentingID: _rentingID,
            rentDuration: new uint8[](0),
            rentAmount: new uint256[](0),
            maxRentDuration: new uint8[](0),
            dailyRentPrice: new bytes4[](0),
            paymentToken: new uint8[](0),
            willAutoRenew: new bool[](0)
        });
    }

    function unpackPrice(bytes4 price, uint256 scale) private pure returns (uint256) {
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

    function sliceArr(uint256[] memory arr, uint256 fromIx, uint256 toIx, uint256 arrOffset)
        private
        pure
        returns (uint256[] memory r)
    {
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
    }

    function ensureIsNotNull(Lending memory lending) private pure {
        ensureIsNotZeroAddr(lending.lenderAddress);
        require(lending.maxRentDuration != 0, "ReNFT::duration zero");
        require(lending.dailyRentPrice != 0, "ReNFT::rent price is zero");
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
        require(cd.lendAmount[i] > 0, "ReNFT::lend amount is zero");
        require(cd.lendAmount[i] <= type(uint16).max, "ReNFT::not uint16");
        require(cd.maxRentDuration[i] > 0, "ReNFT::duration is zero");
        require(cd.maxRentDuration[i] <= type(uint8).max, "ReNFT::not uint8");
        require(uint32(cd.dailyRentPrice[i]) > 0, "ReNFT::rent price is zero");
    }

    function ensureIsRentable(Lending memory lending, CallData memory cd, uint256 i, address msgSender) private pure {
        require(msgSender != lending.lenderAddress, "ReNFT::cant rent own nft");
        require(cd.rentDuration[i] <= type(uint8).max, "ReNFT::not uint8");
        require(cd.rentDuration[i] > 0, "ReNFT::duration is zero");
        require(cd.rentAmount[i] <= type(uint16).max, "ReNFT::not uint16");
        require(cd.rentAmount[i] > 0, "ReNFT::rentAmount is zero");
        require(cd.rentDuration[i] <= lending.maxRentDuration, "ReNFT::rent duration exceeds allowed max");
    }

    function ensureIsReturnable(Renting memory renting, address msgSender, uint256 blockTimestamp) private pure {
        require(renting.renterAddress == msgSender, "ReNFT::not renter");
        require(!isPastReturnDate(renting, blockTimestamp), "ReNFT::past return date");
    }

    function ensureIsStoppable(Lending memory lending, address msgSender) private pure {
        require(lending.lenderAddress == msgSender, "ReNFT::not lender");
    }

    function ensureIsUnpackablePrice(bytes4 price, uint256 scale) private pure {
        require(uint32(price) > 0, "ReNFT::invalid price");
        require(scale >= 10000, "ReNFT::invalid scale");
    }

    function ensureTokenNotSentinel(uint8 paymentIx) private pure {
        require(paymentIx > 0, "ReNFT::token is sentinel");
    }

    function ensureIsClaimable(IRegistry.Renting memory renting, uint256 blockTimestamp) private pure {
        require(isPastReturnDate(renting, blockTimestamp), "ReNFT::return date not passed");
    }

    function isPastReturnDate(Renting memory renting, uint256 nowTime) private pure returns (bool) {
        require(nowTime > renting.rentedAt, "ReNFT::now before rented");
        return nowTime - renting.rentedAt > renting.rentDuration * SECONDS_IN_DAY;
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
