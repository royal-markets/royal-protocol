// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {OwnableRoles} from "solady/auth/OwnableRoles.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

import {IGuardians} from "../interfaces/abstract/IGuardians.sol";

/**
 * @notice Guardians contract to manage guardian addresses.
 *
 * Guardians can be added and removed by the owner of the contract.
 * The only action guardians can perform is to pause the contract.
 *
 * The thinking here is that, if something goes wrong,
 * it is useful to have multiple addresses that can pause the contract,
 * while only the owner can unpause the contract.
 */
abstract contract Guardians is IGuardians, OwnableRoles, Pausable {
    // =============================================================
    //                           CONSTANTS
    // =============================================================

    /// @dev use the last role possible so we don't conflict with other roles defined in the implementation contracts.
    uint256 public constant GUARDIAN = 1 << 255;

    // =============================================================
    //                    PERMISSIONED FUNCTIONS
    // =============================================================

    /// @inheritdoc IGuardians
    function addGuardian(address guardian) external onlyOwner {
        _grantRoles(guardian, GUARDIAN);
    }

    /// @inheritdoc IGuardians
    function removeGuardian(address guardian) external onlyOwner {
        _removeRoles(guardian, GUARDIAN);
    }

    /// @inheritdoc IGuardians
    function pause() external onlyRolesOrOwner(GUARDIAN) {
        _pause();
    }

    /// @inheritdoc IGuardians
    function unpause() external onlyOwner {
        _unpause();
    }

    // =============================================================
    //                          ROLE HELPERS
    // =============================================================

    /// @inheritdoc IGuardians
    function isGuardian(address account) external view returns (bool) {
        return hasAnyRole(account, GUARDIAN);
    }
}
