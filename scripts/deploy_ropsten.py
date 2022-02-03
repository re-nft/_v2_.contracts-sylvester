# pylint: disable=redefined-outer-name,invalid-name,no-name-in-module,unused-argument,too-few-public-methods,too-many-arguments,too-many-locals
# type: ignore
from brownie import (
    Registry,
    accounts,
)

ROPSTEN_RESOLVER_ADDRESS = "0x907B454E33edc407194d5b5ea84c1f1122907adF"

def main():

    a = accounts.load("renft-test-1")
    beneficiary, admin = a, a

    from_a = {"from": a}

    registry = Registry.deploy(
        ROPSTEN_RESOLVER_ADDRESS,
        beneficiary,
        admin,
        from_a
    )

    Registry.publish_source(registry)
