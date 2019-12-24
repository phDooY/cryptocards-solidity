const path = require("path");
var HDWalletProvider = require("truffle-hdwallet-provider");
require('dotenv').config()

// `MNEMONIC` and `ENDPOINT` are defined in environment variables
const mnemonic = process.env.MNEMONIC
const endpoint = process.env.ENDPOINT

module.exports = {
  // See <http://truffleframework.com/docs/advanced/configuration>
  // to customize your Truffle configuration!
  // contracts_build_directory: path.join(__dirname, "client/src/contracts"),
  compilers: {
    solc: {
      version: "^0.6.0",
    }
  },
  contracts_build_directory: path.join(__dirname, "build/contracts"),
  networks: {
    develop: {
      host: "127.0.0.1", // localhost
      port: 8545,
      network_id: "*" // match any network id
    },
    ropsten: {
      provider: function() {
          return new HDWalletProvider(mnemonic, endpoint)
      },
      network_id: 3
    },
    mainnet: {
      provider: function() {
          return new HDWalletProvider(mnemonic, endpoint)
      },
      gas: 6000000,
      network_id: 1
    }
  }
};
