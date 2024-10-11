// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.10;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {GPv2SafeERC20} from "../helpers/GPv2SafeERC20.sol";

import {PercentageMath} from "../math/PercentageMath.sol";
import {WadRayMath} from "../../libraries/math/WadRayMath.sol";
import {Helpers} from "../../libraries/helpers/Helpers.sol";
import {DataTypes} from "../../libraries/types/DataTypes.sol";
import {ReserveLogic} from "./ReserveLogic.sol";
import {ValidationLogic} from "./ValidationLogic.sol";
import {GenericLogic} from "./GenericLogic.sol";

import {UserConfiguration} from "../../libraries/configuration/UserConfiguration.sol";
import {ReserveConfiguration} from "../../libraries/configuration/ReserveConfiguration.sol";
import {IAToken} from "../../../interfaces/IAToken.sol";
import {IStableDebtToken} from "../../../interfaces/IStableDebtToken.sol";
import {IVariableDebtToken} from "../../../interfaces/IVariableDebtToken.sol";
import {IPriceOracleGetter} from "../../../interfaces/IPriceOracleGetter.sol";

library LiquidationLogic {
    using WadRayMath for uint256;
    using PercentageMath for uint256;
    using ReserveLogic for DataTypes.ReserveCache;
    using ReserveLogic for DataTypes.ReserveData;
    using UserConfiguration for DataTypes.UserConfigurationMap;
    using ReserveConfiguration for DataTypes.ReserveConfigurationMap;
    using GPv2SafeERC20 for IERC20;

    // See `IPool` for descriptions
    event ReserveUsedAsCollateralEnabled(
        address indexed reserve,
        address indexed user
    );
    event ReserveUsedAsCollateralDisabled(
        address indexed reserve,
        address indexed user
    );
    event LiquidationCall(
        address indexed collateralAsset,
        address indexed debtAsset,
        address indexed user,
        uint256 debtToCover,
        uint256 liquidatedCollateralAmount,
        address liquidator,
        bool receiveAToken
    );
    uint256 internal constant DEFAULT_LIQUIDATION_CLOSE_FACTOR = 0.5e4;

    uint256 public constant MAX_LIQUIDATION_CLOSE_FACTOR = 1e4;

    uint256 public constant CLOSE_FACTOR_HF_THRESHOLD = 0.95e18;
    struct LiquidationCallLocalVars {
        uint256 userCollateralBalance;
        uint256 userVariableDebt;
        uint256 userTotalDebt;
        uint256 actualDebtToLiquidate;
        uint256 actualCollateralToLiquidate;
        uint256 liquidationBonus;
        uint256 healthFactor;
        uint256 liquidationProtocolFeeAmount;
        address collateralPriceSource;
        address debtPriceSource;
        IAToken collateralAToken;
        DataTypes.ReserveCache debtReserveCache;
    }
    function executeLiquidationCall(
        mapping(address => DataTypes.ReserveData) storage reservesData,
        mapping(uint256 => address) storage reservesList,
        mapping(address => DataTypes.UserConfigurationMap) storage usersConfig,
        DataTypes.ExecuteLiquidationCallParams memory params
    ) external {
        LiquidationCallLocalVars memory vars;

        DataTypes.ReserveData storage collateralReserve = reservesData[
            params.collateralAsset
        ];
        DataTypes.ReserveData storage debtReserve = reservesData[
            params.debtAsset
        ];
        DataTypes.UserConfigurationMap storage userConfig = usersConfig[
            params.user
        ];
        vars.debtReserveCache = debtReserve.cache();
        debtReserve.updateState(vars.debtReserveCache);

        (, , , , vars.healthFactor, ) = GenericLogic.calculateUserAccountData(
            reservesData,
            reservesList,
            DataTypes.CalculateUserAccountDataParams({
                userConfig: userConfig,
                reservesCount: params.reservesCount,
                user: params.user,
                oracle: params.priceOracle
            })
        );
        (
            vars.userVariableDebt,
            vars.userTotalDebt,
            vars.actualDebtToLiquidate
        ) = _calculateDebt(vars.debtReserveCache, params, vars.healthFactor);
    }
    function _calculateDebt(
        DataTypes.ReserveCache memory debtReserveCache,
        DataTypes.ExecuteLiquidationCallParams memory params,
        uint256 healthFactor
    ) internal view returns (uint256, uint256, uint256) {
        // ()=Helpers.getUserCurrentDebt(params.user,debtReserveCache);
    }
}
