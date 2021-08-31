from brownie import (
    Resolver,
    Registry,
    E721,
    E721B,
    E1155,
    E1155B,
    DAI,
    USDC,
    TUSD,
    accounts,
)

from enum import Enum


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

    registry = Registry.deploy(resolver.address, beneficiary.address, admin.address, from_a)

    e721 = E721.deploy(from_a)
    e721b = E721B.deploy(from_a)
    e1155 = E1155.deploy(from_a)
    e1155b = E1155B.deploy(from_a)

    e721.setApprovalForAll(registry.address, True)
    e721b.setApprovalForAll(registry.address, True)
    e1155.setApprovalForAll(registry.address, True)
    e1155b.setApprovalForAll(registry.address, True)

    # test lending batch
    token_id_e721 = 1
    lending_id = 1

    registry.lend(
        [NFTStandard.E721.value],
        [e721.address],
        [token_id_e721],
        [1],
        [100],
        [1],
        [PaymentToken.DAI.value],
        from_a,
    )

    registry.stopLend([e721.address], [token_id_e721], [lending_id])

    # # test lending batch
    # registry.lend(
    #     [NFTStandard.E721.value, NFTStandard.E721.value],
    #     [e721.address, e721.address],
    #     [1, 2],
    #     [1, 1],
    #     [100, 100],
    #     [1, 1],
    #     [PaymentToken.DAI.value, PaymentToken.USDC.value],
    #     from_a,
    # )

    # registry.stopLend([1, 2])
