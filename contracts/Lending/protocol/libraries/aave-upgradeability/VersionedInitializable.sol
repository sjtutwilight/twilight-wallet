// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

abstract contract VersionedInitializable {
    uint256 private lastInitializedRevision;
    bool private initializing;
    modifier initializer() {
        uint256 revision = getRevision();
        require(
            initializing || revision > lastInitializedRevision,
            "already initialzed"
        );
        bool isTopLevelCall = !initializing;
        if (isTopLevelCall) {
            initializing = true;
            lastInitializedRevision = revision;
        }
        _;
        if (isTopLevelCall) {
            initializing = false;
        }
    }
    function getRevision() internal pure virtual returns (uint256);
}
