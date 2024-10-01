require("dotenv").config();

import { HardhatUserConfig } from "hardhat/config";
import "hardhat-deploy";
import "@nomicfoundation/hardhat-toolbox";

const SEPOLIA_CHAIN_ID = 11155111;
const SEPOLIA_PRIVATE_KEY = process.env.SEPOLIA_PRIVATE_KEY;
const ETHER_SCAN_API_KEY = process.env.ETHER_SCAN_API_KEY;
const SEPOLIA_RPC_URL = process.env.SEPOLIA_RPC_URL;
const COIN_MARKET_CAP_API_KEY = process.env.COIN_MARKET_CAP_API_KEY;

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.27",
    settings: {
      optimizer: {
        enabled: true,
        runs: 100,
      },
      viaIR: true,
    },
  },

  defaultNetwork: "hardhat",

  networks: {
    sepolia: {
      url: SEPOLIA_RPC_URL,
      chainId: SEPOLIA_CHAIN_ID,
      accounts: [SEPOLIA_PRIVATE_KEY || ""],
    },
  },

  namedAccounts: {
    deployer: {
      default: 0,
    },
  },

  etherscan: {
    apiKey: ETHER_SCAN_API_KEY,
  },

  gasReporter: {
    coinmarketcap: COIN_MARKET_CAP_API_KEY,
    outputFile: "gas_report.txt",
    enabled: true,
    token: "ETH",
    currency: "USD",
    noColors: true,
  },
};

export default config;
