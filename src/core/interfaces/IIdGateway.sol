// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IIdRegistry} from "./IIdRegistry.sol";

interface IIdGateway {
    // NOTE: None of these events are actually emitted by IdGateway, but because they are emitted when calling IdRegistry,
    //       they are included here so that IdGateway's ABI includes them.
    //
    // =============================================================
    //                           EVENTS
    // =============================================================

    /// @dev Emitted on successful registration of a new ID.
    event Registered(uint256 id, address indexed custody, string username, address indexed recovery);

    /// @dev Emitted on successful transfer of an ID to another address.
    ///
    /// NOTE: We normally put `id` first in events, but this format is consistent with the ERC721 `Transfer` event,
    ///       which ensures various tools that know how to parse that event can also parse this one.
    event Transfer(address indexed from, address indexed to, uint256 indexed id);

    /// @dev Emitted on successful transfer of a username to another ID.
    event UsernameTransferred(uint256 indexed fromId, uint256 indexed toId, string username);

    /// @dev Emitted on successful change of username.
    event UsernameChanged(uint256 indexed id, string newUsername);

    /// @dev Emitted on successful change of recovery address.
    event RecoveryAddressChanged(uint256 indexed id, address indexed newRecovery);

    /// @dev Emitted on successful recovery of an ID to another address.
    event Recovered(uint256 indexed id, address indexed to);

    // =============================================================
    //                          ERRORS
    // =============================================================

    /// @dev Revert when the relevant address is not the recovery address of the ID.
    error OnlyRecovery();

    /// @dev Revert when the provided username is too long.
    error UsernameTooLong();

    /// @dev Revert when the provided username is too short.
    error UsernameTooShort();

    /// @dev Revert when the provided username is not url-safe. (ASCII only, no special characters, etc.)
    error UsernameContainsInvalidChar();

    //
    // These errors are thrown directly by the IdRegistry, when calling IdRegistry.register().
    //

    /// @dev Revert when the provided custody address has already been registered by another ID.
    error CustodyAlreadyRegistered();

    /// @dev Revert when the provided username has already been registered by another ID.
    error UsernameAlreadyRegistered();

    /// @dev Revert when the relevant username/ID does not exist.
    error HasNoId();

    // =============================================================
    //                           CONSTANTS
    // =============================================================

    // Disable rule because we include function interfaces for constants/immutables that should stylistically be UPPERCASED.
    /* solhint-disable func-name-mixedcase */

    /// @notice Contract version specified in the RoyalProtocol version scheme.
    function VERSION() external view returns (string memory);

    /// @notice EIP712 typehash for Register signatures.
    function REGISTER_TYPEHASH() external view returns (bytes32);

    /// @notice The EIP712 typehash for Transfer signatures.
    function TRANSFER_TYPEHASH() external view returns (bytes32);

    /// @notice The EIP712 typehash for TransferUsername signatures.
    function TRANSFER_USERNAME_TYPEHASH() external view returns (bytes32);

    /// @notice The EIP712 typehash for ChangeUsername signatures.
    function CHANGE_USERNAME_TYPEHASH() external view returns (bytes32);

    /// @notice The EIP712 typehash for ChangeRecovery signatures.
    function CHANGE_RECOVERY_TYPEHASH() external view returns (bytes32);

    /// @notice The EIP712 typehash for Recover signatures.
    function RECOVER_TYPEHASH() external view returns (bytes32);

    /* solhint-enable func-name-mixedcase */

    // =============================================================
    //                            STORAGE
    // =============================================================

    /// @notice The RoyalProtocol IdRegistry contract.
    function idRegistry() external view returns (IIdRegistry);

    // =============================================================
    //                        INITIALIZATION
    // =============================================================

    /**
     * @notice Initialize the IdGateway contract with the provided `idRegistry_` and `initialOwner_`.
     *
     * @param idRegistry_ The RoyalProtocol IdRegistry contract address.
     * @param initialOwner_ The initial owner of the contract.
     */
    function initialize(IIdRegistry idRegistry_, address initialOwner_) external;

    // =============================================================
    //                          REGISTRATION
    // =============================================================

