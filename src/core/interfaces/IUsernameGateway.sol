// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IIdRegistry} from "./IIdRegistry.sol";

interface IUsernameGateway {
    // NOTE: None of these events are actually emitted by IdGateway, but because they are emitted when calling
    //       either IdRegistry.unsafeChangeUsername() or IdRegistry.unsafeTransferUsername(),
    //       they are included here so that UsernameGateway's ABI includes them.
    //
    // =============================================================
    //                           EVENTS
    // =============================================================

    /// @dev Emitted on successful change of username.
    event UsernameChanged(uint256 indexed id, string newUsername);

    /// @dev Emitted on successful transfer of a username to another ID.
    event UsernameTransferred(uint256 indexed fromId, uint256 indexed toId, string username);

    // =============================================================
    //                          ERRORS
    // =============================================================

    /// @dev Revert when the relevant address is not the IdRegistry contract.
    error OnlyIdRegistry();

    /// @dev Revert when msg.sender is not the custody address of its associated ID.
    error OnlyCustody();

    /// @dev Revert when the provided username has already been registered by another ID.
    error UsernameAlreadyRegistered();

    /// @dev Revert when the provided username is too long.
    error UsernameTooLong();

    /// @dev Revert when the provided username is too short.
    error UsernameTooShort();

    /// @dev Revert when the provided username is not url-safe. (ASCII only, no special characters, etc.)
    error UsernameContainsInvalidChar();

    // =============================================================
    //                           CONSTANTS
    // =============================================================

    // Disable rule because we include function interfaces for constants/immutables that should stylistically be UPPERCASED.
    /* solhint-disable func-name-mixedcase */

    /// @notice Contract version specified in the RoyalProtocol version scheme.
    function VERSION() external view returns (string memory);

    /// @notice The EIP712 typehash for TransferUsername signatures.
    function TRANSFER_USERNAME_TYPEHASH() external view returns (bytes32);

    /// @notice The EIP712 typehash for ChangeUsername signatures.
    function CHANGE_USERNAME_TYPEHASH() external view returns (bytes32);

    // =============================================================
    //                           IMMUTABLES
    // =============================================================

    /// @notice The RoyalProtocol IdRegistry contract.
    function ID_REGISTRY() external view returns (IIdRegistry);

    /* solhint-enable func-name-mixedcase */

    // =============================================================
    //                       TRANSFER USERNAME
    // =============================================================

    /**
     * @notice Transfer the username of the caller's ID to another ID.
     *
     * @param toId The ID to transfer the username to.
     * @param newFromUsername The new username for the caller's ID.
     * @param toDeadline The deadline for the signature from the `to` ID.
     * @param toSig The signature from the `to` ID.
     */
    function transferUsername(uint256 toId, string calldata newFromUsername, uint256 toDeadline, bytes calldata toSig)
        external;

    /**
     * @notice Transfer the username of the `from` ID to the `to` ID.
     *
     * @param fromId The ID to transfer the username from.
     * @param toId The ID to transfer the username to.
     * @param newFromUsername The new username for the `from` ID.
     * @param fromDeadline The deadline for the signature from the `from` ID.
     * @param fromSig The signature from the `from` ID.
     * @param toDeadline The deadline for the signature from the `to` ID.
     * @param toSig The signature from the `to` ID.
     */
    function transferUsernameFor(
        uint256 fromId,
        uint256 toId,
        string calldata newFromUsername,
        uint256 fromDeadline,
        bytes calldata fromSig,
        uint256 toDeadline,
        bytes calldata toSig
    ) external;

    // =============================================================
    //                         CHANGE USERNAME
    // =============================================================

    /// @notice Change the username for the caller's ID.
    function changeUsername(string calldata newUsername) external;

    /// @notice Change the username for the provided ID.
    function changeUsernameFor(uint256 id, string calldata newUsername, uint256 deadline, bytes calldata sig)
        external;

    // =============================================================
    //                      PERMISSIONED ACTIONS
    // =============================================================

    /// @notice Forces a username transfer from one ID to another. (Only callable by the Owner).
    function forceTransferUsername(uint256 fromId, uint256 toId, string calldata newFromUsername) external;

    /// @notice Forces a username change for the provided ID. (Only callable by the Owner).
    function forceChangeUsername(uint256 id, string calldata newUsername) external;

    // =============================================================
    //                       USERNAME VALIDATION
    // =============================================================

    /**
     * @notice Check if a username is valid.
     *         Intended to be used by DApps to check if a username is valid before attempting to register it.
     *         Also used by the IdRegistry when registering a new ID.
     *
     * @return True if the username is valid, reverts otherwise.
     *
     * - Must be unique.
     * - Must be <= 16 bytes (ASCII characters) in length.
     * - All characters must be alphanumeric, "_" underscores, or "-" hyphens.
     */
    function checkUsername(string calldata username) external view returns (bool);
}
