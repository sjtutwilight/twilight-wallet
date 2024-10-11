// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.8.21;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IVariableDebtToken} from "../../../interfaces/IVariableDebtToken.sol";
import {IReserveInterestRateStrategy} from "../../../interfaces/IReserveInterestRateStrategy.sol";
import {ReserveConfiguration} from "../configuration/ReserveConfiguration.sol";
import {WadRayMath} from "../math/WadRayMath.sol";
import {PercentageMath} from "../math/PercentageMath.sol";
import {Errors} from "../helpers/Errors.sol";
import {DataTypes} from "../types/DataTypes.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";

library ReserveLogic {
    using WadRayMath for uint256;
    using PercentageMath for uint256;
    using ReserveLogic for DataTypes.ReserveData;
    using ReserveConfiguration for DataTypes.ReserveConfigurationMap;
    using SafeCast for uint256;

    uint256 internal constant SECONDS_PER_YEAR = 365 days;
    function getNomalizedIncome(
        DataTypes.ReserveData storage reserve
    ) internal view returns (uint256) {
        uint40 timestamp = reserve.lastUpdateTimestamp;
        if (uint40(block.timestamp) == timestamp) {
            return reserve.liquidityIndex;
        } else {
            return
                calculateLinearInterest(reserve.currentLiquidityRate, timestamp)
                    .rayMul(reserve.liquidityIndex);
        }
    }

    //only for variable debt,because stable debt don`t use reserve dimension index.
    function getNormalizedDebt(
        DataTypes.ReserveData storage reserve
    ) internal view returns (uint256) {
        uint40 timestamp = reserve.lastUpdateTimestamp;
        if (timestamp == uint40(block.timestamp)) {
            return reserve.variableBorrowIndex;
        }
        return
            calculateCompoundedInterest(
                reserve.currentVariableBorrowRate,
                timestamp,
                block.timestamp
            ).rayMul(reserve.variableBorrowIndex);
    }

    function updateState(
        DataTypes.ReserveData storage reserve,
        DataTypes.ReserveCache memory reserveCache
    ) internal {
        if (reserve.lastUpdateTimestamp == uint40(block.timestamp)) {
            return;
        }
        _updateIndexes(reserve, reserveCache);
        reserve.lastUpdateTimestamp = uint40(block.timestamp);
    }

    struct UpdateInterestRatesLocalVars {
        uint256 nextLiquidityRate;
        uint256 nextStableRate;
        uint256 nextVariableRate;
        uint256 totalVariableDebt;
    }
    function updateInterestRates(
        DataTypes.ReserveData storage reserve,
        DataTypes.ReserveCache memory cache,
        address reserveAddress,
        uint256 liquidityAdded,
        uint256 liquidityTaken
    ) internal {
        //too complex,mock
        reserve.currentLiquidityRate = ((1265 * WadRayMath.WAD) / 1000)
            .toUint128();
        //    reserve.currentLiquidityRate = vars.nextLiquidityRate.toUint128();
        reserve.currentVariableBorrowRate = ((1400 * WadRayMath.WAD) / 1000)
            .toUint128();
    }
    function init(
        DataTypes.ReserveData storage reserve,
        address aTokenAddress,
        address stableDebtTokenAddress,
        address variableDebtTokenAddress,
        address interestRateStrategyAddress
    ) internal {
        require(
            reserve.aTokenAddress == address(0),
            Errors.RESERVE_ALREADY_INITIALIZED
        );

        reserve.liquidityIndex = uint128(WadRayMath.RAY);
        reserve.variableBorrowIndex = uint128(WadRayMath.RAY);
        reserve.aTokenAddress = aTokenAddress;
        reserve.stableDebtTokenAddress = stableDebtTokenAddress;
        reserve.variableDebtTokenAddress = variableDebtTokenAddress;
        // reserve.interestRateStrategyAddress = interestRateStrategyAddress;
    }
    function cache(
        DataTypes.ReserveData storage data
    ) internal view returns (DataTypes.ReserveCache memory) {
        DataTypes.ReserveCache memory cache;
        cache.reserveConfiguration = data.configuration;
        cache.reserveFactor = cache.reserveConfiguration.getReserveFactor();
        cache.currLiquidityIndex = cache.nextLiquidityIndex = data
            .liquidityIndex;
        cache.currLiquidityRate = data.currentLiquidityRate;
        cache.currVariableBorrowIndex = cache.nextVariableBorrowIndex = data
            .variableBorrowIndex;
        cache.currVariableBorrowRate = data.currentVariableBorrowRate;
        cache.aTokenAddress = data.aTokenAddress;
        cache.stableDebtTokenAddress = data.stableDebtTokenAddress;
        cache.variableDebtTokenAddress = data.variableDebtTokenAddress;
        cache.reserveLastUpdateTimestamp = data.lastUpdateTimestamp;

        cache.currScaledVariableDebt = cache
            .nextScaledVariableDebt = IVariableDebtToken(
            cache.variableDebtTokenAddress
        ).scaledTotalSupply();
        return cache;
    }
    function _updateIndexes(
        DataTypes.ReserveData storage reserve,
        DataTypes.ReserveCache memory cache
    ) internal {
        if (cache.currLiquidityRate != 0) {
            uint256 cumulatedLiquidityInterest = calculateLinearInterest(
                cache.currLiquidityRate,
                cache.reserveLastUpdateTimestamp
            );
            cache.nextLiquidityIndex = cumulatedLiquidityInterest.rayMul(
                cache.currLiquidityIndex
            );
            reserve.liquidityIndex = cache.nextLiquidityIndex.toUint128();
        }
        //as the liquidity rate might come only from stable rate loans, we need to ensure
        //that there is actual variable debt before accumulating
        if (cache.currScaledVariableDebt != 0) {
            uint256 cumulatedVariableBorrowInterest = calculateCompoundedInterest(
                    cache.currVariableBorrowRate,
                    cache.reserveLastUpdateTimestamp
                );
            cache.nextVariableBorrowIndex = cumulatedVariableBorrowInterest
                .rayMul(cache.currVariableBorrowIndex);
            reserve.variableBorrowIndex = cache
                .nextVariableBorrowIndex
                .toUint128();
        }
    }

    function calculateLinearInterest(
        uint256 rate,
        uint40 lastUpdateTimestamp
    ) internal view returns (uint256) {
        //solium-disable-next-line
        uint256 result = rate *
            (block.timestamp - uint256(lastUpdateTimestamp));
        unchecked {
            result = result / SECONDS_PER_YEAR;
        }

        return WadRayMath.RAY + result;
    }

    function calculateCompoundedInterest(
        uint256 rate,
        uint40 lastUpdateTimestamp,
        uint256 currentTimestamp
    ) internal pure returns (uint256) {
        //solium-disable-next-line
        uint256 exp = currentTimestamp - uint256(lastUpdateTimestamp);

        if (exp == 0) {
            return WadRayMath.RAY;
        }

        uint256 expMinusOne;
        uint256 expMinusTwo;
        uint256 basePowerTwo;
        uint256 basePowerThree;
        unchecked {
            expMinusOne = exp - 1;

            expMinusTwo = exp > 2 ? exp - 2 : 0;

            basePowerTwo =
                rate.rayMul(rate) /
                (SECONDS_PER_YEAR * SECONDS_PER_YEAR);
            basePowerThree = basePowerTwo.rayMul(rate) / SECONDS_PER_YEAR;
        }

        uint256 secondTerm = exp * expMinusOne * basePowerTwo;
        unchecked {
            secondTerm /= 2;
        }
        uint256 thirdTerm = exp * expMinusOne * expMinusTwo * basePowerThree;
        unchecked {
            thirdTerm /= 6;
        }

        return
            WadRayMath.RAY +
            (rate * exp) /
            SECONDS_PER_YEAR +
            secondTerm +
            thirdTerm;
    }

    function calculateCompoundedInterest(
        uint256 rate,
        uint40 lastUpdateTimestamp
    ) internal view returns (uint256) {
        return
            calculateCompoundedInterest(
                rate,
                lastUpdateTimestamp,
                block.timestamp
            );
    }
}
