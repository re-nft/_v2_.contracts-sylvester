from brownie import (
    Registry,
    accounts,
)

RINKEBY_RESOLVER_ADDRESS = "0x5713a9cCdB31fBa207Fc4Fac7ee398eab3ecB3A6"

def main():

    a = accounts.load("renft-test-1")
    beneficiary, admin = a, a

    from_a = {"from": a}

    registry = Registry.deploy(
        RINKEBY_RESOLVER_ADDRESS,
        beneficiary,
        admin,
        from_a
    )

    Registry.publish_source(registry)
