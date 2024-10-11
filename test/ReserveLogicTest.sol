// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import "forge-std/Test.sol";
import "../contracts/utils/logic/ReserveLogic.sol";
import "../contracts/utils/DataTypes.sol";
import "../contracts/utils/copyFromAave/WadRayMath.sol";
import "../contracts/utils/copyFromAave/PercentageMath.sol";

contract ReserveLogicTest is Test {
    using ReserveLogic for DataTypes.ReserveData;
    using WadRayMath for uint256;

    DataTypes.ReserveData reserve;

    function setUp() public {
        // 初始化储备数据
        reserve.liquidityIndex = uint128(WadRayMath.ray()); // 初始为 1e27
        reserve.variableBorrowIndex = uint128(WadRayMath.ray());
        // reserve.currentLiquidityRate = uint128(5e25);
        // // 表示 10% 的借款利率，转换为 ray 单位（10% 即 0.1 * 10^27 = 1e26）
        // reserve.currentVariableBorrowRate = uint128(1e26);
        reserve.lastUpdateTimestamp = uint40(block.timestamp - 1 days); // 上次更新时间为 1 天前
    }

    function testGetNormalizedIncome() public {
        uint256 normalizedIncome = reserve.getNomalizedIncome();
        uint256 expectedIncome = ReserveLogic
            .calculateLinearInterest(
                reserve.currentLiquidityRate,
                reserve.lastUpdateTimestamp
            )
            .rayMul(reserve.liquidityIndex);

        assertEq(
            normalizedIncome,
            expectedIncome,
            "Normalized income calculation is incorrect"
        );
    }

    function testGetNormalizedDebt() public {
        uint256 normalizedDebt = reserve.getNormalizedDebt();
        uint256 expectedDebt = ReserveLogic
            .calculateCompoundedInterest(
                reserve.currentVariableBorrowRate,
                reserve.lastUpdateTimestamp,
                block.timestamp
            )
            .rayMul(reserve.variableBorrowIndex);

        assertEq(
            normalizedDebt,
            expectedDebt,
            "Normalized debt calculation is incorrect"
        );
    }

    function testCalculateLinearInterest() public {
        uint256 interest = ReserveLogic.calculateLinearInterest(
            reserve.currentLiquidityRate,
            reserve.lastUpdateTimestamp
        );

        // 手动计算预期值
        uint256 timeDifference = block.timestamp - reserve.lastUpdateTimestamp;
        uint256 expectedInterest = (reserve.currentLiquidityRate *
            timeDifference) /
            ReserveLogic.SECONDS_PER_YEAR +
            WadRayMath.ray();

        assertEq(
            interest,
            expectedInterest,
            "Linear interest calculation is incorrect"
        );
    }

    function testCalculateCompoundedInterest() public {
        uint256 interest = ReserveLogic.calculateCompoundedInterest(
            reserve.currentVariableBorrowRate,
            reserve.lastUpdateTimestamp,
            block.timestamp
        );

        // 由于 compounded interest 的计算较为复杂，这里可以根据已知值进行断言
        // 或者在特定条件下，预期值等于初始值
        assertGt(
            interest,
            WadRayMath.ray(),
            "Compounded interest should be greater than 1e27"
        );
    }
}
