const { ethers } = require("hardhat");
const hre = require("hardhat");

async function main() {
  // deploey TestToken
  const TestToken = await hre.ethers.getContractFactory("TestToken");
  const TestTokenContract = await TestToken.deploy();

  await TestTokenContract.deployed();

  // deploy DEX token
  const DEXToken = await hre.ethers.getContractFactory("DEXToken");
  const DEXTokenContract = await DEXToken.deploy();

  await DEXTokenContract.deployed();

  // deploy Syrup token
  const Syrup = await hre.ethers.getContractFactory("Syrup");
  const SyrupContract = await Syrup.deploy(DEXTokenContract.address);

  await SyrupContract.deployed();

  // deploy master
  const DEXMasterChef = await hre.ethers.getContractFactory("DEXMasterChef");
  const DEXMasterChefContract = await DEXMasterChef.deploy(
    DEXTokenContract.address,
    SyrupContract.address,
    ethers.utils.parseEther("40"),
    Date.now()
  );

  await DEXMasterChefContract.deployed();
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
