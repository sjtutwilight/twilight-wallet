// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import "forge-std/Test.sol";
import "../contracts/utils/logic/GenericLogic.sol";
import "../contracts/utils/DataTypes.sol";
import "../contracts/utils/copyFromAave/UserConfiguration.sol";
import "../contracts/utils/copyFromAave/ReserveConfiguration.sol";
import "../contracts/utils/copyFromAave/WadRayMath.sol";
import "../contracts/utils/copyFromAave/PercentageMath.sol";

// 模拟的 Aave 依赖合约
contract MockReserveData {
    using ReserveConfiguration for DataTypes.ReserveConfigurationMap;

    DataTypes.ReserveData public reserveData;

    constructor(uint256 ltv, uint256 liquidationThreshold, uint8 decimals) {
        // 设置储备配置参数
        reserveData.configuration.data = 0;
        reserveData.configuration.setLtv(uint256(ltv));
        reserveData.configuration.setLiquidationThreshold(
            uint256(liquidationThreshold)
        );
        reserveData.configuration.setDecimals(decimals);
    }

    function getReserveData()
        external
        view
        returns (DataTypes.ReserveData memory)
    {
        return reserveData;
    }
}

contract GenericLogicTest is Test {
    using GenericLogic for *;
    using UserConfiguration for DataTypes.UserConfigurationMap;
    using ReserveConfiguration for DataTypes.ReserveConfigurationMap;

    // 定义测试变量
    GenericLogic.CalculateUserAccountDataVars vars;

    // 模拟储备数据
    mapping(address => DataTypes.ReserveData) reservesData;
    mapping(uint256 => address) reserves;
    uint256 reserveCount;
    DataTypes.UserConfigurationMap userConfig;

    address user = address(1);
    address mockReserveAddress = address(100);

    function setUp() public {
        // 初始化模拟的储备数据
        MockReserveData mockReserve = new MockReserveData(7500, 8000, 18); // LTV 75%，清算阈值 80%，18 位小数

        DataTypes.ReserveData storage reserveData = reservesData[
            mockReserveAddress
        ];
        //  reserveData = mockReserve.getReserveData();

        // 设置储备地址
        reserves[0] = mockReserveAddress;
        reserveCount = 1;

        // 设置用户配置，使用第 0 个储备作为抵押品
        userConfig.setUsingAsCollateral(0, true);

        // 模拟用户的 aToken 和债务代币余额
        // 由于无法直接模拟 ERC20 的余额，这里可以假定用户有一定的余额
        // 在实际测试中，可以使用 MockERC20 合约来模拟余额
    }

    function testCalculateUserAccountData() public {
        // 调用 calculateUserAccountData 函数
        (
            uint256 totalCollateralETH,
            uint256 totalDebtETH,
            uint256 avgLtv,
            uint256 avgLiquidationThreshold,
            uint256 healthFactor
        ) = GenericLogic.calculateUserAccountData(
                user,
                reservesData,
                userConfig,
                reserves,
                reserveCount,
                address(0) // oracle 地址，这里可以忽略或设置为任意地址
            );

        // 验证计算结果
        // 由于我们没有实际的余额数据，这里可以根据假设的值进行断言
        // 假设用户的总抵押为 100 ETH，LTV 为 75%，清算阈值为 80%
        // 因此，健康因子应该较高

        // 断言总抵押
        // assertEq(totalCollateralETH, 100 ether);

        // 断言总债务
        // assertEq(totalDebtETH, 0);

        // 断言平均 LTV
        assertEq(avgLtv, 7500); // 75%

        // 断言平均清算阈值
        assertEq(avgLiquidationThreshold, 8000); // 80%

        // 断言健康因子
        assertEq(healthFactor, type(uint256).max); // 因为没有债务，健康因子应为最大值
    }
}
