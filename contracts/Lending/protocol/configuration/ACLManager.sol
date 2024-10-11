// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.10;
import "@openzeppelin/contracts/access/AccessControl.sol";

import {IPoolAddressesProvider} from "../../interfaces/IPoolAddressesProvider.sol";
import {IACLManager} from "../../interfaces/IACLManager.sol";
import {Errors} from "../libraries/helpers/Errors.sol";

contract ACLManager is AccessControl, IACLManager {
    bytes32 public constant override POOL_ADMIN_ROLE = keccak256("POOL_ADMIN");
    IPoolAddressesProvider public immutable ADDRESSES_PROVIDER;
    constructor(IPoolAddressesProvider provider) {
        ADDRESSES_PROVIDER = provider;
        address aclAdmin = provider.getACLAdmin();
        require(aclAdmin != address(0), Errors.ACL_ADMIN_CANNOT_BE_ZERO);
        _grantRole(DEFAULT_ADMIN_ROLE, aclAdmin);
    }
    function setRoleAdmin(
        bytes32 role,
        bytes32 adminRole
    ) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        _setRoleAdmin(role, adminRole);
    }
    function addPoolAdmin(address admin) external override {
        grantRole(POOL_ADMIN_ROLE, admin);
    }
    function removePoolAdmin(address admin) external override {
        revokeRole(POOL_ADMIN_ROLE, admin);
    }
    function isPoolAdmin(address admin) external view override returns (bool) {
        return hasRole(POOL_ADMIN_ROLE, admin);
    }
}
