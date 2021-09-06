from dataclasses import dataclass
from decimal import Decimal
from enum import Enum
from typing import List

import pytest
import brownie
from brownie import (
    DAI,
    TUSD,
    USDC,
    E721,
    E1155,
    Resolver,
    Registry,
    accounts,
)
from brownie.test import strategy, contract_strategy

# invariants
# track the lendings, and their details, and check against the contract
# track the rentings, and their details, and check against the contract
# ^ this includes the diff amounts / available amounts

# rule_lend
# nft(s) leave the lender
# nft(s) end up in the registry contract

EPSILON = Decimal("0.0001")
BILLION = Decimal("1_000_000_000e18")
THOUSAND = Decimal("1_000e18")


class NFTStandard(Enum):
    E721 = 0
    E1155 = 1


class PaymentToken(Enum):
    SENTINEL = 0
    DAI = 1
    USDC = 2
    TUSD = 3


class Accounts:
    def __init__(self, accounts):
        self.deployer = accounts[0]
        self.beneficiary = accounts[1]
        self.lender = accounts[2]
        self.renter = accounts[3]


def approx(val):
    return pytest.approx(val, EPSILON)


# reset state before each test
@pytest.fixture(autouse=True)
def shared_setup(fn_isolation):
    pass


@pytest.fixture(scope="module")
def A():
    A = Accounts(accounts)
    return A


@pytest.fixture(scope="module")
def payment_tokens(A):
    dai = DAI.deploy({"from": A.deployer})
    usdc = USDC.deploy({"from": A.deployer})
    tusd = TUSD.deploy({"from": A.deployer})
    return {1: dai, 2: usdc, 3: tusd}


@pytest.fixture(scope="module")
def resolver(A):
    resolver = Resolver.deploy(A.deployer, {"from": A.deployer})
    return resolver


@pytest.fixture(scope="module")
def nfts(A):
    for i in range(5):
        E721.deploy({"from": A.deployer})
    for i in range(5):
        E1155.deploy({"from": A.deployer})


def find_first(
    nft_standard: NFTStandard,
    lendings: dict,
    lender_blacklist: List[str] = None,
    id_blacklist: List[str] = None,
    rent_amount: int = 0,
):
    if lender_blacklist is None:
        lender_blacklist = []

    if id_blacklist is None:
        id_blacklist = []

    for _id, item in lendings.items():
        _, _, lending_id = _id.split(SEPARATOR)
        if (
            (item.nft_standard == nft_standard)
            and (item.lender_address not in lender_blacklist)
            and (lending_id not in id_blacklist)
            and (item.available_amount >= rent_amount)
        ):
            return _id
    return ""


def mint_and_approve(payment_token_contract, renter_address, registry_address):
    payment_token_contract.faucet({"from": renter_address})
    payment_token_contract.approve(registry_address, BILLION, {"from": renter_address})


def find_from_lender(
    lender_address: str, nft_standard: NFTStandard, lendings: dict, not_in_id: List[str]
):
    for _id, item in lendings.items():
        if (
            item.nft_standard == nft_standard
            and item.lender_address == lender_address
            and _id not in not_in_id
        ):
            return _id
        return ""


# @pytest.fixture(scope="module")
# def setup(A, payment_tokens, nfts, resolver, registry):
#     dai, tusd, usdc = payment_tokens[0], payment_tokens[1], payment_tokens[2]
#     e721, e721b, e1155, e1155b = nfts[0], nfts[1], nfts[2], nfts[3]

#     resolver.setPaymentToken(PaymentToken.DAI.value, dai.address)
#     resolver.setPaymentToken(PaymentToken.USDC.value, usdc.address)
#     resolver.setPaymentToken(PaymentToken.TUSD.value, tusd.address)

#     e721.setApprovalForAll(registry.address, True, {"from": A.lender})
#     e721b.setApprovalForAll(registry.address, True, {"from": A.lender})
#     e1155.setApprovalForAll(registry.address, True, {"from": A.lender})
#     e1155b.setApprovalForAll(registry.address, True, {"from": A.lender})

#     dai.approve(registry.address, BILLION, {"from": A.renter})
#     usdc.approve(registry.address, BILLION, {"from": A.renter})
#     tusd.approve(registry.address, BILLION, {"from": A.renter})

#     return {
#         "dai": dai,
#         "tusd": tusd,
#         "usdc": usdc,
#         "e721": e721,
#         "e721b": e721b,
#         "e1155": e1155,
#         "e1155b": e1155b,
#         "resolver": resolver,
#         "registry": registry,
#     }


@dataclass
class Lending:
    nft_standard: NFTStandard
    lender_address: str
    max_rent_duration: str
    daily_rent_price: bytes
    lend_amount: int
    available_amount: int
    payment_token: PaymentToken

    # below are not part of the contract struct
    nft_address: str
    token_id: int
    lending_id: int


