// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Test.sol";
import "../contracts/SimpleAave/LendingPool.sol";
import "../contracts/SimpleAave/AToken.sol";
import "../contracts/Pokemon/PKMToken.sol";
import "../contracts/utils/copyFromAave/WadRayMath.sol";
import "../contracts/utils/DataTypes.sol";

contract LendingPoolTest is Test {
    using WadRayMath for uint256;

    LendingPool lendingPool;
    AToken aToken;
    PKMToken mockERC20;

    address user = address(0x1);
    address onBehalfOf = address(0x2);
    address receiver = address(0x3);

    uint256 constant WAD = 1e18;
    uint256 constant RAY = 1e27;

    function setUp() public {
        // 部署 ERC20 代币（底层资产）
        vm.prank(user);
        mockERC20 = new PKMToken(100);

        // 部署 AToken
        aToken = new AToken();

        // 部署 LendingPool
        lendingPool = new LendingPool();

        // 初始化 AToken
        aToken.initialize(
            address(lendingPool),
            address(mockERC20),
            "AToken",
            "ATK"
        );

        // 初始化 LendingPool 中的储备
        lendingPool.initReserve(address(mockERC20), address(aToken));
        vm.prank(user);
        mockERC20.grantMinterRole(user);
        // 分配用户代币
        vm.prank(user);
        mockERC20.mint(user, 100);
    }
    function testDeposit() public {
        uint256 depositAmount = 100;

        // 用户批准 LendingPool 提取其代币
        vm.prank(user);
        mockERC20.approve(address(lendingPool), depositAmount);

        // 模拟用户存款
        vm.prank(user);
        lendingPool.deposit(address(mockERC20), depositAmount, onBehalfOf);

        // 检查 aToken 的余额
        uint256 aTokenBalance = aToken.balanceOf(onBehalfOf);
        assertEq(
            aTokenBalance,
            depositAmount,
            "aToken balance should match deposit amount"
        );

        // 检查 LendingPool 中是否发出了存款事件
        vm.expectEmit(true, true, true, true);
        // emit LendingPool.Deposit(
        //     address(mockERC20),
        //     user,
        //     onBehalfOf,
        //     depositAmount
        // );
    }

    function testWithdraw() public {
        uint256 depositAmount = 50;

        // 用户批准 LendingPool 提取其代币
        vm.prank(user);
        mockERC20.approve(address(lendingPool), depositAmount);

        // 模拟用户存款
        vm.prank(user);
        lendingPool.deposit(address(mockERC20), depositAmount, onBehalfOf);

        // 检查用户的初始余额
        uint256 initialBalance = mockERC20.balanceOf(receiver);

        // 模拟用户取款
        vm.prank(onBehalfOf);
        lendingPool.withdraw(address(mockERC20), depositAmount, receiver);

        // 验证用户的余额增加
        uint256 newBalance = mockERC20.balanceOf(receiver);
        assertEq(
            newBalance,
            initialBalance + depositAmount,
            "Receiver balance should increase by the withdrawn amount"
        );

        // 检查 aToken 的余额是否减少
        uint256 aTokenBalance = aToken.balanceOf(onBehalfOf);
        assertEq(
            aTokenBalance,
            0,
            "aToken balance should be 0 after full withdrawal"
        );
    }

    function testMint() public {
        uint256 mintAmount = 100;
        uint256 liquidityIndex = RAY; // 初始流动性指数

        // 按照流动性指数缩放铸造的数量
        uint256 scaledMintAmount = mintAmount.rayDiv(liquidityIndex);

        // 模拟铸造 aToken
        vm.prank(address(lendingPool));
        aToken.mint(onBehalfOf, mintAmount, liquidityIndex);

        // 验证 aToken 余额应该等于按 index 缩放后的数量
        uint256 aTokenBalance = aToken.balanceOf(onBehalfOf);
        assertEq(
            aTokenBalance,
            mintAmount,
            "aToken balance should match mint amount, adjusted for index"
        );
    }

    function testBurn() public {
        uint256 mintAmount = 100;
        uint256 liquidityIndex = RAY; // 初始流动性指数

        // 模拟铸造 aToken
        vm.prank(address(lendingPool));
        aToken.mint(onBehalfOf, mintAmount, liquidityIndex);

        vm.prank(onBehalfOf);
        mockERC20.approve(address(aToken), 100);

        // 模拟燃烧 aToken
        vm.prank(address(lendingPool));
        aToken.burn(onBehalfOf, receiver, mintAmount, liquidityIndex);

        // 验证 aToken 余额已减少
        uint256 aTokenBalance = aToken.balanceOf(onBehalfOf);
        assertEq(aTokenBalance, 0, "aToken balance should be 0 after burning");

        // 验证接收者的 ERC20 余额
        uint256 receiverBalance = mockERC20.balanceOf(receiver);
        assertEq(
            receiverBalance,
            mintAmount,
            "Receiver should receive the underlying asset after burn"
        );
    }

    function testInterestAccrual() public {
        uint256 depositAmount = 100;

        // 用户批准 LendingPool 提取其代币
        vm.prank(user);
        mockERC20.approve(address(lendingPool), depositAmount);

        // 模拟用户存款
        vm.prank(user);
        lendingPool.deposit(address(mockERC20), depositAmount, onBehalfOf);

        // 检查存款后的初始 aToken 余额
        uint256 initialBalance = aToken.balanceOf(onBehalfOf);
        assertEq(
            initialBalance,
            depositAmount,
            "Initial aToken balance should match deposit amount"
        );

        // 模拟时间流逝（例如 30 天）
        vm.warp(block.timestamp + 30 days);

        // // 更新储备的状态
        // DataTypes.ReserveData storage data = lendingPool.getReserveData(
        //     address(mockERC20)
        // );
        // DataTypes.updateState(data);
        // 获取更新后的流动性指数
        uint256 newLiquidityIndex = lendingPool.getReserveNomalizedIncome(
            address(mockERC20)
        );

        // 按照新的流动性指数计算预期的余额
        uint256 expectedNewBalance = initialBalance.rayMul(newLiquidityIndex);

        // 检查 aToken 余额是否增加
        uint256 newBalance = aToken.balanceOf(onBehalfOf);
        assertEq(
            newBalance,
            expectedNewBalance,
            "aToken balance should increase due to interest accrual over time"
        );
    }
}
