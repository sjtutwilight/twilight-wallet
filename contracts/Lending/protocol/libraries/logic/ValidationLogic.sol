// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.10;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import {GPv2SafeERC20} from "../helpers/GPv2SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";

import {IReserveInterestRateStrategy} from "../../../interfaces/IReserveInterestRateStrategy.sol";
import {IStableDebtToken} from "../../../interfaces/IStableDebtToken.sol";
import {IScaledBalanceToken} from "../../../interfaces/IScaledBalanceToken.sol";
import {IPriceOracleGetter} from "../../../interfaces/IPriceOracleGetter.sol";
import {IAToken} from "../../../interfaces/IAToken.sol";
import {IPriceOracleSentinel} from "../../../interfaces/IPriceOracleSentinel.sol";
import {IPoolAddressesProvider} from "../../../interfaces/IPoolAddressesProvider.sol";
import "@openzeppelin/contracts/access/IAccessControl.sol";
import {ReserveConfiguration} from "../configuration/ReserveConfiguration.sol";
import {UserConfiguration} from "../configuration/UserConfiguration.sol";
import {Errors} from "../helpers/Errors.sol";
import {WadRayMath} from "../math/WadRayMath.sol";
import {PercentageMath} from "../math/PercentageMath.sol";
import {DataTypes} from "../types/DataTypes.sol";
import {ReserveLogic} from "./ReserveLogic.sol";
import {GenericLogic} from "./GenericLogic.sol";

