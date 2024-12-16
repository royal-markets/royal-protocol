// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/* solhint-disable ordering */
interface IMigration {
    // =============================================================
    //                           EVENTS
    // =============================================================

    /**
     * @dev Emit an event when the admin calls migrate().
     *
     * @param migratedAt  The timestamp at which the migration occurred.
     */
    event Migrated(uint256 indexed migratedAt);

    /**
     * @notice Emit an event when the owner changes the migrator address.
     *
     * @param oldMigrator The address of the previous migrator.
     * @param newMigrator The address of the new migrator.
     */
    event SetMigrator(address oldMigrator, address newMigrator);

    // =============================================================
    //                           ERRORS
    // =============================================================

    /// @dev Revert if the caller is not the migrator.
    error OnlyMigrator();

    /// @dev Revert if the migrator calls a migration function after the grace period.
    error PermissionRevoked();

    /// @dev Revert if the migrator calls migrate more than once.
    error AlreadyMigrated();

    // =============================================================
    //                           STORAGE
    // =============================================================

    /**
     * @notice Period in seconds after migration during which admin can continue to call protected migration functions.
     *         No migration functions can be called after the grace period passes.
     */
    function gracePeriod() external view returns (uint24);

    /**
     * @notice Migration admin address.
     */
    function migrator() external view returns (address);

    /**
     * @notice Timestamp at which the data was migrated.
     */
    function migratedAt() external view returns (uint40);

    // =============================================================
    //                     PERMISSIONED ACTIONS
    // =============================================================

    /**
     * @notice Set the time of the migration and emit an event.
     *
     *         Only callable by the migrator.
     */
    function migrate() external;

    /**
     * @notice Set the migrator address. Only callable by owner.
     *
     * @param migrator_ Migrator address.
     */
    function setMigrator(address migrator_) external;

    // =============================================================
    //                            VIEWS
    // =============================================================

    /**
     * @notice Check if the contract has been migrated.
     *
     * @return true if the contract has been migrated, false otherwise.
     */
    function isMigrated() external view returns (bool);
}
/* solhint-enable ordering */
