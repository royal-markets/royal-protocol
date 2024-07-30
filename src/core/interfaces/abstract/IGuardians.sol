// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IGuardians {
    // =============================================================
    //                            EVENTS
    // =============================================================

    /// @dev Emit an event when owner adds a new guardian address.
    event AddGuardian(address indexed guardian);

    /// @dev Emit an event when owner removes a guardian address.
    event RemoveGuardian(address indexed guardian);

    // =============================================================
    //                            ERRORS
    // =============================================================

    /// @dev Revert if an unauthorized caller calls a protected function.
    error OnlyGuardian();

    // =============================================================
    //                    PERMISSIONED FUNCTIONS
    // =============================================================

    /// @notice Add an address as a guardian. Only callable by owner.
    function addGuardian(address guardian) external;

    /// @notice Remove a guardian. Only callable by owner.
    function removeGuardian(address guardian) external;

    /// @notice Pause the contract. Only callable by owner or a guardian.
    function pause() external;

    /// @notice Unpause the contract. Only callable by owner.
    function unpause() external;

    // =============================================================
    //                          ROLE HELPERS
    // =============================================================

    /// @notice Check if an address is a guardian.
    function isGuardian(address account) external returns (bool);
}
