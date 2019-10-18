# Development

1. Install `truffle`.
2. Run `git clone https://github.com/phDooY/cryptocards-solidity && cd cryptocards-solidity`
3. Run `truffle develop`.

   Alternatively, run `ganache-cli` and use `truffle console --network develop` to open the console.
   The `develop` network is preconfigured to use the default host and port used by Ganache.
4. Inside the console, run `compile` to compile the contracts.
5. Run `migrate` to deploy the contracts to the truffle blockchain.

   Note: It is highly recommended to use `migrate --reset` instead of just `migrate` after making changes to the contracts.
6. Use the cheatsheet below to interact with the contracts.

# Truffle console cheatsheet

Get accounts array and a reference to the deployed contract.

```javascript
a = await web3.eth.getAccounts()
c = await GiftCards.deployed()
```

Example calls:

```javascript
// Call a function. Caller is account 0 by default.
await c.addMaintainer(a[0])
// Call payable function from account 3. Value is in wei.
await c.createCard("some hash", "eleni", "security code hash", {from: a[0], value: 200000000000000000})
// Get card data
d = await c.cards("some hash")
// Activate card
await c.activateCard("some hash", "security code hash", '0x90F63E26982DF91Af836FA3339791a2b2A3452F8')
```


# Useful resources

Exchange wrappers:
https://github.com/DecenterApps/cdpsaver-contracts/tree/9fdc6b2fc100a1b5df676840f8e2d748354f23bc/contracts/exchange/wrappers