    /**
     * @notice Register a new RoyalProtocol ID to the caller.
     *
     * Requirements:
     * - The IdGateway contract is not paused.
     * - The IdRegistry contract is not paused.
     * - The caller must not already have a registered ID.
     * - The provided `username` must be valid and unique.
     *
     * @param username The username for the account, for client-side human-readable identification.
     * @param recovery The address wich can recover the account. Set to address(0) to disable recovery.
     *
     * @return id The registered account ID.
     */
    function register(string calldata username, address recovery) external returns (uint256 id);

    /**
     * @notice Register a new RoyalProtocol ID to the provided `custody` address. A signed message from the `custody` address must be provided.
     *
     * Requirements:
     * - The IdGateway contract is not paused.
     * - The IdRegistry contract is not paused.
     * - The `custody` address must not already have a registered ID.
     * - The provided `username` must be valid and unique.
     * - The `deadline` must be in the future.
     * - The EIP712 signature `sig` must be valid.
     *
     * @param custody The custody address for the account. Also the signer of the EIP712 `sig`.
     * @param username The username for the account, for client-side human-readable identification.
     * @param recovery The address wich can recover the account. Set to address(0) to disable recovery.
     * @param deadline The expiration timestamp for the signature.
     * @param sig The EIP712 "Register" signature, signed by the custody address.
     *
     * @return id The registered account ID.
     */
    function registerFor(
        address custody,
        string calldata username,
        address recovery,
        uint256 deadline,
        bytes calldata sig
    ) external returns (uint256 id);

    // =============================================================
    //                          TRANSFERS
    // =============================================================

    /**
     * @notice Transfer the caller's ID to another address. Only callable by the IdGateway.
     *
     * @param to The address to transfer the ID to.
     * @param deadline The deadline at which the signature expires.
     * @param sig Signature signed by the `to` address authorizing the transfer.
     */
    function transfer(address to, uint256 deadline, bytes calldata sig) external;

    /**
     * @notice Transfer the provided ID to another address.
     *
     * NOTE: This leaves the `recovery` address unchanged.
     */
    function transferFor(
        uint256 id,
        address to,
        uint256 fromDeadline,
        bytes calldata fromSig,
        uint256 toDeadline,
        bytes calldata toSig
    ) external;
    /**
     * @notice Transfer the caller's ID to another address and clear the recovery address. Only callable by the IdGateway.
     *
     * @param to The address to transfer the ID to.
     * @param deadline The deadline at which the signature expires.
     * @param sig Signature signed by the `to` address authorizing the transfer.
     */
    function transferAndClearRecovery(address to, uint256 deadline, bytes calldata sig) external;

    /// @notice Transfer the provided ID to another address and clear the recovery address.
    function transferAndClearRecoveryFor(
        uint256 id,
        address to,
        uint256 fromDeadline,
        bytes calldata fromSig,
        uint256 toDeadline,
        bytes calldata toSig
    ) external;

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
    //                       RECOVERY LOGIC
    // =============================================================

    /// @notice Change the recovery address for the caller's ID. Only callable by the IdGateway.
    function changeRecovery(address newRecovery) external;

    /// @notice Change the recovery address for the provided ID.
    function changeRecoveryFor(uint256 id, address newRecovery, uint256 deadline, bytes calldata sig) external;

    /**
     * @notice Recover the ID of the `from` address ` Only callable by the recovery address for that ID.
     *
     * @param to The address to transfer the ID to.
     * @param deadline The deadline at which the signature expires.
     * @param sig Signature signed by the `to` address authorizing the transfer/recovery.
     */
    function recover(uint256 id, address to, uint256 deadline, bytes calldata sig) external;

    /**
     * @notice Recover the ID of the `from` address on behalf of the ID's recovery address.
     *
     * @param id The account ID to recover.
     * @param to The new custody address to recover the ID to.
     * @param recoveryDeadline The deadline for the signature from the recovery address.
     * @param recoverySig The signature from the recovery address.
     * @param toDeadline The deadline for the signature from the new custody address.
     * @param toSig The signature from the new custody address.
     */
    function recoverFor(
        uint256 id,
        address to,
        uint256 recoveryDeadline,
        bytes calldata recoverySig,
        uint256 toDeadline,
        bytes calldata toSig
    ) external;

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
