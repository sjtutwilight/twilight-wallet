const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("AToken Contract (ethers.js v6)", function () {
  let aToken, mockERC20, lendingPool;
  let owner, user, receiver;
  const index = BigInt(10 ** 27); // 初始流动性指数

  before(async function () {
    [owner, user, receiver] = await ethers.getSigners();

    // 部署MockERC20代币合约
    const MockERC20 = await ethers.getContractFactory("MockERC20");
    mockERC20 = await MockERC20.deploy("Mock Token", "MTK", 18);
    await mockERC20.waitForDeployment();

    // 部署LendingPool合约
    const LendingPool = await ethers.getContractFactory("LendingPool");
    lendingPool = await LendingPool.deploy();
    await lendingPool.waitForDeployment();

    // 部署AToken合约
    const AToken = await ethers.getContractFactory("AToken");
    aToken = await AToken.deploy();
    await aToken.waitForDeployment();

    // 初始化AToken
    await aToken.initialize(lendingPool.target, mockERC20.target, "AToken", "ATK", 18);
  });

  it("应该正确铸造AToken并触发Mint事件", async function () {
    const mintAmount = ethers.parseUnits("100", 18); // 使用 ethers v6 的 parseUnits 替代 parseEther

    // 铸造AToken
    await expect(aToken.mint(user.address, mintAmount, index))
      .to.emit(aToken, "Mint")
      .withArgs(user.address, mintAmount, index);

    // 验证用户AToken余额
    const userBalance = await aToken.balanceOf(user.address);
    expect(userBalance).to.equal(mintAmount);
  });

  it("应该正确按缩放比例销毁AToken并触发Burn事件", async function () {
    const burnAmount = ethers.parseUnits("50", 18);

    // 在销毁前获取用户的初始AToken余额
    const initialBalance = await aToken.balanceOf(user.address);

    // 计算按流动性指数缩放后的AToken销毁数量
    const expectedBurnAmount = burnAmount.rayDiv(index);

    // 燃烧AToken
    await expect(aToken.burn(user.address, receiver.address, burnAmount, index))
      .to.emit(aToken, "Burn")
      .withArgs(user.address, receiver.address, burnAmount, index);

    // 验证用户的AToken余额减少，按缩放值
    const userBalance = await aToken.balanceOf(user.address);
    expect(userBalance).to.equal(initialBalance.sub(expectedBurnAmount));

    // 验证接收者接收到的MockERC20代币
    const receiverBalance = await mockERC20.balanceOf(receiver.address);
    expect(receiverBalance).to.equal(burnAmount); // 原始的ERC20数量未缩放
  });
});
