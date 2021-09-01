# pylint: disable=redefined-outer-name,invalid-name,no-name-in-module,unused-argument,too-few-public-methods,too-many-arguments,too-many-locals
# type: ignore
from brownie import Resolver, Registry, accounts


def main():

    a = accounts[0]
    from_a = {"from": a}

    resolver = Resolver.deploy(a, from_a)

    _ = Registry.deploy(resolver.address, from_a)
