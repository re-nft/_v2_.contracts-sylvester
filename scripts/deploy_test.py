# pylint: disable=redefined-outer-name,invalid-name,no-name-in-module,unused-argument,too-few-public-methods,too-many-arguments,too-many-locals
# type: ignore
from enum import Enum

from brownie import (
    Resolver,
    Registry,
    E721,
    E1155,
    DAI,
    USDC,
    TUSD,
    accounts,
    chain,
)


class NFTStandard(Enum):
    E721 = 0
    E1155 = 1


class PaymentToken(Enum):
    SENTINEL = 0
    DAI = 1
    USDC = 2
    TUSD = 3


def main():

    a = accounts[0]
    beneficiary = accounts[1]
    admin = accounts[0]

    from_a = {"from": a}

    resolver = Resolver.deploy(a, from_a)

    dai = DAI.deploy(from_a)
    usdc = USDC.deploy(from_a)
    tusd = TUSD.deploy(from_a)

    resolver.setPaymentToken(PaymentToken.DAI.value, dai.address)
    resolver.setPaymentToken(PaymentToken.USDC.value, usdc.address)
    resolver.setPaymentToken(PaymentToken.TUSD.value, tusd.address)

    registry = Registry.deploy(
        resolver.address, beneficiary.address, admin.address, from_a
    )

    e721 = E721.deploy(from_a)
    e721b = E721.deploy(from_a)
    e1155 = E1155.deploy(from_a)
    e1155b = E1155.deploy(from_a)
