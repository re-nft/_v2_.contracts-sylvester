# pylint: disable=redefined-outer-name,invalid-name,no-name-in-module,unused-argument,too-few-public-methods,too-many-arguments,too-many-locals
# type: ignore
from enum import Enum

from brownie import (
    Resolver,
    ReNFT,
    accounts,
)


class PaymentToken(Enum):
    SENTINEL = 0
    DAI = 1
    USDC = 2


    # constructor(
    #     address _resolver,
    #     address payable _beneficiary,
    #     address _admin
    # ) {
    #     ensureIsNotZeroAddr(_resolver);
    #     ensureIsNotZeroAddr(_beneficiary);
    #     ensureIsNotZeroAddr(_admin);
    #     resolver = IResolver(_resolver);
    #     beneficiary = _beneficiary;
    #     admin = _admin;
    # }

ROPSTEN_DAI = "0xad6d458402f60fd3bd25163575031acdce07538d" # 18 DP
ROPSTEN_USDC = "0x07865c6e87b9f70255377e024ace6630c1eaa37f" # 6 DP


def main():

    a = accounts.load("<account name>")
    beneficiary, admin = a, a

    from_a = {"from": a}

    resolver = Resolver.deploy(a, from_a)

    resolver.setPaymentToken(PaymentToken.DAI.value, ROPSTEN_DAI)
    resolver.setPaymentToken(PaymentToken.USDC.value, ROPSTEN_USDC)
    resolver.setPaymentToken(PaymentToken.TUSD.value, ROPSTEN_TUSD)

    renft = ReNFT.deploy(resolver, beneficiary, admin, from_a)

    e721 = E721.deploy(from_a)

    breakpoint()

    e721b = E721.deploy(from_a)
    e1155 = E1155.deploy(from_a)
    e1155b = E1155.deploy(from_a)

    Resolver.publish_source(resolver)
    ReNFT.publish_source(renft)
