// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IIdRegistry} from "./IIdRegistry.sol";

interface IIdGateway {
    // NOTE: None of these events are actually emitted by IdGateway, but because they are emitted when calling IdRegistry.register(),
    //       they are included here so that IdGateway's ABI includes them.
    //
    // =============================================================
    //                           EVENTS
    // =============================================================

    /// @dev Emitted on successful registration of a new ID.
    event Registered(
        uint256 id, address indexed custody, string username, address indexed operator, address indexed recovery
    );

    // NOTE: None of these errors are actually thrown by IdGateway, but because they are thrown when calling IdRegistry.register(),
    //       they are included here so that IdGateway's ABI includes them.
    //
    // =============================================================
    //                          ERRORS
    // =============================================================

    //
    // These errors are thrown directly by the IdRegistry, when calling IdRegistry.register().
    //

    /// @dev Revert when the provided custody address has already been registered by another ID.
    error CustodyAlreadyRegistered();

    /// @dev Revert when the provided operator address has already been registered by another ID.
    error OperatorAlreadyRegistered();

    /// @dev Revert when the `custody` and `operator` addresses provided in registration are the same.
    ///      They must be distinct because of how we handle transfers.
    error OperatorCannotBeCustody();

    //
    // These errors are thrown by the UsernameGateway, on username validation, when calling IdRegistry.register().
    //

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

    /// @notice EIP712 typehash for Register signatures.
    function REGISTER_TYPEHASH() external view returns (bytes32);

    // =============================================================
    //                           IMMUTABLES
    // =============================================================

    /// @notice The RoyalProtocol IdRegistry contract.
    function ID_REGISTRY() external view returns (IIdRegistry);

    /* solhint-enable func-name-mixedcase */

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
     * - If non-zero, the `operator` address must not already have a registered ID.
     *
     * @param username The username for the account, for client-side human-readable identification.
     * @param operator An alias / alternate wallet that can be used as this account. (Can be address(0)).
     * @param recovery The address wich can recover the account. Set to address(0) to disable recovery.
     *
     * @return id The registered account ID.
     */
    function register(string calldata username, address operator, address recovery) external returns (uint256 id);

    /**
     * @notice Register a new RoyalProtocol ID to the provided `custody` address. A signed message from the `custody` address must be provided.
     *
     * Requirements:
     * - The IdGateway contract is not paused.
     * - The IdRegistry contract is not paused.
     * - The `custody` address must not already have a registered ID.
     * - The provided `username` must be valid and unique.
     * - If non-zero, the `operator` address must not already have a registered ID.
     * - The `deadline` must be in the future.
     * - The EIP712 signature `sig` must be valid.
     *
     * @param custody The custody address for the account. Also the signer of the EIP712 `sig`.
     * @param username The username for the account, for client-side human-readable identification.
     * @param operator An alias / alternate wallet that can be used as this account. (Can be address(0)).
     * @param recovery The address wich can recover the account. Set to address(0) to disable recovery.
     * @param deadline The expiration timestamp for the signature.
     * @param sig The EIP712 "Register" signature, signed by the custody address.
     *
     * @return id The registered account ID.
     */
    function registerFor(
        address custody,
        string calldata username,
        address operator,
        address recovery,
        uint256 deadline,
        bytes calldata sig
    ) external returns (uint256 id);
}
