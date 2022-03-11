const { ethers } = require("hardhat");

const provider = new ethers.providers.JsonRpcProvider("http://127.0.0.1:7545");

describe("Let Deploy and Stake and get some Rewards :D", async function () {
  it("Test", async () => {
    let poolLength;
    let OwnerDEXBalance;
    let OwnerSyrupBalance;
    const [owner] = await ethers.getSigners();

    // deploey TestToken
    const TestToken = await ethers.getContractFactory("TestToken");
    const TestTokenContract = await TestToken.deploy();
    await TestTokenContract.deployed();

    console.log("TestTokenContract deployed to:", TestTokenContract.address);

    // deploy DEX token
    const DEXToken = await ethers.getContractFactory("DEXToken");
    const DEXTokenContract = await DEXToken.deploy();
    await DEXTokenContract.deployed();

    console.log("DEXTokenContract deployed to:", DEXTokenContract.address);

    // mint DEX to owner
    const mintDEXTX = await DEXTokenContract.mint(owner.address, 1000);
    await mintDEXTX.wait();
    OwnerDEXBalance = await DEXTokenContract.balanceOf(owner.address);
    console.log("Owner Balance For DEX Token", OwnerDEXBalance.toString());

    // deploy Syrup token
    const Syrup = await ethers.getContractFactory("Syrup");
    const SyrupContract = await Syrup.deploy(DEXTokenContract.address);
    await SyrupContract.deployed();

    console.log("SyrupContract deployed to:", SyrupContract.address);

    // deploy master
    const DEXMasterChef = await ethers.getContractFactory("DEXMasterChef");
    const DEXMasterChefContract = await DEXMasterChef.deploy(
      DEXTokenContract.address,
      SyrupContract.address,
      ethers.utils.parseEther("1000"),
      Date.now()
    );
    await DEXMasterChefContract.deployed();

    console.log(
      "DEXMasterChefContract deployed to:",
      DEXMasterChefContract.address
    );

    // mint TestToken to Master
    const TestMintTX = await TestTokenContract.mint(
      DEXMasterChefContract.address,
      1000
    );
    await TestMintTX.wait();
    const MasterTokenBalance = await TestTokenContract.balanceOf(
      DEXMasterChefContract.address
    );
    console.log(
      "DEXMasterChefContract Balance For Test Token",
      MasterTokenBalance.toString()
    );

    // get poolLength
    poolLength = await DEXMasterChefContract.poolLength();
    console.log(poolLength.toString());

    // add Test Token pool
    const addDAIPoolTX = await DEXMasterChefContract.add(
      1000,
      TestTokenContract.address,
      false
    );
    await addDAIPoolTX.wait();

    // get poolLength
    poolLength = await DEXMasterChefContract.poolLength();
    console.log(poolLength.toString());

    // information of test token pool
    const TestTokenPoolInfo = await DEXMasterChefContract.poolInfo(1);
    console.log(TestTokenPoolInfo[0].toString());
    console.log(TestTokenPoolInfo[1].toString());
    console.log(TestTokenPoolInfo[2].toString());

    // get master DEX balance before stake
    OwnerDEXBalance = await DEXTokenContract.balanceOf(
      DEXMasterChefContract.address
    );
    console.log(
      "DEXMasterChefContract Balance For DEX Token Before Stake",
      OwnerDEXBalance.toString()
    );

    // get owner Syrup balance after stake
    OwnerSyrupBalance = await SyrupContract.balanceOf(owner.address);
    console.log(
      "Owner Balance For Syrup Token Before Stake",
      OwnerSyrupBalance.toString()
    );

    // stake DEX token to master
    await DEXTokenContract.approve(DEXMasterChefContract.address, 500);
    const DEXStakeTX = await DEXMasterChefContract.enterStaking(500);
    await DEXStakeTX.wait();

    // get master DEX balance after stake
    OwnerDEXBalance = await DEXTokenContract.balanceOf(
      DEXMasterChefContract.address
    );
    console.log(
      "DEXMasterChefContract Balance For DEX Token After Stake",
      OwnerDEXBalance.toString()
    );

    // get owner DEX balance after stake
    OwnerDEXBalance = await DEXTokenContract.balanceOf(owner.address);
    console.log(
      "Owner Balance For DEX Token After Stake",
      OwnerDEXBalance.toString()
    );

    // get owner Syrup balance after stake
    OwnerSyrupBalance = await SyrupContract.balanceOf(owner.address);
    console.log(
      "Owner Balance For Syrup Token After Stake",
      OwnerSyrupBalance.toString()
    );

    // mine some blocks
    console.log(await provider.getBlockNumber());
    await provider.send("evm_mine");
    await provider.send("evm_mine");
    await provider.send("evm_mine");
    await provider.send("evm_mine");
    await provider.send("evm_mine");
    console.log(await provider.getBlockNumber());

    // leave stake
    const leaveStakingTX = await DEXMasterChefContract.leaveStaking(
      OwnerSyrupBalance
    );
    await leaveStakingTX.wait();

    // get master DEX balance after leave stake
    OwnerDEXBalance = await DEXTokenContract.balanceOf(
      DEXMasterChefContract.address
    );
    console.log(
      "DEXMasterChefContract Balance For DEX Token After leave stake",
      OwnerDEXBalance.toString()
    );

    // get owner DEX balance after leave stake
    OwnerDEXBalance = await DEXTokenContract.balanceOf(owner.address);
    console.log(
      "Owner Balance For DEX Token After leave stake",
      OwnerDEXBalance.toString()
    );

    // get owner Syrup balance after leave stake
    OwnerSyrupBalance = await SyrupContract.balanceOf(owner.address);
    console.log(
      "Owner Balance For Syrup Token After leave stake",
      OwnerSyrupBalance.toString()
    );
  });
});
