// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {GPv2SafeERC20} from "../helpers/GPv2SafeERC20.sol";
import {IAToken} from "../../../interfaces/IAToken.sol";
import {Errors} from "../helpers/Errors.sol";
import {UserConfiguration} from "../configuration/UserConfiguration.sol";
import {DataTypes} from "../types/DataTypes.sol";
import {WadRayMath} from "../math/WadRayMath.sol";
import {PercentageMath} from "../math/PercentageMath.sol";
import {ValidationLogic} from "./ValidationLogic.sol";
import {ReserveLogic} from "./ReserveLogic.sol";
import {ReserveConfiguration} from "../configuration/ReserveConfiguration.sol";
library SupplyLogic {
    using ReserveLogic for DataTypes.ReserveCache;
    using ReserveLogic for DataTypes.ReserveData;
    using GPv2SafeERC20 for IERC20;
    using UserConfiguration for DataTypes.UserConfigurationMap;
    using ReserveConfiguration for DataTypes.ReserveConfigurationMap;
    using WadRayMath for uint256;
    using PercentageMath for uint256;

    event ReserveUsedAsCollateralEnabled(
        address indexed reserve,
        address indexed user
    );
    event ReserveUsedAsCollateralDisabled(
        address indexed reserve,
        address indexed user
    );
    event Withdraw(
        address indexed reserve,
        address indexed user,
        address indexed to,
        uint256 amount
    );
    event Supply(
        address indexed reserve,
        address user,
        address indexed OnBehalfOf,
        uint256 amount
    );
    function executeSupply(
        mapping(address => DataTypes.ReserveData) storage reservesData,
        mapping(uint256 => address) storage reservesList,
        DataTypes.UserConfigurationMap storage userConfig,
        DataTypes.ExecuteSupplyParams memory params
    ) external {
        DataTypes.ReserveData storage reserve = reservesData[params.asset];
        DataTypes.ReserveCache memory reserveCache = reserve.cache();
        reserve.updateState(reserveCache);
        ValidationLogic.validateSupply(reserveCache, reserve, params.amount);
        reserve.updateInterestRates(
            reserveCache,
            params.asset,
            params.amount,
            0
        );
        IERC20(params.asset).safeTransferFrom(
            msg.sender,
            reserveCache.aTokenAddress,
            params.amount
        );
        bool isFirstSupply = IAToken(reserveCache.aTokenAddress).mint(
            msg.sender,
            params.onBehalfOf,
            params.amount,
            reserveCache.nextLiquidityIndex
        );
        if (isFirstSupply) {
            if (
                ValidationLogic.validateAutomaticUseAsCollateral(
                    reserveCache.reserveConfiguration,
                    userConfig
                )
            ) {
                userConfig.setUsingAsCollateral(reserve.id, true);
                emit ReserveUsedAsCollateralEnabled(
                    params.asset,
                    params.onBehalfOf
                );
            }
        }
        emit Supply(params.asset, msg.sender, params.onBehalfOf, params.amount);
    }
    function executeWithdraw(
        mapping(address => DataTypes.ReserveData) storage reservesData,
        mapping(uint256 => address) storage reservesList,
        DataTypes.UserConfigurationMap storage userConfig,
        DataTypes.ExecuteWithdrawParams memory params
    ) external returns (uint256) {
        DataTypes.ReserveData storage reserve = reservesData[params.asset];
        DataTypes.ReserveCache memory cache = reserve.cache();
        reserve.updateState(cache);
        uint256 userBalance = IAToken(cache.aTokenAddress)
            .scaledBalanceOf(msg.sender)
            .rayMul(cache.nextLiquidityIndex);
        uint256 amountToWithdraw = params.amount;
        if (params.amount == type(uint256).max) {
            amountToWithdraw = userBalance;
        }
        ValidationLogic.validateWithdraw(cache, amountToWithdraw, userBalance);
        reserve.updateInterestRates(cache, params.asset, 0, amountToWithdraw);
        bool isColleral = userConfig.isUsingAsCollateral(reserve.id);
        if (isColleral && userBalance == amountToWithdraw) {
            userConfig.setUsingAsCollateral(reserve.id, false);
            emit ReserveUsedAsCollateralDisabled(params.asset, msg.sender);
        }
        IAToken(cache.aTokenAddress).burn(
            msg.sender,
            params.to,
            params.amount,
            cache.nextLiquidityIndex
        );
        if (isColleral && userConfig.isBorrowingAny()) {
            ValidationLogic.validateHFAndLtv(
                reservesData,
                reservesList,
                userConfig,
                params.asset,
                msg.sender,
                params.reservesCount,
                params.oracle
            );
        }
        emit Withdraw(params.asset, msg.sender, params.to, amountToWithdraw);
        return amountToWithdraw;
    }
}
