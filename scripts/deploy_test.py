from brownie import Resolver, Registry, E721, E721B, E1155, E1155B, DAI, USDC, TUSD, accounts


def main():

    a = accounts[0]
    from_a = {"from": a}

    resolver = Resolver.deploy(a, from_a)

    dai = DAI.deploy(from_a)
    usdc = USDC.deploy(from_a)
    tusd = TUSD.deploy(from_a)

    resolver.setPaymentToken(1, dai.address)
    resolver.setPaymentToken(2, usdc.address)
    resolver.setPaymentToken(3, tusd.address)

    registry = Registry.deploy(resolver.address, from_a)

    e721 = E721.deploy(from_a)
    e721b = E721B.deploy(from_a)
    e1155 = E1155.deploy(from_a)
    e1155b = E1155B.deploy(from_a)
