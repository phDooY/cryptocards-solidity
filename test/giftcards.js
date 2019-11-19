const GiftCards = artifacts.require("./GiftCards.sol");

// Helpers
const keccak256 = (...inputs) => web3.utils.soliditySha3(...inputs)
const generateSecurityCode = () => web3.utils.randomHex(20)
const hashSecurityCode = code => web3.utils.soliditySha3(web3.utils.padRight(web3.utils.fromAscii(code), 66, { encoding: "hex" }))

contract("GiftCards", async accounts => {

  // Constants (taken from deployment script)
  const addressOwner = accounts[0];
  // Ropsten addresses
  const addressDAI = "0xad6d458402f60fd3bd25163575031acdce07538d";
  const kyberNetworkProxyAddress = "0x818E6FECD516Ecc3849DAf6845e3EC868087B755";

  // const giftCardsInstance = await GiftCards.deployed();

  let giftCardsInstance
  let securityCode, linkHash
  before('Setup new contract instance', async () => {
    giftCardsInstance = await GiftCards.new(
      addressOwner,
      addressDAI,
      kyberNetworkProxyAddress
    );

    // Initialize a linkHash and securityCode that will be used in
    // various tests below:
    // ----------
    linkHash = keccak256('testcard')
    securityCode = generateSecurityCode()
    // ----------
  });


  it("Should return that the card does not exist.", async () => {

    // Check if it exists
    let result = await giftCardsInstance.cardExists(linkHash);

    assert.equal(result, false, "The card somehow exists");
  });


  it("Should create a new card without error.", async () => {

    // Create card
    let securityCodeHash = hashSecurityCode(securityCode) 
    let recipientName = 'Test Recipient'
    let nominalAmount = 10
    let cardStyle = 0
    let buyer = accounts[0]
    // Since nominalAmount is only for show, we can send whatever we
    // want as value during the test
    let initialAmountWei = web3.utils.toWei('0.05')
    await giftCardsInstance.createCard(
      linkHash,
      recipientName,
      securityCodeHash,
      nominalAmount,
      cardStyle,
      { from: buyer, value: initialAmountWei }
    );

    // Get card data from linkHash
    const storedCard = await giftCardsInstance.cards(linkHash);

    // TODO more asserts here for every field of the card struct
    assert.equal(storedCard.recipientName, recipientName, "The stored recipientName is wrong.");
    assert.equal(storedCard.securityCodeHash, securityCodeHash, "The stored securityCodeHash is wrong.");
    assert.equal(storedCard.nominalAmount, nominalAmount, "The stored nominalAmount is wrong.");
    assert.equal(storedCard.cardStyle, cardStyle, "The stored cardStyle is wrong.");
    assert.equal(storedCard.buyer, buyer, "The stored buyer is wrong.");
    assert.equal(storedCard.initialAmountWei, initialAmountWei, "The stored initialAmountWei is wrong.");

    // TODO check for DAI balance on the contract
    // TODO check for ETH balance on the contract (increased by gasActivationFee and service fee)
  });


  it("Should activate the previous card without error.", async () => {

    let recipientAddress = accounts[0]
    // Get balance before activating
    // Assume that it will not change during this test
    let balanceBefore = web3.eth.getBalance(recipientAddress);

    // Activate card
    await giftCardsInstance.activateCard(
      linkHash,
      securityCode,
      recipientAddress
    )

    // Get balance after activation
    let balanceAfter = web3.eth.getBalance(recipientAddress);

    // Get sellAmountWei from card
    const storedCard = await giftCardsInstance.cards(linkHash);
    let sellAmountWei = storedCard.sellAmountWei

    // TODO more and better asserts here
    // assert.notEqual(balanceBefore, balanceAfter, "The recipient's ETH balance did not change after activation.");
    assert.notEqual(balanceBefore+sellAmountWei, balanceAfter, "The recipient's ETH balance is not correct after card activation.");
  });


  it("Should return that the card exists.", async () => {
    let result = await giftCardsInstance.cardExists(linkHash);
    assert.equal(result, true, "The card we just activated somehow does not exist.");
  });


  it("Should return that the card has been activated.", async () => {
    let result = await giftCardsInstance.cardIsActivated(linkHash);
    assert.equal(result, true, "The card we just activated appears not activated.");
  });

});
