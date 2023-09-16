require("dotenv").config()
require("@nomicfoundation/hardhat-toolbox");
//import '@nomiclabs/hardhat-waffle'
import '@nomiclabs/hardhat-ethers'

// 你的Alchemy  Goerli网络配置
const { ALCHEMY_GOERLI_API_URL, ALCHEMY_GOERLI_PRIVATE_KEY } = process.env;
// 你的Alchemy  main 网络配置
const { ALCHEMY_MAINNET_API_URL, ALCHEMY_MAINNET_PRIVATE_KEY } = process.env;
// 本地测试网络配置
const { LOCAL_API_URL, LOCAL_PRIVATE_KEY  } = process.env;
module.exports = { 
  solidity: {
    version: "0.8.9",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  defaultNetwork: "localhost",   //选择默认网络
  networks: {
    goerli: {
      url: ALCHEMY_GOERLI_API_URL,
      accounts: [ALCHEMY_GOERLI_PRIVATE_KEY]
    },
    mainnet: {
      url: ALCHEMY_MAINNET_API_URL,
      accounts: [ALCHEMY_MAINNET_PRIVATE_KEY]
    },
    localhost: {
      url: LOCAL_API_URL,
      accounts: [LOCAL_PRIVATE_KEY]
    },
  }, 
  etherscan: {
    apiKey: {
      goerli: process.env.ETHERSCAN_API_KEY
    }
  },
  gasReporter: {
    currency: 'RMB',
    gasPrice: 21,
    enabled: (process.env.REPORT_GAS) ? true : false
  }
};