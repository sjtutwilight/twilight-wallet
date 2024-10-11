// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Test.sol";
import "../contracts/utils/DataTypes.sol";
import "../contracts/utils/logic/ReserveLogic.sol";

import "../contracts/utils/copyFromAave/WadRayMath.sol";

contract DataTypesTest is Test {
    using DataTypes for DataTypes.ReserveData;
    using WadRayMath for uint256;
    using ReserveLogic for DataTypes.ReserveData;
    DataTypes.ReserveData reserve;
    uint256 constant WAD = 1e18;
    uint256 constant RAY = 1e27;
    uint256 constant SECONDS_PER_YEAR = 365 days;

    function setUp() public {
        // 初始化 ReserveData 的初始状态
        address mockAToken = address(0xABCD);
        reserve.init(mockAToken);
    }

    function testInit() public {
        // 确保 init 函数正确初始化
        assertEq(reserve.liquidityIndex, RAY, "Liquidity index should be RAY");
        assertEq(
            reserve.currentLiquidityRate,
            uint128((1265 * WAD) / 1000),
            "Incorrect liquidity rate"
        );
        assertEq(
            reserve.aTokenAddress,
            address(0xABCD),
            "aTokenAddress not initialized correctly"
        );
        assertEq(
            reserve.lastUpdateTimestamp,
            block.timestamp,
            "Timestamp mismatch"
        );
    }

    function testGetNomalizedIncome() public {
        // 模拟时间流逝，并测试 getNomalizedIncome 函数
        uint256 initialIncome = reserve.getNomalizedIncome();
        assertEq(initialIncome, RAY, "Initial income should be RAY");

        // 增加1000秒的时间
        vm.warp(block.timestamp + 1000);

        // 更新收益并获取新的标准化收益
        uint256 newIncome = reserve.getNomalizedIncome();
        assertGt(
            newIncome,
            RAY,
            "New income should be greater than initial RAY due to interest accumulation"
        );
    }

    function testUpdateState() public {
        // 更新状态前记录初始流动性指数
        uint256 initialLiquidityIndex = reserve.liquidityIndex;

        // 增加时间后更新状态
        vm.warp(block.timestamp + 1 weeks); // 增加一周的时间
        reserve.updateState();

        // 验证流动性指数是否更新

        // 验证时间戳是否更新为当前块的时间戳
        assertEq(
            reserve.lastUpdateTimestamp,
            block.timestamp,
            "Timestamp should have been updated"
        );
    }

    function testUpdateInterestRates() public {
        // 调用 updateInterestRates 函数并验证利率的更新
        uint256 liquidityAdded = 1000 * WAD;
        uint256 liquidityTaken = 500 * WAD;

        reserve.updateInterestRates(
            address(this),
            address(this),
            liquidityAdded,
            liquidityTaken
        );

        // 检查当前利率是否等于设置的模拟值
        assertEq(
            reserve.currentLiquidityRate,
            uint128((1265 * WAD) / 1000),
            "Liquidity rate should be updated"
        );
    }

    function testRequireReserveAlreadyInitialized() public {
        // 测试重复初始化时触发的异常
        vm.expectRevert("RESERVE_ALREADY_INITIALIZED");
        reserve.init(address(0x1234)); // 再次初始化应该触发异常
    }
}
