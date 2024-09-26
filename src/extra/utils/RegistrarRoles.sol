// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IRoleData} from "./IRoleData.sol";
import {Withdrawable} from "../../core/abstract/Withdrawable.sol";

abstract contract RegistrarRoles is IRoleData, Withdrawable {
    // =============================================================
    //                          CONSTANTS
    // =============================================================

    // All the roles are defined here so that there isn't conflict between different contracts inheriting RegistrarRoles,
    // but the role helper functions are only defined in the respective inheriting contract,
    // so that those functions don't show up as part of the interface for contracts that don't use any given role.

    /// @notice The bitmask for the ADMIN role.
    uint256 public constant ADMIN = 1 << 0;

    /// @notice The bitmask for the REGISTER_CALLER role (ProvenanceRegistrar).
    uint256 public constant REGISTER_CALLER = 1 << 1;

    /// @notice The bitmask for the AIRDROPPER role (ProvenanceToken).
    uint256 public constant AIRDROPPER = 1 << 2;

    /// @notice The bitmask for the DEPLOY_CALLER role (RegistrarFactory).
    uint256 public constant DEPLOY_CALLER = 1 << 3;

    // NOTE: This role is not referenced in this file,
    // but I wanted to record here that the final bit is reserved for the GUARDIAN role.
    // which we inherit from Withdrawable (which inherits it from Guardians).
    // uint256 public constant GUARDIAN = 1 << 255;

    // =============================================================
    //                          INITIALIZER
    // =============================================================

    /// @dev Initialize the roles for the contract.
    function _initializeRoles(RoleData[] memory roles) internal {
        unchecked {
            uint256 length = roles.length;
            for (uint256 i = 0; i < length; i++) {
                RoleData memory role = roles[i];

                _setRoles(role.holder, role.roles);
            }
        }
    }

    // =============================================================
    //                       ROLE HELPERS
    // =============================================================

    /// @notice Check if an address has the ADMIN role.
    function isAdmin(address account) external view returns (bool) {
        return hasAnyRole(account, ADMIN);
    }

    /// @notice Add the ADMIN role to an address.
    function addAdmin(address account) external onlyOwner {
        _grantRoles(account, ADMIN);
    }

    /// @notice Remove the ADMIN role from an address.
    function removeAdmin(address account) external onlyOwner {
        _removeRoles(account, ADMIN);
    }
}
