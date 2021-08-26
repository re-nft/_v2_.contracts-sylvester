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
        address _resolver,
        address payable _beneficiary,
        address _admin
    ) {
        ensureIsNotZeroAddr(_resolver);
        ensureIsNotZeroAddr(_beneficiary);
        ensureIsNotZeroAddr(_admin);
        resolver = IResolver(_resolver);
        beneficiary = _beneficiary;
        admin = _admin;
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

    function handleRent(CallData memory _cd) private {
        uint256[] memory lentAmounts = new uint256[](_cd.right - _cd.left);

        for (uint256 i = _cd.left; i < _cd.right; i++) {
            LendingRenting storage item = lendingRenting[
                keccak256(
                    abi.encodePacked(
                        _cd.nfts[_cd.left],
                        _cd.tokenIds[i],
                        _cd.lendingIds[i]
                    )
                )
            ];

            ensureIsNotNull(item.lending);
            ensureIsNull(item.renting);
            ensureIsRentable(item.lending, _cd, i, msg.sender);

            uint8 paymentTokenIx = uint8(item.lending.paymentToken);
            ensureTokenNotSentinel(paymentTokenIx);
            address paymentToken = resolver.getPaymentToken(paymentTokenIx);
            uint256 decimals = ERC20(paymentToken).decimals();

            {
                uint256 scale = 10**decimals;
                uint256 rentPrice = _cd.rentDurations[i] *
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

            lentAmounts[i - _cd.left] = item.lending.lentAmount;

            item.renting.renterAddress = payable(msg.sender);
            item.renting.rentDuration = _cd.rentDurations[i];
            item.renting.rentedAt = uint32(block.timestamp);

            emit Rented(
                _cd.lendingIds[i],
                msg.sender,
                _cd.rentDurations[i],
                item.renting.rentedAt
            );
        }
    }

    function handleStopRent(CallData memory _cd) private {
        uint256[] memory lentAmounts = new uint256[](_cd.right - _cd.left);
        for (uint256 i = _cd.left; i < _cd.right; i++) {
            bytes32 identifier = keccak256(
                abi.encodePacked(
                    _cd.nfts[_cd.left],
                    _cd.tokenIds[i],
                    _cd.lendingIds[i]
                )
            );
            Renting storage item = rentings[identifier];
            ensureIsNotNull(item.lending);
            ensureIsReturnable(item.renting, msg.sender, block.timestamp);
            uint256 secondsSinceRentStart = block.timestamp -
                item.renting.rentedAt;
            distributePayments(item, secondsSinceRentStart);
            lentAmounts[i - _cd.left] = item.lending.lentAmount;
            emit Returned(_cd.lendingIds[i], uint32(block.timestamp));
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

    function takeFee(uint256 _rent, IResolver.PaymentToken _paymentToken)
        private
        returns (uint256 fee)
    {
        fee = _rent * rentFee;
        fee /= 10000;
        uint8 paymentTokenIx = uint8(_paymentToken);
        ensureTokenNotSentinel(paymentTokenIx);
        ERC20 paymentToken = ERC20(resolver.getPaymentToken(paymentTokenIx));
        paymentToken.safeTransfer(beneficiary, fee);
    }

    function distributePayments(
        LendingRenting storage _lendingRenting,
        uint256 _secondsSinceRentStart
    ) private {
        uint8 paymentTokenIx = uint8(_lendingRenting.lending.paymentToken);
        ensureTokenNotSentinel(paymentTokenIx);
        address paymentToken = resolver.getPaymentToken(paymentTokenIx);
        uint256 decimals = ERC20(paymentToken).decimals();

        uint256 scale = 10**decimals;
        uint256 nftPrice = _lendingRenting.lending.lentAmount *
            unpackPrice(_lendingRenting.lending.nftPrice, scale);
        uint256 rentPrice = unpackPrice(
            _lendingRenting.lending.dailyRentPrice,
            scale
        );
        uint256 totalRenterPmtWoCollateral = rentPrice *
            _lendingRenting.renting.rentDuration;
        uint256 sendLenderAmt = (_secondsSinceRentStart * rentPrice) /
            SECONDS_IN_DAY;
        require(
            totalRenterPmtWoCollateral > 0,
            "ReNFT::total payment wo collateral is zero"
        );
        require(sendLenderAmt > 0, "ReNFT::lender payment is zero");
        uint256 sendRenterAmt = totalRenterPmtWoCollateral - sendLenderAmt;

        uint256 takenFee = takeFee(
            sendLenderAmt,
            _lendingRenting.lending.paymentToken
        );

        sendLenderAmt -= takenFee;
        sendRenterAmt += nftPrice;

        ERC20(paymentToken).safeTransfer(
            _lendingRenting.lending.lenderAddress,
            sendLenderAmt
        );
        ERC20(paymentToken).safeTransfer(
            _lendingRenting.renting.renterAddress,
            sendRenterAmt
        );
    }

    function safeTransfer(
        CallData memory _cd,
        address _from,
        address _to,
        uint256[] memory _tokenIds,
        uint256[] memory _lentAmounts
    ) private {
        if (is721(_cd.nfts[_cd.left])) {
            IERC721(_cd.nfts[_cd.left]).transferFrom(
                _from,
                _to,
                _cd.tokenIds[_cd.left]
            );
        } else if (is1155(_cd.nfts[_cd.left])) {
            IERC1155(_cd.nfts[_cd.left]).safeBatchTransferFrom(
                _from,
                _to,
                _tokenIds,
                _lentAmounts,
                ""
            );
        } else {
            revert("ReNFT::unsupported token type");
        }
    }

    //      .-.     .-.     .-.     .-.     .-.     .-.     .-.     .-.     .-.     .-.
    // `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'

    function createLendCallData(
        address[] memory _nfts,
        uint256[] memory _tokenIds,
        uint256[] memory _lendAmounts,
        uint8[] memory _maxRentDurations,
        bytes4[] memory _dailyRentPrices,
        bytes4[] memory _nftPrices,
        IResolver.PaymentToken[] memory _paymentTokens
    ) private pure returns (CallData memory cd) {
        cd = CallData({
            left: 0,
            right: 1,
            nfts: _nfts,
            tokenIds: _tokenIds,
            lentAmounts: _lendAmounts,
            lendingIds: new uint256[](0),
            rentDurations: new uint8[](0),
            maxRentDurations: _maxRentDurations,
            dailyRentPrices: _dailyRentPrices,
            nftPrices: _nftPrices,
            paymentTokens: _paymentTokens
        });
    }

    function createRentCallData(
        address[] memory _nfts,
        uint256[] memory _tokenIds,
        uint256[] memory _lendingIds,
        uint8[] memory _rentDurations
    ) private pure returns (CallData memory cd) {
        cd = CallData({
            left: 0,
            right: 1,
            nfts: _nfts,
            tokenIds: _tokenIds,
            lentAmounts: new uint256[](0),
            lendingIds: _lendingIds,
            rentDurations: _rentDurations,
            maxRentDurations: new uint8[](0),
            dailyRentPrices: new bytes4[](0),
            nftPrices: new bytes4[](0),
            paymentTokens: new IResolver.PaymentToken[](0)
        });
    }

    function createActionCallData(
        address[] memory _nfts,
        uint256[] memory _tokenIds,
        uint256[] memory _lendingIds
    ) private pure returns (CallData memory cd) {
        cd = CallData({
            left: 0,
            right: 1,
            nfts: _nfts,
            tokenIds: _tokenIds,
            lentAmounts: new uint256[](0),
            lendingIds: _lendingIds,
            rentDurations: new uint8[](0),
            maxRentDurations: new uint8[](0),
            dailyRentPrices: new bytes4[](0),
            nftPrices: new bytes4[](0),
            paymentTokens: new IResolver.PaymentToken[](0)
        });
    }

    function unpackPrice(bytes4 _price, uint256 _scale)
        private
        pure
        returns (uint256)
    {
        ensureIsUnpackablePrice(_price, _scale);

        uint16 whole = uint16(bytes2(_price));
        uint16 decimal = uint16(bytes2(_price << 16));
        uint256 decimalScale = _scale / 10000;

        if (whole > 9999) {
            whole = 9999;
        }
        if (decimal > 9999) {
            decimal = 9999;
        }

        uint256 w = whole * _scale;
        uint256 d = decimal * decimalScale;
        uint256 price = w + d;

        return price;
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

    function ensureIsNotZeroAddr(address _addr) private pure {
        require(_addr != address(0), "ReNFT::zero address");
    }

    function ensureIsZeroAddr(address _addr) private pure {
        require(_addr == address(0), "ReNFT::not a zero address");
    }

    function ensureIsNull(Lending memory _lending) private pure {
        ensureIsZeroAddr(_lending.lenderAddress);
        require(_lending.maxRentDuration == 0, "ReNFT::duration not zero");
        require(_lending.dailyRentPrice == 0, "ReNFT::rent price not zero");
        require(_lending.nftPrice == 0, "ReNFT::nft price not zero");
    }

    function ensureIsNotNull(Lending memory _lending) private pure {
        ensureIsNotZeroAddr(_lending.lenderAddress);
        require(_lending.maxRentDuration != 0, "ReNFT::duration zero");
        require(_lending.dailyRentPrice != 0, "ReNFT::rent price is zero");
        require(_lending.nftPrice != 0, "ReNFT::nft price is zero");
    }

    function ensureIsNull(Renting memory _renting) private pure {
        ensureIsZeroAddr(_renting.renterAddress);
        require(_renting.rentDuration == 0, "ReNFT::duration not zero");
        require(_renting.rentedAt == 0, "ReNFT::rented at not zero");
    }

    function ensureIsNotNull(Renting memory _renting) private pure {
        ensureIsNotZeroAddr(_renting.renterAddress);
        require(_renting.rentDuration != 0, "ReNFT::duration is zero");
        require(_renting.rentedAt != 0, "ReNFT::rented at is zero");
    }

    function ensureIsLendable(CallData memory _cd, uint256 _i) private pure {
        require(_cd.lentAmounts[_i] > 0, "ReNFT::lend amount is zero");
        require(_cd.lentAmounts[_i] <= type(uint8).max, "ReNFT::not uint8");
        require(_cd.maxRentDurations[_i] > 0, "ReNFT::duration is zero");
        require(
            _cd.maxRentDurations[_i] <= type(uint8).max,
            "ReNFT::not uint8"
        );
        require(
            uint32(_cd.dailyRentPrices[_i]) > 0,
            "ReNFT::rent price is zero"
        );
        require(uint32(_cd.nftPrices[_i]) > 0, "ReNFT::nft price is zero");
    }

    function ensureIsRentable(
        Lending memory _lending,
        CallData memory _cd,
        uint256 _i,
        address _msgSender
    ) private pure {
        require(
            _msgSender != _lending.lenderAddress,
            "ReNFT::cant rent own nft"
        );
        require(_cd.rentDurations[_i] <= type(uint8).max, "ReNFT::not uint8");
        require(_cd.rentDurations[_i] > 0, "ReNFT::duration is zero");
        require(
            _cd.rentDurations[_i] <= _lending.maxRentDuration,
            "ReNFT::rent duration exceeds allowed max"
        );
    }

    function ensureIsReturnable(
        Renting memory _renting,
        address _msgSender,
        uint256 _blockTimestamp
    ) private pure {
        require(_renting.renterAddress == _msgSender, "ReNFT::not renter");
        require(
            !isPastReturnDate(_renting, _blockTimestamp),
            "ReNFT::past return date"
        );
    }

    function ensureIsStoppable(Lending memory _lending, address _msgSender)
        private
        pure
    {
        require(_lending.lenderAddress == _msgSender, "ReNFT::not lender");
    }

    function ensureIsUnpackablePrice(bytes4 _price, uint256 _scale)
        private
        pure
    {
        require(uint32(_price) > 0, "ReNFT::invalid price");
        require(_scale >= 10000, "ReNFT::invalid scale");
    }

    function ensureTokenNotSentinel(uint8 _paymentIx) private pure {
        require(_paymentIx > 0, "ReNFT::token is sentinel");
    }

    function isPastReturnDate(Renting memory _renting, uint256 _now)
        private
        pure
        returns (bool)
    {
        require(_now > _renting.rentedAt, "ReNFT::now before rented");
        return
            _now - _renting.rentedAt > _renting.rentDuration * SECONDS_IN_DAY;
    }

    //      .-.     .-.     .-.     .-.     .-.     .-.     .-.     .-.     .-.     .-.
    // `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'

    function setRentFee(uint256 _rentFee) external onlyAdmin {
        require(_rentFee < 10000, "ReNFT::fee exceeds 100pct");
        rentFee = _rentFee;
    }

    function setBeneficiary(address payable _newBeneficiary)
        external
        onlyAdmin
    {
        beneficiary = _newBeneficiary;
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
