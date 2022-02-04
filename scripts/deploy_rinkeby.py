# pylint: disable=redefined-outer-name,invalid-name,no-name-in-module,unused-argument,too-few-public-methods,too-many-arguments,too-many-locals
# type: ignore
from enum import Enum

from brownie import (
    Resolver,
    ReNFT,
    E721,
    E1155,
    accounts,
)


class PaymentToken(Enum):
    SENTINEL = 0
    DAI = 1
    USDC = 2


RINKEBY_DAI = "0xc7ad46e0b8a400bb3c915120d284aafba8fc4735" # 18 DP
RINKEBY_USDC = "0x4dbcdf9b62e891a7cec5a2568c3f4faf9e8abe2b" # 6 DP


def main():

    a = accounts.load("renft-test-1")
    beneficiary, admin = a, a

    from_a = {"from": a}

    resolver = Resolver.deploy(a, from_a)

    resolver.setPaymentToken(PaymentToken.DAI.value, RINKEBY_DAI)
    resolver.setPaymentToken(PaymentToken.USDC.value, RINKEBY_USDC)

    renft = ReNFT.deploy(resolver, beneficiary, admin, from_a)

    e721 = E721.deploy(from_a)
    e721b = E721.deploy(from_a)
    e1155 = E1155.deploy(from_a)
    e1155b = E1155.deploy(from_a)

    E721.publish_source(e721)
    # E721.publish_source(e721b)
    E1155.publish_source(e1155)
    # E1155.publish_source(e1155b)

    Resolver.publish_source(resolver)
    ReNFT.publish_source(renft)

#   Resolver deployed at: 0x5713a9cCdB31fBa207Fc4Fac7ee398eab3ecB3A6
#   ReNFT deployed at: 0x8e03432370a4a82DE1D2e2A64E3Cf8987B7D1215
#   E721 deployed at: 0xdb413009EE84CB51984Bc208890475923f00c715
#   E721 deployed at: 0xfb8C7c258FD06e3230F68F0ca494f3C07Bc48E7f
#   E1155 deployed at: 0xcD9feBe3bbEEe7138B9Fa7CD0ae66c5dd6872B3b
#   E1155 deployed at: 0x575c6ed5bC2B688C748DE20D4620A3528b78B270
