// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.8.21;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IScaledBalanceToken} from "../../../interfaces/IScaledBalanceToken.sol";
import {IPriceOracleGetter} from "../../../interfaces/IPriceOracleGetter.sol";
import {ReserveConfiguration} from "../configuration/ReserveConfiguration.sol";
import {UserConfiguration} from "../configuration/UserConfiguration.sol";
import {PercentageMath} from "../math/PercentageMath.sol";
import {WadRayMath} from "../math/WadRayMath.sol";
import {DataTypes} from "../types/DataTypes.sol";
import {ReserveLogic} from "./ReserveLogic.sol";
import {IVariableDebtToken} from "../../../interfaces/IVariableDebtToken.sol";
import {IAToken} from "../../../interfaces/IAToken.sol";

library GenericLogic {
    using UserConfiguration for DataTypes.UserConfigurationMap;
    using ReserveConfiguration for DataTypes.ReserveConfigurationMap;
    using ReserveLogic for DataTypes.ReserveData;
    using WadRayMath for uint256;
    using PercentageMath for uint256;
    uint256 public constant HEALTH_FACTOR_LIQUIDATION_THRESHOLD = 1 ether;
    //using for intermediate storage during user account data calculating.Will no put onchain
    struct CalculateUserAccountDataVars {
        uint256 assetPrice;
        uint256 assetUnit;
        uint256 userBalanceInBaseCurrency;
        uint256 decimals;
        uint256 ltv;
        uint256 liquidationThreshold;
        uint256 i;
        uint256 healthFactor;
        uint256 totalCollateralInBaseCurrency;
        uint256 totalDebtInBaseCurrency;
        uint256 avgLtv;
        uint256 avgLiquidationThreshold;
        address currentReserveAddress;
        bool hasZeroLtvCollateral;
    }

    function calculateUserAccountData(
        mapping(address => DataTypes.ReserveData) storage reservesData,
        mapping(uint256 => address) storage reservesList,
        DataTypes.CalculateUserAccountDataParams memory params
    )
        internal
        view
        returns (uint256, uint256, uint256, uint256, uint256, bool)
    {
        if (params.userConfig.isEmpty()) {
            return (0, 0, 0, 0, type(uint256).max, false);
        }
        CalculateUserAccountDataVars memory vars;
        while (vars.i < params.reservesCount) {
            if (!params.userConfig.isUsingAsCollateralOrBorrowing(vars.i)) {
                unchecked {
                    ++vars.i;
                }
                continue;
            }
            vars.currentReserveAddress = reservesList[vars.i];
            if (vars.currentReserveAddress == address(0)) {
                unchecked {
                    ++vars.i;
                }
                continue;
            }
            DataTypes.ReserveData storage currentReserve = reservesData[
                vars.currentReserveAddress
            ];

            (
                vars.ltv,
                vars.liquidationThreshold,
                ,
                vars.decimals,
                ,

            ) = currentReserve.configuration.getParams();
            vars.assetPrice = IPriceOracleGetter(params.oracle).getAssetPrice(
                vars.currentReserveAddress
            );
            if (
                vars.liquidationThreshold != 0 &&
                params.userConfig.isUsingAsCollateral(vars.i)
            ) {
                vars.userBalanceInBaseCurrency = _getUserBalanceInBaseCurrency(
                    params.user,
                    currentReserve,
                    vars.assetPrice,
                    vars.assetUnit
                );

                vars.totalCollateralInBaseCurrency += vars
                    .userBalanceInBaseCurrency;
                if (vars.ltv != 0) {
                    vars.avgLtv += vars.userBalanceInBaseCurrency * vars.ltv;
                } else {
                    vars.hasZeroLtvCollateral = true;
                }

                vars.avgLiquidationThreshold +=
                    vars.userBalanceInBaseCurrency *
                    vars.liquidationThreshold;
            }
            if (params.userConfig.isBorrowing(vars.i)) {
                vars.totalDebtInBaseCurrency += _getUserDebtInBaseCurrency(
                    params.user,
                    currentReserve,
                    vars.assetPrice,
                    vars.assetUnit
                );
            }

            unchecked {
                ++vars.i;
            }
        }

        unchecked {
            vars.avgLtv = vars.totalCollateralInBaseCurrency != 0
                ? vars.avgLtv / vars.totalCollateralInBaseCurrency
                : 0;
            vars.avgLiquidationThreshold = vars.totalCollateralInBaseCurrency !=
                0
                ? vars.avgLiquidationThreshold /
                    vars.totalCollateralInBaseCurrency
                : 0;
        }

        vars.healthFactor = (vars.totalDebtInBaseCurrency == 0)
            ? type(uint256).max
            : (
                vars.totalCollateralInBaseCurrency.percentMul(
                    vars.avgLiquidationThreshold
                )
            ).wadDiv(vars.totalDebtInBaseCurrency);
        return (
            vars.totalCollateralInBaseCurrency,
            vars.totalDebtInBaseCurrency,
            vars.avgLtv,
            vars.avgLiquidationThreshold,
            vars.healthFactor,
            vars.hasZeroLtvCollateral
        );
    }
    function calculateAvailableBorrows(
        uint256 totalCollateralInBaseCurrency,
        uint256 totalDebtInBaseCurrency,
        uint256 ltv
    ) internal pure returns (uint256) {
        uint256 availableBorrowsInBaseCurrency = totalCollateralInBaseCurrency
            .percentMul(ltv);

        if (availableBorrowsInBaseCurrency < totalDebtInBaseCurrency) {
            return 0;
        }

        availableBorrowsInBaseCurrency =
            availableBorrowsInBaseCurrency -
            totalDebtInBaseCurrency;
        return availableBorrowsInBaseCurrency;
    }
    function _getUserDebtInBaseCurrency(
        address user,
        DataTypes.ReserveData storage reserve,
        uint256 assetPrice,
        uint256 assetUnit
    ) private view returns (uint256) {
        // fetching variable debt
        uint256 userTotalDebt = IVariableDebtToken(
            reserve.variableDebtTokenAddress
        ).scaledBalanceOf(user);
        if (userTotalDebt != 0) {
            userTotalDebt = userTotalDebt.rayMul(reserve.getNormalizedDebt());
        }

        userTotalDebt = assetPrice * userTotalDebt;

        unchecked {
            return userTotalDebt / assetUnit;
        }
    }

    function _getUserBalanceInBaseCurrency(
        address user,
        DataTypes.ReserveData storage reserve,
        uint256 assetPrice,
        uint256 assetUnit
    ) private view returns (uint256) {
        uint256 normalizedIncome = reserve.getNomalizedIncome();
        uint256 balance = (
            IAToken(reserve.aTokenAddress).scaledBalanceOf(user).rayMul(
                normalizedIncome
            )
        ) * assetPrice;

        unchecked {
            return balance / assetUnit;
        }
    }
}
