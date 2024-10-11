import {VersionedInitializable} from "../libraries/aave-upgradeability/VersionedInitializable.sol";
import {Errors} from "../libraries/helpers/Errors.sol";
import {ReserveConfiguration} from "../libraries/configuration/ReserveConfiguration.sol";
//import {PoolLogic} from "../libraries/logic/PoolLogic.sol";
import {ReserveLogic} from "../libraries/logic/ReserveLogic.sol";
import {SupplyLogic} from "../libraries/logic/SupplyLogic.sol";
import {BorrowLogic} from "../libraries/logic/BorrowLogic.sol";
import {LiquidationLogic} from "../libraries/logic/LiquidationLogic.sol";
import {DataTypes} from "../libraries/types/DataTypes.sol";
import {IERC20WithPermit} from "../../interfaces/IERC20WithPermit.sol";
import {IPoolAddressesProvider} from "../../interfaces/IPoolAddressesProvider.sol";
import {IPool} from "../../interfaces/IPool.sol";
import {IACLManager} from "../../interfaces/IACLManager.sol";
import {PoolStorage} from "./PoolStorage.sol";

contract Pool is VersionedInitializable, PoolStorage, IPool {
    uint256 public constant POOL_REVISION = 0x1;

    IPoolAddressesProvider public immutable ADDRESSES_PROVIDER;
    constructor(IPoolAddressesProvider provider) {
        ADDRESSES_PROVIDER = provider;
    }
    function initialize(
        IPoolAddressesProvider provider
    ) external virtual initializer {
        require(
            provider == ADDRESSES_PROVIDER,
            Errors.INVALID_ADDRESSES_PROVIDER
        );
    }
    function supply(
        address asset,
        uint256 amount,
        address onBehalfOf
    ) public virtual override {
        SupplyLogic.executeSupply(
            _reserves,
            _reservesList,
            _usersConfig[onBehalfOf],
            DataTypes.ExecuteSupplyParams({
                asset: asset,
                amount: amount,
                onBehalfOf: onBehalfOf
            })
        );
    }
    function supplyWithPermit(
        address asset,
        uint256 amount,
        address onBehalfOf,
        uint256 deadline,
        uint8 permitV,
        bytes32 permitR,
        bytes32 permitS
    ) public virtual override {
        IERC20WithPermit(asset).permit(
            msg.sender,
            address(this),
            amount,
            deadline,
            permitV,
            permitR,
            permitS
        );
        SupplyLogic.executeSupply(
            _reserves,
            _reservesList,
            _usersConfig[onBehalfOf],
            DataTypes.ExecuteSupplyParams({
                asset: asset,
                amount: amount,
                onBehalfOf: onBehalfOf
            })
        );
    }
    function withdraw(
        address asset,
        uint256 amount,
        address to
    ) public virtual override returns (uint256) {
        SupplyLogic.executeWithdraw(
            _reserves,
            _reservesList,
            _usersConfig[msg.sender],
            DataTypes.ExecuteWithdrawParams({
                asset: asset,
                amount: amount,
                to: to,
                reservesCount: _reservesCount,
                oracle: ADDRESSES_PROVIDER.getPriceOracle()
            })
        );
    }
    function borrow(
        address asset,
        uint256 amount,
        uint256 interestRateMode,
        address onBehalfOf
    ) public virtual override {
        BorrowLogic.executeBorrow(
            _reserves,
            _reservesList,
            _usersConfig[onBehalfOf],
            DataTypes.ExecuteBorrowParams({
                asset: asset,
                user: msg.sender,
                onBehalfOf: onBehalfOf,
                amount: amount,
                interestRateMode: DataTypes.InterestRateMode(interestRateMode),
                releaseUnderlying: true,
                reservesCount: _reservesCount,
                oracle: ADDRESSES_PROVIDER.getPriceOracle(),
                priceOracleSentinel: ADDRESSES_PROVIDER.getPriceOracleSentinel()
            })
        );
    }
    function repay(
        address asset,
        uint256 amount,
        uint256 interestRateMode,
        address onBehalfOf
    ) public virtual override returns (uint256) {
        return
            BorrowLogic.executeRepay(
                _reserves,
                _reservesList,
                _usersConfig[onBehalfOf],
                DataTypes.ExecuteRepayParams({
                    asset: asset,
                    amount: amount,
                    interestRateMode: DataTypes.InterestRateMode(
                        interestRateMode
                    ),
                    onBehalfOf: onBehalfOf,
                    useATokens: false
                })
            );
    }
    function repayWithPermit(
        address asset,
        uint256 amount,
        uint256 interestRateMode,
        address onBehalfOf,
        uint256 deadline,
        uint8 permitV,
        bytes32 permitR,
        bytes32 permitS
    ) public virtual override returns (uint256) {
        {
            IERC20WithPermit(asset).permit(
                msg.sender,
                address(this),
                amount,
                deadline,
                permitV,
                permitR,
                permitS
            );
        }
        {
            DataTypes.ExecuteRepayParams memory params = DataTypes
                .ExecuteRepayParams({
                    asset: asset,
                    amount: amount,
                    interestRateMode: DataTypes.InterestRateMode(
                        interestRateMode
                    ),
                    onBehalfOf: onBehalfOf,
                    useATokens: false
                });
            return
                BorrowLogic.executeRepay(
                    _reserves,
                    _reservesList,
                    _usersConfig[onBehalfOf],
                    params
                );
        }
    }
    function liquidationCall(
        address collateralAsset,
        address debtAsset,
        address user,
        uint256 debtToCover,
        bool receiveAToken
    ) public virtual override {
        LiquidationLogic.executeLiquidationCall(
            _reserves,
            _reservesList,
            _usersConfig,
            DataTypes.ExecuteLiquidationCallParams({
                reservesCount: _reservesCount,
                debtToCover: debtToCover,
                collateralAsset: collateralAsset,
                debtAsset: debtAsset,
                user: user,
                receiveAToken: receiveAToken,
                priceOracle: ADDRESSES_PROVIDER.getPriceOracle(),
                priceOracleSentinel: ADDRESSES_PROVIDER.getPriceOracleSentinel()
            })
        );
    }
    function getRevision() internal pure virtual override returns (uint256) {
        return POOL_REVISION;
    }
}