@dataclass
class Renting:
    nft_standard: NFTStandard
    nft_address: str
    token_id: int
    renter_address: str
    lending_id: int
    renting_id: int
    rent_amount: int
    rent_duration: int
    rented_at: int


SEPARATOR = "::"


@dataclass
class ContractLending:
    nft_standard_ix: int = 0
    lender_address_ix: int = 1
    available_amount_ix: int = 5


def concat_lending_id(nft_address, token_id, lending_id):
    return f"{nft_address}{SEPARATOR}{token_id}{SEPARATOR}{lending_id}"


def concat_renting_id(nft_address, token_id, renting_id):
    return f"{nft_address}{SEPARATOR}{token_id}{SEPARATOR}{renting_id}"


def is_actively_rented(lending_id: int, rentings: dict) -> bool:
    for _id, item in rentings.items():
        if item.lending_id == lending_id:
            return True
    return False


class StateMachine:

    address = strategy("address")
    e721 = contract_strategy("E721")
    e1155 = contract_strategy("E1155")
    e1155_lend_amount = strategy("uint256", min_value="1", max_value="10")

    def __init__(cls, accounts, Registry, resolver, beneficiary, payment_tokens):
        cls.accounts = accounts
        cls.contract = Registry.deploy(
            resolver.address, beneficiary.address, accounts[0], {"from": accounts[0]}
        )
        cls.payment_tokens = payment_tokens

    def setup(self):
        self.lendings = dict()
        self.rentings = dict()

    def rule_lend_721(self, address, e721):
        print(f"rule_lend_721. a,e721. {address},{e721}")
        txn = e721.faucet({"from": address})
        e721.setApprovalForAll(self.contract.address, True, {"from": address})

        # todo: max_rent_duration is a strategy, and some cases revert
        lending = Lending(
            lender_address=address,
            nft_standard=NFTStandard.E721.value,
            lend_amount=1,
            available_amount=1,
            max_rent_duration=1,
            daily_rent_price=1,
            payment_token=PaymentToken.DAI.value,
            # not part of the contract's lending struct
            nft_address=e721.address,
            token_id=txn.events["Transfer"]["tokenId"],
            lending_id=0,
        )

        txn = self.contract.lend(
            [lending.nft_standard],
            [lending.nft_address],
            [lending.token_id],
            [lending.lend_amount],
            [lending.max_rent_duration],
            [lending.daily_rent_price],
            [lending.payment_token],
            {"from": address},
        )

        lending.lending_id = txn.events["Lend"]["lendingID"]
        self.lendings[
            concat_lending_id(lending.nft_address, lending.token_id, lending.lending_id)
        ] = lending

    def rule_lend_1155(self, address, e1155, e1155_lend_amount):
        print(f"rule_lend_1155. a,e1155. {address},{e1155}")
        txn = e1155.faucet({"from": address})
        e1155.setApprovalForAll(self.contract.address, True, {"from": address})

        # todo: max_rent_duration is a strategy, and some cases revert
        lending = Lending(
            lender_address=address,
            nft_standard=NFTStandard.E1155.value,
            lend_amount=e1155_lend_amount,
            available_amount=e1155_lend_amount,
            max_rent_duration=1,
            daily_rent_price=1,
            payment_token=PaymentToken.DAI.value,
            # not part of the contract's lending struct
            nft_address=e1155.address,
            token_id=txn.events["TransferSingle"]["id"],
            lending_id=0,
        )

        txn = self.contract.lend(
            [lending.nft_standard],
            [lending.nft_address],
            [lending.token_id],
            [lending.lend_amount],
            [lending.max_rent_duration],
            [lending.daily_rent_price],
            [lending.payment_token],
            {"from": address},
        )

        lending.lending_id = txn.events["Lend"]["lendingID"]
        self.lendings[
            concat_lending_id(lending.nft_address, lending.token_id, lending.lending_id)
        ] = lending

    def rule_lend_batch_721(self, address, e721a="e721", e721b="e721"):
        print(f"rule_lend_batch_721. a,721. {address},{e721a},{e721b}")
        txna = e721a.faucet({"from": address})
        e721a.setApprovalForAll(self.contract.address, True, {"from": address})
        txnb = e721b.faucet({"from": address})
        e721b.setApprovalForAll(self.contract.address, True, {"from": address})

        # todo: max_rent_duration is a strategy, and some cases revert
        lendinga = Lending(
            lender_address=address,
            nft_standard=NFTStandard.E721.value,
            lend_amount=1,
            available_amount=1,
            max_rent_duration=1,
            daily_rent_price=1,
            payment_token=PaymentToken.DAI.value,
            # not part of the contract's lending struct
            nft_address=e721a.address,
            token_id=txna.events["Transfer"]["tokenId"],
            lending_id=0,
        )

        lendingb = Lending(
            lender_address=address,
            nft_standard=NFTStandard.E721.value,
            lend_amount=1,
            available_amount=1,
            max_rent_duration=1,
            daily_rent_price=1,
            payment_token=PaymentToken.DAI.value,
            # not part of the contract's lending struct
            nft_address=e721b.address,
            token_id=txnb.events["Transfer"]["tokenId"],
            lending_id=0,
        )

        txn = self.contract.lend(
            [lendinga.nft_standard, lendingb.nft_standard],
            [lendinga.nft_address, lendingb.nft_address],
            [lendinga.token_id, lendingb.token_id],
            [lendinga.lend_amount, lendingb.lend_amount],
            [lendinga.max_rent_duration, lendingb.max_rent_duration],
            [lendinga.daily_rent_price, lendingb.daily_rent_price],
            [lendinga.payment_token, lendingb.payment_token],
            {"from": address},
        )

        lendinga.lending_id = txn.events["Lend"][0]["lendingID"]
        self.lendings[
            concat_lending_id(
                lendinga.nft_address, lendinga.token_id, lendinga.lending_id
            )
        ] = lendinga
        lendingb.lending_id = txn.events["Lend"][1]["lendingID"]
        self.lendings[
            concat_lending_id(
                lendingb.nft_address, lendingb.token_id, lendingb.lending_id
            )
        ] = lendingb

    def rule_lend_batch_1155(
        self,
        address,
        e1155a="e1155",
        e1155b="e1155",
        e1155a_lend_amount="e1155_lend_amount",
        e1155b_lend_amount="e1155_lend_amount",
    ):
        print(f"rule_lend_batch_1155. a,1155. {address},{e1155a},{e1155b}")
        txna = e1155a.faucet({"from": address})
        e1155a.setApprovalForAll(self.contract.address, True, {"from": address})
        txnb = e1155b.faucet({"from": address})
        e1155b.setApprovalForAll(self.contract.address, True, {"from": address})

        lendinga = Lending(
            lender_address=address,
            nft_standard=NFTStandard.E1155.value,
            lend_amount=e1155a_lend_amount,
            available_amount=e1155a_lend_amount,
            max_rent_duration=1,
            daily_rent_price=1,
            payment_token=PaymentToken.DAI.value,
            # not part of the contract's lending struct
            nft_address=e1155a.address,
            token_id=txna.events["TransferSingle"]["id"],
            lending_id=0,
        )
        lendingb = Lending(
            lender_address=address,
            nft_standard=NFTStandard.E1155.value,
            lend_amount=e1155b_lend_amount,
            available_amount=e1155b_lend_amount,
            max_rent_duration=1,
            daily_rent_price=1,
            payment_token=PaymentToken.DAI.value,
            # not part of the contract's lending struct
            nft_address=e1155b.address,
            token_id=txnb.events["TransferSingle"]["id"],
            lending_id=0,
        )

        txn = self.contract.lend(
            [lendinga.nft_standard, lendingb.nft_standard],
            [lendinga.nft_address, lendingb.nft_address],
            [lendinga.token_id, lendingb.token_id],
            [lendinga.lend_amount, lendingb.lend_amount],
            [lendinga.max_rent_duration, lendingb.max_rent_duration],
            [lendinga.daily_rent_price, lendingb.daily_rent_price],
            [lendinga.payment_token, lendingb.payment_token],
            {"from": address},
        )

        lendinga.lending_id = txn.events["Lend"][0]["lendingID"]
        self.lendings[
            concat_lending_id(
                lendinga.nft_address, lendinga.token_id, lendinga.lending_id
            )
        ] = lendinga
        lendingb.lending_id = txn.events["Lend"][1]["lendingID"]
        self.lendings[
            concat_lending_id(
                lendingb.nft_address, lendingb.token_id, lendingb.lending_id
            )
        ] = lendingb

    def rule_lend_batch_721_1155(
        self,
        address,
        e721a="e721",
        e721b="e721",
        e1155a="e1155",
        e1155b="e1155",
        e1155a_lend_amount="e1155_lend_amount",
        e1155b_lend_amount="e1155_lend_amount",
    ):
        txna = e1155a.faucet({"from": address})
        e1155a.setApprovalForAll(self.contract.address, True, {"from": address})
        txnb = e1155b.faucet({"from": address})
        e1155b.setApprovalForAll(self.contract.address, True, {"from": address})
        txnc = e721a.faucet({"from": address})
        e721a.setApprovalForAll(self.contract.address, True, {"from": address})
        txnd = e721b.faucet({"from": address})
        e721b.setApprovalForAll(self.contract.address, True, {"from": address})

        lendinga = Lending(
            lender_address=address,
            nft_standard=NFTStandard.E1155.value,
            lend_amount=e1155a_lend_amount,
            available_amount=e1155a_lend_amount,
            max_rent_duration=1,
            daily_rent_price=1,
            payment_token=PaymentToken.DAI.value,
            # not part of the contract's lending struct
            nft_address=e1155a.address,
            token_id=txna.events["TransferSingle"]["id"],
            lending_id=0,
        )
        lendingb = Lending(
            lender_address=address,
            nft_standard=NFTStandard.E1155.value,
            lend_amount=e1155b_lend_amount,
            available_amount=e1155b_lend_amount,
            max_rent_duration=1,
            daily_rent_price=1,
            payment_token=PaymentToken.DAI.value,
            # not part of the contract's lending struct
            nft_address=e1155b.address,
            token_id=txnb.events["TransferSingle"]["id"],
            lending_id=0,
        )
        lendingc = Lending(
            lender_address=address,
            nft_standard=NFTStandard.E721.value,
            lend_amount=1,
            available_amount=1,
            max_rent_duration=1,
            daily_rent_price=1,
            payment_token=PaymentToken.DAI.value,
            # not part of the contract's lending struct
            nft_address=e721a.address,
            token_id=txnc.events["Transfer"]["tokenId"],
            lending_id=0,
        )
        lendingd = Lending(
            lender_address=address,
            nft_standard=NFTStandard.E721.value,
            lend_amount=1,
            available_amount=1,
            max_rent_duration=1,
            daily_rent_price=1,
            payment_token=PaymentToken.DAI.value,
            # not part of the contract's lending struct
            nft_address=e721b.address,
            token_id=txnd.events["Transfer"]["tokenId"],
            lending_id=0,
        )

        txn = self.contract.lend(
            [
                lendinga.nft_standard,
                lendingb.nft_standard,
                lendingc.nft_standard,
                lendingd.nft_standard,
            ],
            [
                lendinga.nft_address,
                lendingb.nft_address,
                lendingc.nft_address,
                lendingd.nft_address,
            ],
            [
                lendinga.token_id,
                lendingb.token_id,
                lendingc.token_id,
                lendingd.token_id,
            ],
            [
                lendinga.lend_amount,
                lendingb.lend_amount,
                lendingc.lend_amount,
                lendingd.lend_amount,
            ],
            [
                lendinga.max_rent_duration,
                lendingb.max_rent_duration,
                lendingc.max_rent_duration,
                lendingd.max_rent_duration,
            ],
            [
                lendinga.daily_rent_price,
                lendingb.daily_rent_price,
                lendingc.daily_rent_price,
                lendingd.daily_rent_price,
            ],
            [
                lendinga.payment_token,
                lendingb.payment_token,
                lendingc.payment_token,
                lendingd.payment_token,
            ],
            {"from": address},
        )

        lendinga.lending_id = txn.events["Lend"][0]["lendingID"]
        self.lendings[
            concat_lending_id(
                lendinga.nft_address, lendinga.token_id, lendinga.lending_id
            )
        ] = lendinga
        lendingb.lending_id = txn.events["Lend"][1]["lendingID"]
        self.lendings[
            concat_lending_id(
                lendingb.nft_address, lendingb.token_id, lendingb.lending_id
            )
        ] = lendingb
        lendingc.lending_id = txn.events["Lend"][2]["lendingID"]
        self.lendings[
            concat_lending_id(
                lendingc.nft_address, lendingc.token_id, lendingc.lending_id
            )
        ] = lendingc
        lendingd.lending_id = txn.events["Lend"][3]["lendingID"]
        self.lendings[
            concat_lending_id(
                lendingd.nft_address, lendingd.token_id, lendingd.lending_id
            )
        ] = lendingd

    def rule_stop_lend_721(self):
        first = find_first(NFTStandard.E721.value, self.lendings)
        if first == "":
            return
        print(f"rule_stop_lend_721.a,{first}")
        lending = self.lendings[first]
        # todo: when renting, add the reverts here, since when the available amount != lend amount, this will revert
        if is_actively_rented(lending.lending_id, self.rentings):
            with brownie.reverts("ReNFT::actively rented"):
                self.contract.stopLend(
                    [lending.nft_standard],
                    [lending.nft_address],
                    [lending.token_id],
                    [lending.lending_id],
                    {"from": lending.lender_address},
                )
        else:
            self.contract.stopLend(
                [lending.nft_standard],
                [lending.nft_address],
                [lending.token_id],
                [lending.lending_id],
                {"from": lending.lender_address},
            )
            del self.lendings[first]

    def rule_stop_lend_1155(self):
        first = find_first(NFTStandard.E1155.value, self.lendings)
        if first == "":
            return
        print(f"rule_stop_lend_1155.a,{first}")
        lending = self.lendings[first]
        # todo: when renting, add the reverts here, since when the available amount != lend amount, this will revert
        if is_actively_rented(lending.lending_id, self.rentings):
            with brownie.reverts("ReNFT::actively rented"):
                self.contract.stopLend(
                    [lending.nft_standard],
                    [lending.nft_address],
                    [lending.token_id],
                    [lending.lending_id],
                    {"from": lending.lender_address},
                )
        else:
            self.contract.stopLend(
                [lending.nft_standard],
                [lending.nft_address],
                [lending.token_id],
                [lending.lending_id],
                {"from": lending.lender_address},
            )
            del self.lendings[first]

    def rule_stop_lend_batch_721(self):
        first = find_first(NFTStandard.E721.value, self.lendings)
        if first == "":
            return
        lendinga = self.lendings[first]
        second = find_from_lender(
            lendinga.lender_address, NFTStandard.E721.value, self.lendings, [first]
        )
        if second == "":
            return
        print(f"rule_stop_lend_batch_1155.a,{first},{second}")
        lendingb = self.lendings[second]
        # todo: when renting, add the reverts here, since when the available amount != lend amount, this will revert
        if is_actively_rented(lendinga.lending_id, self.rentings) or is_actively_rented(
            lendingb.lending_id, self.rentings
        ):
            with brownie.reverts("ReNFT::actively rented"):
                self.contract.stopLend(
                    [lendinga.nft_standard, lendingb.nft_standard],
                    [lendinga.nft_address, lendingb.nft_address],
                    [lendinga.token_id, lendingb.token_id],
                    [lendinga.lending_id, lendingb.lending_id],
                    {"from": lendinga.lender_address},
                )
        else:
            self.contract.stopLend(
                [lendinga.nft_standard, lendingb.nft_standard],
                [lendinga.nft_address, lendingb.nft_address],
                [lendinga.token_id, lendingb.token_id],
                [lendinga.lending_id, lendingb.lending_id],
                {"from": lendinga.lender_address},
            )
            del self.lendings[first]
            del self.lendings[second]

    def rule_stop_lend_batch_1155(self):
        first = find_first(NFTStandard.E1155.value, self.lendings)
        if first == "":
            return
        lendinga = self.lendings[first]
        second = find_from_lender(
            lendinga.lender_address, NFTStandard.E1155.value, self.lendings, [first]
        )
        if second == "":
            return
        print(f"rule_stop_lend_batch_1155.a,{first},{second}")
        lendingb = self.lendings[second]
        # todo: when renting, add the reverts here, since when the available amount != lend amount, this will revert
        if is_actively_rented(lendinga.lending_id, self.rentings) or is_actively_rented(
            lendingb.lending_id, self.rentings
        ):
            with brownie.reverts("ReNFT::actively rented"):
                self.contract.stopLend(
                    [lendinga.nft_standard, lendingb.nft_standard],
                    [lendinga.nft_address, lendingb.nft_address],
                    [lendinga.token_id, lendingb.token_id],
                    [lendinga.lending_id, lendingb.lending_id],
                    {"from": lendinga.lender_address},
                )
        else:
            self.contract.stopLend(
                [lendinga.nft_standard, lendingb.nft_standard],
                [lendinga.nft_address, lendingb.nft_address],
                [lendinga.token_id, lendingb.token_id],
                [lendinga.lending_id, lendingb.lending_id],
                {"from": lendinga.lender_address},
            )
            del self.lendings[first]
            del self.lendings[second]

    def rule_stop_lend_batch_721_1155(self):
        first_ = find_first(NFTStandard.E1155.value, self.lendings)
        if first_ == "":
            return
        lendinga = self.lendings[first_]
        second_ = find_from_lender(
            lendinga.lender_address, NFTStandard.E1155.value, self.lendings, [first_]
        )
        if second_ == "":
            return
        lendingb = self.lendings[second_]
        first = find_from_lender(
            lendinga.lender_address, NFTStandard.E721.value, self.lendings, []
        )
        if first == "":
            return
        lendingc = self.lendings[first]
        second = find_from_lender(
            lendinga.lender_address, NFTStandard.E721.value, self.lendings, [first]
        )
        if second == "":
            return
        print(f"rule_stop_lend_batch_721_1155.a,{first_},{second_},{first},{second}")
        lendingd = self.lendings[second]
        # todo: when renting, add the reverts here, since when the available amount != lend amount, this will revert
        if (
            is_actively_rented(lendinga.lending_id, self.rentings)
            or is_actively_rented(lendingb.lending_id, self.rentings)
            or is_actively_rented(lendingc.lending_id, self.rentings)
            or is_actively_rented(lendingd.lending_id, self.rentings)
        ):
            with brownie.reverts("ReNFT::actively rented"):
                self.contract.stopLend(
                    [
                        lendinga.nft_standard,
                        lendingb.nft_standard,
                        lendingc.nft_standard,
                        lendingd.nft_standard,
                    ],
                    [
                        lendinga.nft_address,
                        lendingb.nft_address,
                        lendingc.nft_address,
                        lendingd.nft_address,
                    ],
                    [
                        lendinga.token_id,
                        lendingb.token_id,
                        lendingc.token_id,
                        lendingd.token_id,
                    ],
                    [
                        lendinga.lending_id,
                        lendingb.lending_id,
                        lendingc.lending_id,
                        lendingd.lending_id,
                    ],
                    {"from": lendinga.lender_address},
                )
        else:
            self.contract.stopLend(
                [
                    lendinga.nft_standard,
                    lendingb.nft_standard,
                    lendingc.nft_standard,
                    lendingd.nft_standard,
                ],
                [
                    lendinga.nft_address,
                    lendingb.nft_address,
                    lendingc.nft_address,
                    lendingd.nft_address,
                ],
                [
                    lendinga.token_id,
                    lendingb.token_id,
                    lendingc.token_id,
                    lendingd.token_id,
                ],
                [
                    lendinga.lending_id,
                    lendingb.lending_id,
                    lendingc.lending_id,
                    lendingd.lending_id,
                ],
                {"from": lendinga.lender_address},
            )
            del self.lendings[first_]
            del self.lendings[second_]
            del self.lendings[first]
            del self.lendings[second]

    def rule_rent_721(self, address):
        rent_amount = 1
        first = find_first(
            NFTStandard.E721.value,
            self.lendings,
            lender_blacklist=[address],
            rent_amount=rent_amount,
        )
        if first == "":
            return
        print(f"rule_rent_721.a,{first}")
        lending = self.lendings[first]
        mint_and_approve(
            self.payment_tokens[lending.payment_token], address, self.contract.address
        )
        # todo: rent amount random
        renting = Renting(
            nft_standard=lending.nft_standard,
            nft_address=lending.nft_address,
            token_id=lending.token_id,
            renter_address=address,
            lending_id=lending.lending_id,
            renting_id=0,
            rent_amount=rent_amount,
            rent_duration=1,
            rented_at=0,
        )
        txn = self.contract.rent(
            [renting.nft_standard],
            [renting.nft_address],
            [renting.token_id],
            [renting.lending_id],
            [renting.rent_duration],
            [renting.rent_amount],
            {"from": address},
        )
        renting.renting_id = txn.events["Rent"]["rentingID"]
        self.lendings[first].available_amount -= renting.rent_amount
        self.rentings[
            concat_renting_id(renting.nft_address, renting.token_id, renting.renting_id)
        ] = renting

    def rule_rent_1155(self, address):
        rent_amount = 1
        first = find_first(
            NFTStandard.E1155.value,
            self.lendings,
            lender_blacklist=[address],
            rent_amount=rent_amount,
        )
        if first == "":
            return
        print(f"rule_rent_1155.a,{first}")
        lending = self.lendings[first]
        mint_and_approve(
            self.payment_tokens[lending.payment_token], address, self.contract.address
        )
        # todo: rent amount random
        renting = Renting(
            nft_standard=lending.nft_standard,
            nft_address=lending.nft_address,
            token_id=lending.token_id,
            renter_address=address,
            lending_id=lending.lending_id,
            renting_id=0,
            rent_amount=rent_amount,
            rent_duration=1,
            rented_at=0,
        )
        txn = self.contract.rent(
            [renting.nft_standard],
            [renting.nft_address],
            [renting.token_id],
            [renting.lending_id],
            [renting.rent_duration],
            [renting.rent_amount],
            {"from": address},
        )
        renting.renting_id = txn.events["Rent"]["rentingID"]
        self.lendings[first].available_amount -= renting.rent_amount
        self.rentings[
            concat_renting_id(renting.nft_address, renting.token_id, renting.renting_id)
        ] = renting

    def rule_rent_batch_721(self, address):
        rent_amount = 1
        first = find_first(
            NFTStandard.E721.value,
            self.lendings,
            lender_blacklist=[address],
            rent_amount=rent_amount,
        )
        if first == "":
            return
        second = find_first(
            NFTStandard.E721.value,
            self.lendings,
            lender_blacklist=[address],
            id_blacklist=[self.lendings[first].lending_id],
            rent_amount=rent_amount,
        )
        if second == "":
            return
        print(f"rule_rent_batch_721.a,{first},{second}")
        lendinga = self.lendings[first]
        lendingb = self.lendings[second]
        mint_and_approve(
            self.payment_tokens[lendinga.payment_token], address, self.contract.address
        )
        mint_and_approve(
            self.payment_tokens[lendingb.payment_token], address, self.contract.address
        )
        # todo: rent amount random
        rentinga = Renting(
            nft_standard=lendinga.nft_standard,
            nft_address=lendinga.nft_address,
            token_id=lendinga.token_id,
            renter_address=address,
            lending_id=lendinga.lending_id,
            renting_id=0,
            rent_amount=1,
            rent_duration=1,
            rented_at=0,
        )
        rentingb = Renting(
            nft_standard=lendingb.nft_standard,
            nft_address=lendingb.nft_address,
            token_id=lendingb.token_id,
            renter_address=address,
            lending_id=lendingb.lending_id,
            renting_id=0,
            rent_amount=1,
            rent_duration=1,
            rented_at=0,
        )
        txn = self.contract.rent(
            [rentinga.nft_standard, rentingb.nft_standard],
            [rentinga.nft_address, rentingb.nft_address],
            [rentinga.token_id, rentingb.token_id],
            [rentinga.lending_id, rentingb.lending_id],
            [rentinga.rent_duration, rentingb.rent_duration],
            [rentinga.rent_amount, rentingb.rent_amount],
            {"from": address},
        )
        rentinga.renting_id = txn.events["Rent"][0]["rentingID"]
        rentingb.renting_id = txn.events["Rent"][1]["rentingID"]
        self.lendings[first].available_amount -= rentinga.rent_amount
        self.lendings[second].available_amount -= rentingb.rent_amount
        self.rentings[
            concat_renting_id(
                rentinga.nft_address, rentinga.token_id, rentinga.renting_id
            )
        ] = rentinga
        self.rentings[
            concat_renting_id(
                rentingb.nft_address, rentingb.token_id, rentingb.renting_id
            )
        ] = rentingb

    def rule_rent_batch_1155(self, address):
        rent_amount = 1
        first = find_first(
            NFTStandard.E1155.value,
            self.lendings,
            lender_blacklist=[address],
            rent_amount=rent_amount,
        )
        if first == "":
            return
        second = find_first(
            NFTStandard.E1155.value,
            self.lendings,
            lender_blacklist=[address],
            id_blacklist=[self.lendings[first].lending_id],
            rent_amount=rent_amount,
        )
        if second == "":
            return
        print(f"rule_rent_batch_1155.a,{first},{second}")
        lendinga = self.lendings[first]
        lendingb = self.lendings[second]
        mint_and_approve(
            self.payment_tokens[lendinga.payment_token], address, self.contract.address
        )
        mint_and_approve(
            self.payment_tokens[lendingb.payment_token], address, self.contract.address
        )
        # todo: rent amount random
        rentinga = Renting(
            nft_standard=lendinga.nft_standard,
            nft_address=lendinga.nft_address,
            token_id=lendinga.token_id,
            renter_address=address,
            lending_id=lendinga.lending_id,
            renting_id=0,
            rent_amount=1,
            rent_duration=1,
            rented_at=0,
        )
        rentingb = Renting(
            nft_standard=lendingb.nft_standard,
            nft_address=lendingb.nft_address,
            token_id=lendingb.token_id,
            renter_address=address,
            lending_id=lendingb.lending_id,
            renting_id=0,
            rent_amount=1,
            rent_duration=1,
            rented_at=0,
        )
        txn = self.contract.rent(
            [rentinga.nft_standard, rentingb.nft_standard],
            [rentinga.nft_address, rentingb.nft_address],
            [rentinga.token_id, rentingb.token_id],
            [rentinga.lending_id, rentingb.lending_id],
            [rentinga.rent_duration, rentingb.rent_duration],
            [rentinga.rent_amount, rentingb.rent_amount],
            {"from": address},
        )
        rentinga.renting_id = txn.events["Rent"][0]["rentingID"]
        rentingb.renting_id = txn.events["Rent"][1]["rentingID"]
        self.lendings[first].available_amount -= rentinga.rent_amount
        self.lendings[second].available_amount -= rentingb.rent_amount
        self.rentings[
            concat_renting_id(
                rentinga.nft_address, rentinga.token_id, rentinga.renting_id
            )
        ] = rentinga
        self.rentings[
            concat_renting_id(
                rentingb.nft_address, rentingb.token_id, rentingb.renting_id
            )
        ] = rentingb

    def rule_rent_batch_721_1155(self, address):
        rent_amount = 1
        first = find_first(
            NFTStandard.E721.value,
            self.lendings,
            lender_blacklist=[address],
            rent_amount=rent_amount,
        )
        if first == "":
            return
        second = find_first(
            NFTStandard.E721.value,
            self.lendings,
            lender_blacklist=[address],
            id_blacklist=[self.lendings[first].lending_id],
            rent_amount=rent_amount,
        )
        if second == "":
            return
        first_ = find_first(
            NFTStandard.E1155.value,
            self.lendings,
            lender_blacklist=[address],
            rent_amount=rent_amount,
        )
        if first_ == "":
            return
        second_ = find_first(
            NFTStandard.E1155.value,
            self.lendings,
            lender_blacklist=[address],
            id_blacklist=[self.lendings[first_].lending_id],
            rent_amount=rent_amount,
        )
        if second_ == "":
            return
        print(f"rule_rent_batch_721_1155.a,{first},{second},{first_},{second_}")
        lendinga = self.lendings[first]
        lendingb = self.lendings[second]
        lendingc = self.lendings[first_]
        lendingd = self.lendings[second_]
        mint_and_approve(
            self.payment_tokens[lendinga.payment_token], address, self.contract.address
        )
        mint_and_approve(
            self.payment_tokens[lendingb.payment_token], address, self.contract.address
        )
        mint_and_approve(
            self.payment_tokens[lendingc.payment_token], address, self.contract.address
        )
        mint_and_approve(
            self.payment_tokens[lendingd.payment_token], address, self.contract.address
        )
        # todo: rent amount random
        rentinga = Renting(
            nft_standard=lendinga.nft_standard,
            nft_address=lendinga.nft_address,
            token_id=lendinga.token_id,
            renter_address=address,
            lending_id=lendinga.lending_id,
            renting_id=0,
            rent_amount=1,
            rent_duration=1,
            rented_at=0,
        )
        rentingb = Renting(
            nft_standard=lendingb.nft_standard,
            nft_address=lendingb.nft_address,
            token_id=lendingb.token_id,
            renter_address=address,
            lending_id=lendingb.lending_id,
            renting_id=0,
            rent_amount=1,
            rent_duration=1,
            rented_at=0,
        )
        rentingc = Renting(
            nft_standard=lendingc.nft_standard,
            nft_address=lendingc.nft_address,
            token_id=lendingc.token_id,
            renter_address=address,
            lending_id=lendingc.lending_id,
            renting_id=0,
            rent_amount=1,
            rent_duration=1,
            rented_at=0,
        )
        rentingd = Renting(
            nft_standard=lendingd.nft_standard,
            nft_address=lendingd.nft_address,
            token_id=lendingd.token_id,
            renter_address=address,
            lending_id=lendingd.lending_id,
            renting_id=0,
            rent_amount=1,
            rent_duration=1,
            rented_at=0,
        )
        txn = self.contract.rent(
            [
                rentinga.nft_standard,
                rentingb.nft_standard,
                rentingc.nft_standard,
                rentingd.nft_standard,
            ],
            [
                rentinga.nft_address,
                rentingb.nft_address,
                rentingc.nft_address,
                rentingd.nft_address,
            ],
            [
                rentinga.token_id,
                rentingb.token_id,
                rentingc.token_id,
                rentingd.token_id,
            ],
            [
                rentinga.lending_id,
                rentingb.lending_id,
                rentingc.lending_id,
                rentingd.lending_id,
            ],
            [
                rentinga.rent_duration,
                rentingb.rent_duration,
                rentingc.rent_duration,
                rentingd.rent_duration,
            ],
            [
                rentinga.rent_amount,
                rentingb.rent_amount,
                rentingc.rent_amount,
                rentingd.rent_amount,
            ],
            {"from": address},
        )
        rentinga.renting_id = txn.events["Rent"][0]["rentingID"]
        rentingb.renting_id = txn.events["Rent"][1]["rentingID"]
        rentingc.renting_id = txn.events["Rent"][2]["rentingID"]
        rentingd.renting_id = txn.events["Rent"][3]["rentingID"]
        self.lendings[first].available_amount -= rentinga.rent_amount
        self.lendings[second].available_amount -= rentingb.rent_amount
        self.lendings[first_].available_amount -= rentingc.rent_amount
        self.lendings[second_].available_amount -= rentingd.rent_amount
        self.rentings[
            concat_renting_id(
                rentinga.nft_address, rentinga.token_id, rentinga.renting_id
            )
        ] = rentinga
        self.rentings[
            concat_renting_id(
                rentingb.nft_address, rentingb.token_id, rentingb.renting_id
            )
        ] = rentingb
        self.rentings[
            concat_renting_id(
                rentingc.nft_address, rentingc.token_id, rentingc.renting_id
            )
        ] = rentingc
        self.rentings[
            concat_renting_id(
                rentingd.nft_address, rentingd.token_id, rentingd.renting_id
            )
        ] = rentingd

    def rule_stop_rent_721(self):
        ...

    def rule_stop_rent_1155(self):
        ...

    def rule_stop_rent_batch_721(self):
        ...

    def rule_stop_rent_batch_1155(self):
        ...

    def rule_stop_rent_batch_721_1155(self):
        ...

    def invariant_correct_lending(self):
        for _id, lending in self.lendings.items():
            nft_address, token_id, lending_id = _id.split(SEPARATOR)
            contract_lending = self.contract.getLending(
                nft_address, token_id, lending_id
            )
            assert (
                lending.lender_address.address
                == contract_lending[ContractLending.lender_address_ix]
            )
            assert (
                lending.available_amount
                == contract_lending[ContractLending.available_amount_ix]
            )


def test_stateful(Registry, accounts, state_machine, nfts, resolver, payment_tokens):
    beneficiary = accounts.from_mnemonic(
        "test test test test test test test test test test test junk", count=1
    )
    resolver.setPaymentToken(
        PaymentToken.DAI.value, payment_tokens[PaymentToken.DAI.value]
    )
    resolver.setPaymentToken(
        PaymentToken.USDC.value, payment_tokens[PaymentToken.USDC.value]
    )
    resolver.setPaymentToken(
        PaymentToken.TUSD.value, payment_tokens[PaymentToken.TUSD.value]
    )
    state_machine(
        StateMachine, accounts, Registry, resolver, beneficiary, payment_tokens
    )
