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

# Transaction sent: 0xd76529ddd8206603cf7cc1225e9d73cdcab026c6c3cdb0d04ab3b1dfdefe03c4
#   Gas price: 2.442239021 gwei   Gas limit: 239322   Nonce: 53
#   Resolver.constructor confirmed   Block: 11915033   Gas used: 217566 (90.91%)
#   Resolver deployed at: 0x907B454E33edc407194d5b5ea84c1f1122907adF

# Transaction sent: 0x35de79fcc074a8f105c7d16349728bbe85ee39d52153b617fa7fb8e65fc3493e
#   Gas price: 2.442239021 gwei   Gas limit: 51188   Nonce: 54
#   Resolver.setPaymentToken confirmed   Block: 11915035   Gas used: 46535 (90.91%)

# Transaction sent: 0x9ef4a4dbf321b3b3542a60c85ce5a6e5c41cd36e3917b4dcb87a3a4b4c5a78c9
#   Gas price: 2.440485869 gwei   Gas limit: 51188   Nonce: 55
#   Resolver.setPaymentToken confirmed   Block: 11915036   Gas used: 46535 (90.91%)

# Transaction sent: 0x5fe30797e6a5b8e91f8be724e77e038c221446865e394d929fae9bea6c896a2f
#   Gas price: 2.438604132 gwei   Gas limit: 4130151   Nonce: 56
#   ReNFT.constructor confirmed   Block: 11915037   Gas used: 3754683 (90.91%)
#   ReNFT deployed at: 0x1A465AB83EEC6C06C8DE8dAd2684E54ffbc2E355

# Transaction sent: 0x889ec19cc8cb091e4962ace475cf5251de79159b5f71cbadcf600cea7cc89fdf
#   Gas price: 2.437672517 gwei   Gas limit: 1720193   Nonce: 57
#   E721.constructor confirmed   Block: 11915038   Gas used: 1563812 (90.91%)
#   E721 deployed at: 0x676E65596E04F340d52aFbf8b63b73750AA30D9e

# Transaction sent: 0xa39f6bbe8032e21dc7d8d655a6156b77c9acd941fa2f198191e68c2aed8c6581
#   Gas price: 2.437672517 gwei   Gas limit: 1720193   Nonce: 58
#   E721.constructor confirmed   Block: 11915039   Gas used: 1563812 (90.91%)
#   E721 deployed at: 0x0191EB1Ddd9D08F9988E4ef2dbdb7D8E025063Da

# Transaction sent: 0x80b530a8e75f45201f8091a70bb25f8ade648bc67f3bd3e100b0f8609f42f84c
#   Gas price: 2.440472814 gwei   Gas limit: 1440366   Nonce: 59
#   E1155.constructor confirmed   Block: 11915040   Gas used: 1309424 (90.91%)
#   E1155 deployed at: 0xdFf567aF26EeAE50E2272ED2dFca7C4C4f22ce4E

# Transaction sent: 0xce494f8b02ffa27523977e8c6e7de12efbb755b0a8f911a9c5b974588a7dd87e
#   Gas price: 2.440472814 gwei   Gas limit: 1440366   Nonce: 60
#   E1155.constructor confirmed   Block: 11915041   Gas used: 1309424 (90.91%)
#   E1155 deployed at: 0x98175a675F3E249dB493E3b2c6068B98d62BB1D1