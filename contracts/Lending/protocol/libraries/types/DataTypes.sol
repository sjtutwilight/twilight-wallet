// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.8.21;

library DataTypes {
    struct ReserveData {
        ReserveConfigurationMap configuration;
        uint128 liquidityIndex;
        uint128 currentLiquidityRate;
        uint128 variableBorrowIndex;
        uint128 currentVariableBorrowRate;
        uint128 currentStableBorrowRate;
        uint40 lastUpdateTimestamp;
        address aTokenAddress;
        address stableDebtTokenAddress;
        address variableDebtTokenAddress;
        uint8 id;
        uint128 accruedToTreasury;
    }
    struct ReserveConfigurationMap {
        //bit 0-15: LTV
        //bit 16-31: Liq. threshold
        //bit 32-47: Liq. bonus
        //bit 48-55: Decimals
        //bit 56: Reserve is active
        //bit 57: reserve is frozen
        //bit 58: borrowing is enabled
        //bit 59: stable rate borrowing enabled
        //bit 60-63: reserved
        //bit 64-79: reserve factor
        uint256 data;
    }
    struct ReserveCache {
        uint256 currScaledVariableDebt;
        uint256 nextScaledVariableDebt;
        uint256 currPrincipalStableDebt;
        uint256 currAvgStableBorrowRate;
        uint256 currTotalStableDebt;
        uint256 nextAvgStableBorrowRate;
        uint256 nextTotalStableDebt;
        uint256 currLiquidityIndex;
        uint256 nextLiquidityIndex;
        uint256 currVariableBorrowIndex;
        uint256 nextVariableBorrowIndex;
        uint256 currLiquidityRate;
        uint256 currVariableBorrowRate;
        uint256 reserveFactor;
        ReserveConfigurationMap reserveConfiguration;
        address aTokenAddress;
        address stableDebtTokenAddress;
        address variableDebtTokenAddress;
        uint40 reserveLastUpdateTimestamp;
        uint40 stableDebtLastUpdateTimestamp;
    }

    struct UserConfigurationMap {
        uint256 data;
    }
    struct CalculateUserAccountDataParams {
        UserConfigurationMap userConfig;
        uint256 reservesCount;
        address user;
        address oracle;
    }
    enum InterestRateMode {
        NONE,
        STABLE,
        VARIABLE
    }

    struct ExecuteSupplyParams {
        address asset;
        uint256 amount;
        address onBehalfOf;
    }
    struct ExecuteWithdrawParams {
        address asset;
        uint256 amount;
        address to;
        uint256 reservesCount;
        address oracle;
    }
    struct ExecuteBorrowParams {
        address asset;
        address user;
        address onBehalfOf;
        uint256 amount;
        InterestRateMode interestRateMode;
        bool releaseUnderlying;
        uint256 reservesCount;
        address oracle;
        address priceOracleSentinel;
    }
    struct ExecuteRepayParams {
        address asset;
        uint256 amount;
        InterestRateMode interestRateMode;
        address onBehalfOf;
        bool useATokens;
    }
    struct ExecuteLiquidationCallParams {
        uint256 reservesCount;
        uint256 debtToCover;
        address collateralAsset;
        address debtAsset;
        address user;
        bool receiveAToken;
        address priceOracle;
        address priceOracleSentinel;
    }

    struct ValidateBorrowParams {
        ReserveCache reserveCache;
        UserConfigurationMap userConfig;
        address asset;
        address userAddress;
        uint256 amount;
        InterestRateMode interestRateMode;
        uint256 reservesCount;
        address oracle;
        address priceOracleSentinel;
    }
    struct CalculateInterestRatesParams {
        uint256 unbacked;
        uint256 liquidityAdded;
        uint256 liquidityTaken;
        uint256 totalStableDebt;
        uint256 totalVariableDebt;
        uint256 averageStableBorrowRate;
        uint256 reserveFactor;
        address reserve;
        address aToken;
    }
}
