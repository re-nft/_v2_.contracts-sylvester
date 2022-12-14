# pylint: disable=redefined-outer-name,invalid-name,no-name-in-module,unused-argument,too-few-public-methods,too-many-arguments,too-many-locals
# type: ignore
from brownie import Resolver, Registry, accounts


def main():

    a = accounts.load("renft-deployer")
    from_a = {"from": a}

    # ! if you have previously deployed a resolver
    # ! just paste the address here
    # resolver = "0x945e589a4715d1915e6fe14f08e4887bc4019341"
    resolver = Resolver.deploy(a, from_a)

    weth = "0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619" # 18 dp
    dai  = "0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063" # 18 dp
    usdc = "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174" # 6 dp
    usdt = "0xc2132D05D31c914a87C6611C10748AEb04B58e8F" # 6 dp
    tusd = "0x2e1AD108fF1D8C782fcBbB89AAd783aC49586756" # 18 dp

    resolver.setPaymentToken(1, weth)
    resolver.setPaymentToken(2, dai)
    resolver.setPaymentToken(3, usdc)
    resolver.setPaymentToken(4, usdt)
    resolver.setPaymentToken(5, tusd)

    # ! beenficiary on polygon is the deployer
    beneficiary = "0x000000045232fe75A3C7db3e5B03B0Ab6166F425"

    _ = Registry.deploy(
        resolver.address,
        beneficiary,
        a.address,
        from_a
    )