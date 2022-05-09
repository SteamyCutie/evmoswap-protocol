import "dotenv/config";
import "hardhat-deploy";
import "hardhat-deploy-ethers";
import "hardhat-spdx-license-identifier";
import "@nomiclabs/hardhat-etherscan";

const gasPrice = 5*1e9;

module.exports = {
  defaultNetwork: "hardhat",
  namedAccounts: {
    deployer: 0, //the second account
  },
  networks: {
    hardhat: {
      // loggingEnabled: true
    },
    mainnet: {
      live: false,
      chainId: 9001,
      gasPrice: gasPrice,
      // gasLimit: 3000000,
      url: process.env.RPC_MAINNET_URL,
      accounts: process.env.MAINNET_PRIVATE_KEY ? [`0x${process.env.MAINNET_PRIVATE_KEY}`] : [],
    },
    testnet: {
      live: false,
      chainId: 9000,
      url: process.env.RPC_TESTNET_URL,
      accounts: process.env.TESTNET_PRIVATE_KEY ? [`0x${process.env.TESTNET_PRIVATE_KEY}`] : [],
    },
    bsctest: {
      live: true,
      chainId: 97,
      url: process.env.RPC_BSC_TESTNET,
      accounts: process.env.TESTNET_PRIVATE_KEY ? [`0x${process.env.TESTNET_PRIVATE_KEY}`] : [],
    }
  },
  paths: {
    cache: "./build/cache",
    artifacts: "./build/artifacts",
    deployments: "./build/deployments",
  },
  solidity: {
    compilers: [
      {
        version: "0.4.25",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          }
        }
      },
      {
        version: "0.6.12",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          }
        }
      },
      // Used for Uniswap v2 Periphery
      { 
        version: "0.6.6",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          }
        }
      },
      // Used for (some) OpenZeppelin
      { 
        version: "0.5.16",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          }
        }
      },
      { 
        version: "0.4.19",
        settings: {
          optimizer: {
            enabled: false,
            runs: 200,
          }
        }
      },
    ],
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY ? `${process.env.ETHERSCAN_API_KEY}` : ""
  },
};

