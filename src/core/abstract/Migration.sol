// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Withdrawable} from "../abstract/Withdrawable.sol";
import {IMigration} from "../interfaces/abstract/IMigration.sol";

/**
 * @title Migration
 *
 * @notice Provides an abstraction around an initial "migration" for contracts.
 *         It pauses the contract as part of its constructor.
 *         Also note that it is built on Withdrawable, which is built on top of Guardians, which implies Ownable and Pausable.
 *
 * @dev - The implementing contract will need to call _initializeOwner() in either the constructor or an initializer.
 */
abstract contract Migration is IMigration, Withdrawable {
    // =============================================================
    //                            STORAGE
    // =============================================================

    /// @inheritdoc IMigration
    uint24 public gracePeriod;

    /// @inheritdoc IMigration
    address public migrator;

    /// @inheritdoc IMigration
    uint40 public migratedAt;

    // =============================================================
    //                           MODIFIERS
    // =============================================================

    /**
     * @notice Allow only the migrator to call the protected function.
     *         Revoke permissions after the migration period.
     */
    modifier onlyMigrator() {
        if (msg.sender != migrator) revert OnlyMigrator();

        if (isMigrated() && block.timestamp > migratedAt + gracePeriod) {
            revert PermissionRevoked();
        }

        _requirePaused();
        _;
    }

    // =============================================================
    //                          CONSTRUCTOR
    // =============================================================

    /**
     * @notice Set the grace period and migrator address.
     *         Pauses contract at initialization time.
     *
     * @param gracePeriod_  Migration grace period in seconds.
     * @param migrator_     Initial migrator address (potentially distinct from owner).
     */
    function _initializeMigrator(uint24 gracePeriod_, address migrator_) internal {
        gracePeriod = gracePeriod_;
        migrator = migrator_;

        emit SetMigrator(address(0), migrator_);
        _pause();
    }

    // =============================================================
    //                             VIEWS
    // =============================================================

    /// @inheritdoc IMigration
    function isMigrated() public view returns (bool) {
        return migratedAt != 0;
    }

    // =============================================================
    //                          MIGRATION
    // =============================================================

    /// @inheritdoc IMigration
    function migrate() external {
        if (msg.sender != migrator) revert OnlyMigrator();
        if (isMigrated()) revert AlreadyMigrated();
        _requirePaused();

        migratedAt = uint40(block.timestamp);

        emit Migrated(migratedAt);
    }

    // =============================================================
    //                            SET MIGRATOR
    // =============================================================

    /// @inheritdoc IMigration
    function setMigrator(address migrator_) public onlyOwner {
        if (isMigrated()) revert AlreadyMigrated();
        _requirePaused();

        emit SetMigrator(migrator, migrator_);

        migrator = migrator_;
    }
}
