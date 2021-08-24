from brownie import Resolver, Registry, accounts


def main():

    a = accounts[0]
    from_a = {"from": a}

    resolver = Resolver.deploy(a, from_a)

    registry = Registry.deploy(resolver.address, from_a)
