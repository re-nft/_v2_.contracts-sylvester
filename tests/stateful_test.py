from dataclasses import dataclass
from decimal import Decimal
from enum import Enum

import pytest
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
    tusd = TUSD.deploy({"from": A.deployer})
    usdc = USDC.deploy({"from": A.deployer})
    return dai, tusd, usdc


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


SEPARATOR = "::"


@dataclass
class ContractLending:
    nft_standard_ix: int = 0
    lender_address_ix: int = 1


def concat_lending_id(nft_address, token_id, lending_id):
    return f"{nft_address}{SEPARATOR}{token_id}{SEPARATOR}{lending_id}"


class StateMachine:

    address = strategy("address")
    e721 = contract_strategy("E721")
    e1155 = contract_strategy("E1155")

    def __init__(cls, accounts, Registry, resolver, beneficiary):
        cls.accounts = accounts
        cls.contract = Registry.deploy(
            resolver.address, beneficiary.address, accounts[0], {"from": accounts[0]}
        )

    def setup(self):
        self.lendings = dict()

    def rule_lend_721(self, address, e721):
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

    def rule_lend_1155(self, address, e1155):
        txn = e1155.faucet({"from": address})
        e1155.setApprovalForAll(self.contract.address, True, {"from": address})

        # todo: max_rent_duration is a strategy, and some cases revert
        lending = Lending(
            lender_address=address,
            nft_standard=NFTStandard.E1155.value,
            lend_amount=1,
            available_amount=1,
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

    def rule_lend_batch_1155(self, address, e1155a="e1155", e1155b="e1155"):
        txna = e1155a.faucet({"from": address})
        e1155a.setApprovalForAll(self.contract.address, True, {"from": address})
        txnb = e1155b.faucet({"from": address})
        e1155b.setApprovalForAll(self.contract.address, True, {"from": address})

        lendinga = Lending(
            lender_address=address,
            nft_standard=NFTStandard.E1155.value,
            lend_amount=1,
            available_amount=1,
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
            lend_amount=1,
            available_amount=1,
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

    # def rule_lend_batch_721_1155():
    #     ...

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


#     value = strategy("uint256", max_value="1 ether")
#     address = strategy("address")

#     def __init__(cls, accounts, Depositer):
#         # deploy the contract at the start of the test
#         cls.accounts = accounts
#         cls.contract = Depositer.deploy({"from": accounts[0]})

#     def setup(self):
#         # zero the deposit amounts at the start of each test run
#         self.deposits = {i: 0 for i in self.accounts}

#     def rule_deposit(self, address, value):
#         # make a deposit and adjust the local record
#         self.contract.deposit_for(address, {"from": self.accounts[0], "value": value})
#         self.deposits[address] += value

#     def rule_withdraw(self, address, value):
#         if self.deposits[address] >= value:
#             # make a withdrawal and adjust the local record
#             self.contract.withdraw_from(value, {"from": address})
#             self.deposits[address] -= value
#         else:
#             # attempting to withdraw beyond your balance should revert
#             with brownie.reverts("Insufficient balance"):
#                 self.contract.withdraw_from(value, {"from": address})

#     def invariant(self):
#         # compare the contract deposit amounts with the local record
#         for address, amount in self.deposits.items():
#             assert self.contract.deposited(address) == amount


def test_stateful(Registry, accounts, state_machine, nfts, resolver, payment_tokens):
    beneficiary = accounts.from_mnemonic(
        "test test test test test test test test test test test junk", count=1
    )
    state_machine(StateMachine, accounts, Registry, resolver, beneficiary)
