var GiftCards = artifacts.require("./GiftCards.sol");

module.exports = function(deployer, network, accounts) {
  // TODO: replace dummy addresses
  const addressOwner = accounts[0];
  const addressDAI = accounts[9];
  deployer.deploy(GiftCards, addressOwner, addressDAI);
};
