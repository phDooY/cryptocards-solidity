const GiftCards = artifacts.require("./GiftCards.sol");

// Addresses of external contracts (DAI, Kyber) needed in order to deploy our
// GiftCards contract on Ropsten and Mainnet.
const ADDRESSES = {
  // >>> Main net
  1: {
    addressDAI: "0x6b175474e89094c44da98b954eedeac495271d0f",
    addressKyberNetworkProxy: "0x818E6FECD516Ecc3849DAf6845e3EC868087B755"
  },
  // >>> Ropsten
  3: {
    addressDAI: "0xad6d458402f60fd3bd25163575031acdce07538d",
    addressKyberNetworkProxy: "0x818E6FECD516Ecc3849DAf6845e3EC868087B755"
  }
}

module.exports = function(deployer, network, accounts) {
  // Get external contract addresses automatically according to
  // We use `deployer.network_id` instead of `network ` (network name) since
  // truffle also deploys to fork networks (e.g. "mainnet-fork") which have the
  // same network id as the original network but different network name
  let { addressDAI, addressKyberNetworkProxy } = ADDRESSES[deployer.network_id];

  const addressOwner = accounts[0];
  const addressMaintainer = "0xbd2912fe2b99f137867da4e8513fbb9fc6470698";

  deployer.deploy(GiftCards, addressOwner, addressMaintainer, addressDAI, addressKyberNetworkProxy);
};