library ValidationLogic {
    using ReserveLogic for DataTypes.ReserveData;
    using WadRayMath for uint256;
    using PercentageMath for uint256;
    using SafeCast for uint256;
    using GPv2SafeERC20 for IERC20;
    using ReserveConfiguration for DataTypes.ReserveConfigurationMap;
    using UserConfiguration for DataTypes.UserConfigurationMap;
    using Address for address;
    uint256 public constant MINIMUM_HEALTH_FACTOR_LIQUIDATION_THRESHOLD =
        0.95e18;
    uint256 public constant HEALTH_FACTOR_LIQUIDATION_THRESHOLD = 1e18;

    function validateSupply(
        DataTypes.ReserveCache memory reserveCache,
        DataTypes.ReserveData storage reserve,
        uint256 amount
    ) internal view {
        require(amount != 0, Errors.INVALID_AMOUNT);

        (bool isActive, bool isFrozen, , , bool isPaused) = reserveCache
            .reserveConfiguration
            .getFlags();
        require(isActive, Errors.RESERVE_INACTIVE);
        require(!isPaused, Errors.RESERVE_PAUSED);
        require(!isFrozen, Errors.RESERVE_FROZEN);

        uint256 supplyCap = reserveCache.reserveConfiguration.getSupplyCap();
        require(
            supplyCap == 0 ||
                (
                    (IAToken(reserveCache.aTokenAddress).scaledTotalSupply() +
                        uint256(reserve.accruedToTreasury).rayMul(
                            reserveCache.nextLiquidityIndex
                        ) +
                        amount <=
                        supplyCap *
                            (10 **
                                reserveCache
                                    .reserveConfiguration
                                    .getDecimals()))
                ),
            Errors.SUPPLY_CAP_EXCEEDED
        );
    }
    function validateWithdraw(
        DataTypes.ReserveCache memory reserveCache,
        uint256 amount,
        uint256 userBalance
    ) internal pure {
        require(amount != 0, Errors.INVALID_AMOUNT);
        require(
            amount <= userBalance,
            Errors.NOT_ENOUGH_AVAILABLE_USER_BALANCE
        );

        (bool isActive, , , , bool isPaused) = reserveCache
            .reserveConfiguration
            .getFlags();
        require(isActive, Errors.RESERVE_INACTIVE);
        require(!isPaused, Errors.RESERVE_PAUSED);
    }

    struct ValidateBorrowLocalVars {
        uint256 currentLtv;
        uint256 collateralNeededInBaseCurrency;
        uint256 userCollateralInBaseCurrency;
        uint256 userDebtInBaseCurrency;
        uint256 availableLiquidity;
        uint256 healthFactor;
        uint256 totalDebt;
        uint256 totalSupplyVariableDebt;
        uint256 reserveDecimals;
        uint256 borrowCap;
        uint256 amountInBaseCurrency;
        uint256 assetUnit;
        bool isActive;
        bool isFrozen;
        bool isPaused;
        bool borrowingEnabled;
    }

    function validateBorrow(
        mapping(address => DataTypes.ReserveData) storage reservesData,
        mapping(uint256 => address) storage reservesList,
        DataTypes.ValidateBorrowParams memory params
    ) internal view {
        require(params.amount != 0, Errors.INVALID_AMOUNT);

        ValidateBorrowLocalVars memory vars;

        (
            vars.isActive,
            vars.isFrozen,
            vars.borrowingEnabled,
            ,
            vars.isPaused
        ) = params.reserveCache.reserveConfiguration.getFlags();
        require(vars.isActive, Errors.RESERVE_INACTIVE);
        require(!vars.isPaused, Errors.RESERVE_PAUSED);
        require(!vars.isFrozen, Errors.RESERVE_FROZEN);
        require(vars.borrowingEnabled, Errors.BORROWING_NOT_ENABLED);
        require(
            params.priceOracleSentinel == address(0) ||
                IPriceOracleSentinel(params.priceOracleSentinel)
                    .isBorrowAllowed(),
            Errors.PRICE_ORACLE_SENTINEL_CHECK_FAILED
        );
        require(
            params.interestRateMode == DataTypes.InterestRateMode.VARIABLE,
            Errors.INVALID_INTEREST_RATE_MODE_SELECTED
        );
        vars.reserveDecimals = params
            .reserveCache
            .reserveConfiguration
            .getDecimals();
        vars.borrowCap = params
            .reserveCache
            .reserveConfiguration
            .getBorrowCap();
        unchecked {
            vars.assetUnit = 10 ** vars.reserveDecimals;
        }
        if (vars.borrowCap != 0) {
            vars.totalSupplyVariableDebt = params
                .reserveCache
                .currScaledVariableDebt
                .rayMul(params.reserveCache.nextVariableBorrowIndex);
            vars.totalSupplyVariableDebt += params.amount;
            unchecked {
                require(
                    vars.totalSupplyVariableDebt <=
                        vars.borrowCap * vars.assetUnit,
                    Errors.BORROW_CAP_EXCEEDED
                );
            }
        }
        (
            vars.userCollateralInBaseCurrency,
            vars.userDebtInBaseCurrency,
            vars.currentLtv,
            ,
            vars.healthFactor,

        ) = GenericLogic.calculateUserAccountData(
            reservesData,
            reservesList,
            DataTypes.CalculateUserAccountDataParams({
                userConfig: params.userConfig,
                reservesCount: params.reservesCount,
                user: params.userAddress,
                oracle: params.oracle
            })
        );
        require(
            vars.userCollateralInBaseCurrency != 0,
            Errors.COLLATERAL_BALANCE_IS_ZERO
        );
        require(vars.currentLtv != 0, Errors.LTV_VALIDATION_FAILED);

        require(
            vars.healthFactor > HEALTH_FACTOR_LIQUIDATION_THRESHOLD,
            Errors.HEALTH_FACTOR_LOWER_THAN_LIQUIDATION_THRESHOLD
        );
        vars.amountInBaseCurrency =
            IPriceOracleGetter(params.oracle).getAssetPrice(params.asset) *
            params.amount;
        unchecked {
            vars.amountInBaseCurrency /= vars.assetUnit;
        }
        vars.collateralNeededInBaseCurrency = (vars.userDebtInBaseCurrency +
            vars.amountInBaseCurrency).percentDiv(vars.currentLtv);
        require(
            vars.collateralNeededInBaseCurrency <=
                vars.userCollateralInBaseCurrency,
            Errors.COLLATERAL_CANNOT_COVER_NEW_BORROW
        );
    }
    function validateRepay(
        DataTypes.ReserveCache memory reserveCache,
        uint256 amountSent,
        DataTypes.InterestRateMode interestRateMode,
        address onBehalfOf,
        uint256 variableDebt
    ) internal view {
        require(amountSent != 0, Errors.INVALID_AMOUNT);
        require(
            amountSent != type(uint256).max || msg.sender == onBehalfOf,
            Errors.NO_EXPLICIT_AMOUNT_TO_REPAY_ON_BEHALF
        );

        (bool isActive, , , , bool isPaused) = reserveCache
            .reserveConfiguration
            .getFlags();
        require(isActive, Errors.RESERVE_INACTIVE);
        require(!isPaused, Errors.RESERVE_PAUSED);

        require(
            variableDebt != 0 &&
                interestRateMode == DataTypes.InterestRateMode.VARIABLE,
            Errors.NO_DEBT_OF_SELECTED_TYPE
        );
    }
    //? why userConfig use storage
    function validateUseAsCollateral(
        DataTypes.ReserveConfigurationMap memory reserveConfig,
        DataTypes.UserConfigurationMap storage userConfig
    ) internal view returns (bool) {
        if (reserveConfig.getLtv() == 0) {
            return false;
        }
        if (!userConfig.isUsingAsCollateralAny()) {
            return true;
        }
        //? isolation logic
        return true;
    }
    function validateAutomaticUseAsCollateral(
        DataTypes.ReserveConfigurationMap memory reserveConfig,
        DataTypes.UserConfigurationMap storage userConfig
    ) internal view returns (bool) {
        //todo isolated mode
        return validateUseAsCollateral(reserveConfig, userConfig);
    }
    function validateHealthFactor(
        mapping(address => DataTypes.ReserveData) storage reservesData,
        mapping(uint256 => address) storage reservesList,
        DataTypes.UserConfigurationMap memory userConfig,
        address user,
        uint256 reservesCount,
        address oracle
    ) internal view returns (uint256, bool) {
        (, , , , uint256 healthFactor, bool hasZeroLtvCollateral) = GenericLogic
            .calculateUserAccountData(
                reservesData,
                reservesList,
                DataTypes.CalculateUserAccountDataParams({
                    userConfig: userConfig,
                    reservesCount: reservesCount,
                    user: user,
                    oracle: oracle
                })
            );
        require(
            healthFactor >= HEALTH_FACTOR_LIQUIDATION_THRESHOLD,
            Errors.HEALTH_FACTOR_LOWER_THAN_LIQUIDATION_THRESHOLD
        );

        return (healthFactor, hasZeroLtvCollateral);
    }
    function validateHFAndLtv(
        mapping(address => DataTypes.ReserveData) storage reservesData,
        mapping(uint256 => address) storage reservesList,
        DataTypes.UserConfigurationMap memory userConfig,
        address asset,
        address from,
        uint256 reservesCount,
        address oracle
    ) internal view {
        DataTypes.ReserveData memory reserve = reservesData[asset];

        (, bool hasZeroLtvCollateral) = validateHealthFactor(
            reservesData,
            reservesList,
            userConfig,
            from,
            reservesCount,
            oracle
        );

        require(
            !hasZeroLtvCollateral || reserve.configuration.getLtv() == 0,
            Errors.LTV_VALIDATION_FAILED
        );
    }
}
