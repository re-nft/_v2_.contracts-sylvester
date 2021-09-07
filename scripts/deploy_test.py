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
    e721b = E721B.deploy(from_a)
    e1155 = E1155.deploy(from_a)
    e1155b = E1155B.deploy(from_a)

    e721.setApprovalForAll(registry.address, True, {"from": accounts[0]})
    e721.setApprovalForAll(registry.address, True, {"from": accounts[1]})
    e721b.setApprovalForAll(registry.address, True, {"from": accounts[0]})
    e721.setApprovalForAll(registry.address, True, {"from": accounts[1]})
    e1155.setApprovalForAll(registry.address, True, {"from": accounts[0]})
    e721.setApprovalForAll(registry.address, True, {"from": accounts[1]})
    e1155b.setApprovalForAll(registry.address, True, {"from": accounts[0]})
    e721.setApprovalForAll(registry.address, True, {"from": accounts[1]})

    dai.approve(registry.address, 1_000_000e18, from_a)
    usdc.approve(registry.address, 1_000_000e18, from_a)
    tusd.approve(registry.address, 1_000_000e18, from_a)

    # test lending
    token_id_e721_1 = 1
    token_id_e721_2 = 2

    lending_id_1 = 1
    lending_id_2 = 2
    lending_id_3 = 3
    lending_id_4 = 4

    renting_id_1 = 1

    registry.lend(
        [NFTStandard.E721.value],
        [e721.address],
        [token_id_e721_1],
        [1],
        [100],
        [1],
        [PaymentToken.DAI.value],
        from_a,
    )

    registry.stopLend(
        [NFTStandard.E721.value], [e721.address], [token_id_e721_1], [lending_id_1]
    )

    # test lending batch
    registry.lend(
        [NFTStandard.E721.value, NFTStandard.E721.value],
        [e721.address, e721.address],
        [token_id_e721_1, token_id_e721_2],
        [1, 1],
        [100, 100],
        [1, 1],
        [PaymentToken.DAI.value, PaymentToken.USDC.value],
        from_a,
    )

    registry.stopLend(
        [NFTStandard.E721.value, NFTStandard.E721.value],
        [e721.address, e721.address],
        [token_id_e721_1, token_id_e721_2],
        [lending_id_2, lending_id_3],
    )

    # test renting
    e721.transferFrom(accounts[0], accounts[1], token_id_e721_1, {"from": accounts[0]})

    registry.lend(
        [NFTStandard.E721.value],
        [e721.address],
        [token_id_e721_1],
        [1],
        [100],
        [1],
        [PaymentToken.DAI.value],
        {"from": accounts[1]},
    )

    # IRegistry.NFTStandard[] memory nftStandard,
    # address[] memory nftAddress,
    # uint256[] memory tokenID,
    # uint256[] memory _lendingID,
    # uint8[] memory rentDuration,
    # uint256[] memory rentAmount
    registry.rent(
        [NFTStandard.E721.value],
        [e721.address],
        [token_id_e721_1],
        [lending_id_4],
        [1],
        [1],
        from_a,
    )

    chain.sleep(10)
    chain.mine()

    # IRegistry.NFTStandard[] memory nftStandard,
    # address[] memory nftAddress,
    # uint256[] memory tokenID,
    # uint256[] memory _lendingID,
    # uint256[] memory _rentingID
    registry.stopRent(
        [NFTStandard.E721.value],
        [e721.address],
        [token_id_e721_1],
        [lending_id_4],
        [renting_id_1],
        from_a,
    )
