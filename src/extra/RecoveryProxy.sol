// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IIdRegistry} from "../core/interfaces/IIdRegistry.sol";

import {Withdrawable} from "../core/abstract/Withdrawable.sol";
import {Initializable} from "solady/utils/Initializable.sol";
import {UUPSUpgradeable} from "solady/utils/UUPSUpgradeable.sol";

/* solhint-disable comprehensive-interface */

/**
 * @title RecoveryProxy
 * @notice A contract for managing recovery of IDs using the RoyalProtocol IdRegistry.
 */
contract RecoveryProxy is Withdrawable, Initializable, UUPSUpgradeable {
    // =============================================================
    //                           IMMUTABLES
    // =============================================================

    address public idRegistry;

    // =============================================================
    //                          CONSTANTS
    // =============================================================

    /// @notice The bitmask for the ADMIN role.
    uint256 public constant ADMIN = 1 << 0;

    /// @notice The bitmask for the RECOVER_CALLER role.
    uint256 public constant RECOVER_CALLER = 1 << 1;

    // =============================================================
    //                           EVENTS
    // =============================================================

    /// @notice Emitted when the IdRegistry is set/updated.
    event SetIdRegistry(address oldIdRegistry, address newIdRegistry);

    // =============================================================
    //                          CONSTRUCTOR
    // =============================================================

    constructor() {
        _disableInitializers();
    }

    // =============================================================
    //                          INITIALIZER
    // =============================================================

    /**
     * @notice Initializes the contract.
     * @param idRegistry_ The address of the IdRegistry contract.
     * @param owner The address of the contract owner.
     */
    function initialize(address idRegistry_, address owner) external initializer {
        _initializeOwner(owner);
        idRegistry = idRegistry_;
    }

    // =============================================================
    //                          RECOVERY
    // =============================================================

    /**
     * @notice Recovers an ID to a new address.
     * @param id The account ID to recover.
     * @param to The new custody address to recover the ID to.
     * @param deadline The deadline for the signature from the recovery address.
     * @param sig The signature from the recovery address.
     */
    function recover(uint256 id, address to, uint256 deadline, bytes calldata sig)
        public
        onlyRolesOrOwner(RECOVER_CALLER)
        whenNotPaused
    {
        IIdRegistry(idRegistry).recover(id, to, deadline, sig);
    }

    // =============================================================
    //                       ROLE HELPERS
    // =============================================================

    /// @notice Adds the ADMIN role to an account.
    function addAdmin(address account) external onlyOwner {
        _grantRoles(account, ADMIN);
    }

    /// @notice Removes the ADMIN role from an account.
    function removeAdmin(address account) external onlyOwner {
        _removeRoles(account, ADMIN);
    }

    /// @notice Adds the RECOVER_CALLER role to an account.
    function addRecoverCaller(address account) external onlyOwner {
        _grantRoles(account, RECOVER_CALLER);
    }

    /// @notice Removes the RECOVER_CALLER role from an account.
    function removeRecoverCaller(address account) external onlyOwner {
        _removeRoles(account, RECOVER_CALLER);
    }

    /// @notice Checks if an account has the ADMIN role.
    function isAdmin(address account) external view returns (bool) {
        return hasAnyRole(account, ADMIN);
    }

    /// @notice Checks if an account has the RECOVER_CALLER role.
    function isRecoverCaller(address account) external view returns (bool) {
        return hasAnyRole(account, RECOVER_CALLER);
    }

    // =============================================================
    //                          ADMIN FNs
    // =============================================================

    /// @notice Set the address of the IdRegistry contract.
    function setIdRegistry(address idRegistry_) external onlyRolesOrOwner(ADMIN) {
        emit SetIdRegistry(idRegistry, idRegistry_);
        idRegistry = idRegistry_;
    }

    // =============================================================
    //                          UUPS
    // =============================================================

    // solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address newImplementation) internal override onlyRolesOrOwner(ADMIN) {}
}
/* solhint-enable comprehensive-interface */
