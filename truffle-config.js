const path = require("path");
var HDWalletProvider = require("truffle-hdwallet-provider");

// `mnemonic` and `endpoint` are defined in env.js
const env = require("./env.js")

module.exports = {
  // See <http://truffleframework.com/docs/advanced/configuration>
  // to customize your Truffle configuration!
  // contracts_build_directory: path.join(__dirname, "client/src/contracts"),
  contracts_build_directory: path.join(__dirname, "build/contracts"),
  networks: {
    develop: {
      host: "127.0.0.1", // localhost
      port: 8545,
      network_id: "*" // match any network id
    },
    ropsten: {
        provider: function() {
            return new HDWalletProvider(env.mnemonic, env.endpoint)
        },
        network_id: 3
    }
  }
};
