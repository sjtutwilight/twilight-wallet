const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("DataTypes Library", function () {
  let DataTypesLib;
  let deployedLib;
  let reserveData;
  let aTokenAddress;
  const SECONDS_PER_YEAR = 365 * 24 * 60 * 60;

  before(async function () {
    // 1. 部署WadRayMath库
    const WadRayMath = await ethers.getContractFactory("WadRayMath");
    const wadRayMath = await WadRayMath.deploy();  // 部署WadRayMath库
    await wadRayMath.deployed();  // 确保库已经部署完成

    // 2. 将WadRayMath库链接到DataTypes合约
    const DataTypesLibFactory = await ethers.getContractFactory("DataTypes", {
      libraries: {
        WadRayMath: wadRayMath.address,  // 链接库的地址
      },
    });

    // 3. 部署DataTypes合约
    deployedLib = await DataTypesLibFactory.deploy();
    await deployedLib.deployed();

    // 设置初始的reserveData对象
    reserveData = {
      liquidityIndex: 0,
      currentLiquidityRate: 0,
      lastUpdateTimestamp: 0,
      aTokenAddress: ethers.constants.AddressZero,
      id: 1,
    };
    aTokenAddress = "0x5FbDB2315678afecb367f032d93F642f64180aa3"; // 模拟的aToken地址
  });

  it("应该正确初始化Reserve", async function () {
    // 模拟调用init函数
    await deployedLib.init(reserveData, aTokenAddress);

    // 校验初始化后的值
    expect(reserveData.liquidityIndex).to.equal(
      ethers.BigNumber.from(10).pow(27)
    ); // 应该等于Ray的值
    expect(reserveData.currentLiquidityRate).to.equal(
      ethers.BigNumber.from(1265).mul(ethers.BigNumber.from(10).pow(21))
    );
    expect(reserveData.aTokenAddress).to.equal(aTokenAddress);
  });

  it("应该正确计算标准化收入", async function () {
    // 初始化Reserve并设置timestamp为过去的时间
    reserveData.lastUpdateTimestamp = Math.floor(Date.now() / 1000) - 1000;
    reserveData.currentLiquidityRate = ethers.BigNumber.from(1265).mul(
      ethers.BigNumber.from(10).pow(21)
    );
    reserveData.liquidityIndex = ethers.BigNumber.from(10).pow(27);

    const nomalizedIncome = await deployedLib.getNomalizedIncome(reserveData);

    expect(nomalizedIncome).to.be.a("BigNumber");
  });

  it("应该正确更新状态", async function () {
    const prevLiquidityIndex = reserveData.liquidityIndex;
    const prevTimestamp = reserveData.lastUpdateTimestamp;

    // 调用updateState并测试
    await deployedLib.updateState(reserveData);

    expect(reserveData.liquidityIndex).to.be.gt(prevLiquidityIndex);
    expect(reserveData.lastUpdateTimestamp).to.be.gt(prevTimestamp);
  });

  it("应该更新流动性利率", async function () {
    const liquidityAdded = ethers.BigNumber.from(1000);
    const liquidityTaken = ethers.BigNumber.from(500);

    // 模拟利率变化
    await deployedLib.updateInterestRates(
      reserveData,
      reserveData.aTokenAddress,
      reserveData.aTokenAddress,
      liquidityAdded,
      liquidityTaken
    );

    expect(reserveData.currentLiquidityRate).to.equal(
      ethers.BigNumber.from(1265).mul(ethers.BigNumber.from(10).pow(21))
    );
  });

  it("应该触发RESERVE_ALREADY_INITIALIZED异常", async function () {
    // 再次初始化时应该触发异常
    await expect(
      deployedLib.init(reserveData, aTokenAddress)
    ).to.be.revertedWith("RESERVE_ALREADY_INITIALIZED");
  });
});
