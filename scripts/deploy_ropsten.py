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


ROPSTEN_DAI = "0xad6d458402f60fd3bd25163575031acdce07538d" # 18 DP
ROPSTEN_USDC = "0x07865c6e87b9f70255377e024ace6630c1eaa37f" # 6 DP


def main():

    a = accounts.load("renft-test-1")
    beneficiary, admin = a, a

    from_a = {"from": a}

    resolver = Resolver.deploy(a, from_a)

    resolver.setPaymentToken(PaymentToken.DAI.value, ROPSTEN_DAI)
    resolver.setPaymentToken(PaymentToken.USDC.value, ROPSTEN_USDC)

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

#   Resolver deployed at: 0x907B454E33edc407194d5b5ea84c1f1122907adF
#   ReNFT deployed at: 0x1A465AB83EEC6C06C8DE8dAd2684E54ffbc2E355
#   E721 deployed at: 0x676E65596E04F340d52aFbf8b63b73750AA30D9e
#   E721 deployed at: 0x0191EB1Ddd9D08F9988E4ef2dbdb7D8E025063Da
#   E1155 deployed at: 0xdFf567aF26EeAE50E2272ED2dFca7C4C4f22ce4E
#   E1155 deployed at: 0x98175a675F3E249dB493E3b2c6068B98d62BB1D1
