require("@nomicfoundation/hardhat-toolbox");
//require("@nomiclabs/hardhat-ethers");
require("dotenv").config();  // Load .env file
require("@nomicfoundation/hardhat-foundry");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  
    solidity: {
      version: "0.8.21", // Ensure it's 0.8.21
      settings: {
        optimizer: {
          enabled: true,  // Make sure optimizer is enabled if required
          runs: 200
        }
      }
    },
  
  networks: {
    hardhat: {
        chainId: 1337,
    },
 
    // sepolia: {
    //   url: process.env.SEPOLIA_INFURA_KEY,
    //   accounts: [process.env.PRIVATE_KEY]
    // }
},
};
