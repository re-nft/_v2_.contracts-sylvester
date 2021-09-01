#pylint: disable=redefined-outer-name,invalid-name,no-name-in-module,unused-argument,too-few-public-methods,too-many-arguments
#type: ignore
from decimal import Decimal

import pytest
from brownie import DAI, TUSD, USDC, E721, E721B, E1155, E1155B, Resolver, Registry, accounts
from brownie.network.state import Chain

chain = Chain()

THOUSAND = Decimal("1000e18")
MAX = Decimal("5e76")
ONE_WEEK = 24 * 60 * 60 * 7
EPSILON = Decimal("0.0001")


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
def registry(A):
    return Registry.deploy({"from": A.deployer})


@pytest.fixture(scope="module")
def lp(A):
    return E20.deploy({"from": A.DEPLOYER})


@pytest.fixture(scope="module")
def setup(lp, A, rent, liquidity_mining):
    rent.sendToLiquidityMining(liquidity_mining.address, {"from": A.DEPLOYER})

    # lp tokens represent uni v2 lp erc20 tokens
    lp.mint(A.NV, THOUSAND, {"from": A.DEPLOYER})
    lp.mint(A.ER, THOUSAND, {"from": A.DEPLOYER})
    lp.mint(A.EN, THOUSAND, {"from": A.DEPLOYER})
    lp.mint(A.LU, THOUSAND, {"from": A.DEPLOYER})

    lp.approve(liquidity_mining.address, MAX, {"from": A.NV})
    lp.approve(liquidity_mining.address, MAX, {"from": A.ER})
    lp.approve(liquidity_mining.address, MAX, {"from": A.EN})
    lp.approve(liquidity_mining.address, MAX, {"from": A.LU})
