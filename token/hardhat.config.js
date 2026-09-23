require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();

const { PRIVATE_KEY, SEPOLIA_RPC_URL, BASE_SEPOLIA_RPC_URL, ETHERSCAN_API_KEY } = process.env;
const accounts = PRIVATE_KEY ? [PRIVATE_KEY] : [];

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: "0.8.24",
    settings: { optimizer: { enabled: true, runs: 200 } },
  },
  networks: {
    sepolia: { url: SEPOLIA_RPC_URL || "", accounts },
    baseSepolia: { url: BASE_SEPOLIA_RPC_URL || "https://sepolia.base.org", accounts },
  },
  etherscan: { apiKey: ETHERSCAN_API_KEY || "" },
};
