from brownie import Resolver, Registry, E721, E721B, E1155, E1155B, accounts


def main():

    a = accounts[0]
    from_a = {"from": a}

    resolver = Resolver.deploy(a, from_a)

    registry = Registry.deploy(resolver.address, from_a)

    e721 = E721.deploy(from_a)
    e721b = E721B.deploy(from_a)
    e1155 = E1155.deploy(from_a)
    e1155b = E1155B.deploy(from_a)
