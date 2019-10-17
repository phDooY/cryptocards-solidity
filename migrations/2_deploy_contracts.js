var GiftCards = artifacts.require("./GiftCards.sol");

module.exports = function(deployer, network, accounts) {
  // TODO: replace dummy addresses
  const addressOwner = accounts[0];

  // Ropsten addresses
  const addressDAI = "0xad6d458402f60fd3bd25163575031acdce07538d";
  const kyberNetworkProxyAddress = "0x818E6FECD516Ecc3849DAf6845e3EC868087B755";

  deployer.deploy(GiftCards, addressOwner, addressDAI, kyberNetworkProxyAddress);
};
