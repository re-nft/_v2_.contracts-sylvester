# pylint: disable=redefined-outer-name,invalid-name,no-name-in-module,unused-argument,too-few-public-methods,too-many-arguments
# type: ignore
from decimal import Decimal
from enum import Enum

import pytest
from brownie import (
    DAI,
    TUSD,
    USDC,
    E721,
    E721B,
    E1155,
    E1155B,
    Resolver,
    Registry,
    accounts,
    chain,
)


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
    dai = DAI.deploy({"from": A.renter})
    tusd = TUSD.deploy({"from": A.renter})
    usdc = USDC.deploy({"from": A.renter})

    return dai, tusd, usdc


@pytest.fixture(scope="module")
def resolver(A):
    resolver = Resolver.deploy(A.deployer, {"from": A.deployer})
    return resolver


@pytest.fixture(scope="module")
def nfts(A):

    e721 = E721.deploy({"from": A.lender})
    e721b = E721B.deploy({"from": A.lender})
    e1155 = E1155.deploy({"from": A.lender})
    e1155b = E1155B.deploy({"from": A.lender})

    return e721, e721b, e1155, e1155b


@pytest.fixture(scope="module")
def registry(A, resolver):
    registry = Registry.deploy(
        resolver.address, A.beneficiary, A.deployer, {"from": A.deployer}
    )
    return registry


@pytest.fixture(scope="module")
def setup(A, payment_tokens, nfts, resolver, registry):
    dai, tusd, usdc = payment_tokens[0], payment_tokens[1], payment_tokens[2]
    e721, e721b, e1155, e1155b = nfts[0], nfts[1], nfts[2], nfts[3]

    resolver.setPaymentToken(PaymentToken.DAI.value, dai.address)
    resolver.setPaymentToken(PaymentToken.USDC.value, usdc.address)
    resolver.setPaymentToken(PaymentToken.TUSD.value, tusd.address)

    e721.setApprovalForAll(registry.address, True, {"from": A.lender})
    e721b.setApprovalForAll(registry.address, True, {"from": A.lender})
    e1155.setApprovalForAll(registry.address, True, {"from": A.lender})
    e1155b.setApprovalForAll(registry.address, True, {"from": A.lender})

    dai.approve(registry.address, BILLION, {"from": A.renter})
    usdc.approve(registry.address, BILLION, {"from": A.renter})
    tusd.approve(registry.address, BILLION, {"from": A.renter})

    return {
        "dai": dai,
        "tusd": tusd,
        "usdc": usdc,
        "e721": e721,
        "e721b": e721b,
        "e1155": e1155,
        "e1155b": e1155b,
        "resolver": resolver,
        "registry": registry,
    }


def test_e721(A, setup):
    token_id = 1
    lend_amount = 1
    max_rent_duration = 1
    daily_rent_price = 1

    lending_id = 1

    setup["registry"].lend(
        [NFTStandard.E721.value],
        [setup["e721"].address],
        [token_id],
        [lend_amount],
        [max_rent_duration],
        [daily_rent_price],
        [PaymentToken.DAI.value],
        {"from": A.lender},
    )

    setup["registry"].stopLend(
        [NFTStandard.E721.value],
        [setup["e721"].address],
        [token_id],
        [lending_id],
        {"from": A.lender},
    )


def test_e721_e721b(A, setup):
    token_id = 1
    lend_amount = 1
    max_rent_duration = 1
    daily_rent_price = 1

    lending_id = 1

    setup["registry"].lend(
        [NFTStandard.E721.value, NFTStandard.E721.value],
        [setup["e721"].address, setup["e721b"].address],
        [token_id, token_id],
        [lend_amount, lend_amount],
        [max_rent_duration, max_rent_duration],
        [daily_rent_price, daily_rent_price],
        [PaymentToken.DAI.value, PaymentToken.DAI.value],
        {"from": A.lender},
    )

    setup["registry"].stopLend(
        [NFTStandard.E721.value, NFTStandard.E721.value],
        [setup["e721"].address, setup["e721b"].address],
        [token_id, token_id],
        [lending_id, lending_id + 1],
        {"from": A.lender},
    )


def test_e721_e721b_e1155(A, setup):
    token_id = 1
    lend_amount = 1
    max_rent_duration = 1
    daily_rent_price = 1

    lending_id = 1

    setup["registry"].lend(
        [NFTStandard.E721.value, NFTStandard.E721.value, NFTStandard.E1155.value],
        [setup["e721"].address, setup["e721b"].address, setup["e1155"].address],
        [token_id, token_id, setup["e1155"].GOLD()],
        [lend_amount, lend_amount, lend_amount],
        [max_rent_duration, max_rent_duration, max_rent_duration],
        [daily_rent_price, daily_rent_price, daily_rent_price],
        [PaymentToken.DAI.value, PaymentToken.DAI.value, PaymentToken.DAI.value],
        {"from": A.lender},
    )

    setup["registry"].stopLend(
        [NFTStandard.E721.value, NFTStandard.E721.value, NFTStandard.E1155.value],
        [setup["e721"].address, setup["e721b"].address, setup["e1155"].address],
        [token_id, token_id, setup["e1155"].GOLD()],
        [lending_id, lending_id + 1, lending_id + 2],
        {"from": A.lender},
    )


def test_e721_e721b_e1155_e1155b(A, setup):
    token_id = 1
    lend_amount = 1
    max_rent_duration = 1
    daily_rent_price = 1

    lending_id = 1

    setup["registry"].lend(
        [
            NFTStandard.E721.value,
            NFTStandard.E721.value,
            NFTStandard.E1155.value,
            NFTStandard.E1155.value,
        ],
        [
            setup["e721"].address,
            setup["e721b"].address,
            setup["e1155"].address,
            setup["e1155b"].address,
        ],
        [token_id, token_id, setup["e1155"].GOLD(), setup["e1155b"].GOLD()],
        [lend_amount, lend_amount, lend_amount, lend_amount],
        [max_rent_duration, max_rent_duration, max_rent_duration, max_rent_duration],
        [daily_rent_price, daily_rent_price, daily_rent_price, daily_rent_price],
        [
            PaymentToken.DAI.value,
            PaymentToken.DAI.value,
            PaymentToken.DAI.value,
            PaymentToken.DAI.value,
        ],
        {"from": A.lender},
    )

    setup["registry"].stopLend(
        [
            NFTStandard.E721.value,
            NFTStandard.E721.value,
            NFTStandard.E1155.value,
            NFTStandard.E1155.value,
        ],
        [
            setup["e721"].address,
            setup["e721b"].address,
            setup["e1155"].address,
            setup["e1155b"].address,
        ],
        [token_id, token_id, setup["e1155"].GOLD(), setup["e1155b"].GOLD()],
        [lending_id, lending_id + 1, lending_id + 2, lending_id + 3],
        {"from": A.lender},
    )
