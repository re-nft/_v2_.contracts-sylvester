# pylint: disable=redefined-outer-name,invalid-name,no-name-in-module,unused-argument,too-few-public-methods,too-many-arguments,too-many-locals
# type: ignore
from brownie import Resolver, Registry, accounts


def main():

    a = accounts.load("renft-deployer")

    from_a = {"from": a}

    # ! if you have previously deployed a resolver
    # ! just paste the address here
    resolver_addr = "0xf8834327e7f3f5103954e477a32dc742a6518a9c"
    resolver = Resolver.at(resolver_addr)
    # resolver = Resolver.deploy(a, from_a)

    # weth = "0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6" # 18 dp
    # dai  = "0x9D233A907E065855D2A9c7d4B552ea27fB2E5a36" # 18 dp

    # resolver.setPaymentToken(1, weth)
    # resolver.setPaymentToken(2, dai)

    # beneficiary = "0x000000045232fe75A3C7db3e5B03B0Ab6166F425"

    # registry = Registry.deploy(
    #     resolver.address,
    #     beneficiary,
    #     a.address,
    #     from_a
    # )
    registry_addr = "0xede9a15388ccd972dffbd7c3f5504345703b63b2"
    registry = Registry.at(registry_addr)

    # publishing source
    Resolver.publish_source(resolver)
    Registry.publish_source(registry) 

    # goerli resolver: 0xf8834327e7f3f5103954e477a32dc742a6518a9c
    # goerli registry: 0xede9a15388ccd972dffbd7c3f5504345703b63b2

# this is the source code of Resolver that we used to deploy on Goerli
# purpose of this was to be able to easily swap out different payment
# tokens in real time on the goerli testnet
# contract Resolver is IResolver {
#     address private admin;
#     mapping(uint8 => address) private addresses;

#     constructor(address _admin) {
#         admin = _admin;
#     }

#     function getPaymentToken(uint8 _pt)
#         external
#         view
#         override
#         returns (address)
#     {
#         return addresses[_pt];
#     }

#     function setPaymentToken(uint8 _pt, address _v) external override {
#         require(_pt != 0, "ReNFT::cant set sentinel");
#         // TODO: just for goerli deploy
#         // require(
#         //     addresses[_pt] == address(0),
#         //     "ReNFT::cannot reset the address"
#         // );
#         require(msg.sender == admin, "ReNFT::only admin");
#         addresses[_pt] = _v;
#     }
# }