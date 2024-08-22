// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IIdRegistry {
    // =============================================================
    //                        STRUCTS
    // =============================================================

    /**
     * @dev Struct used in a getter for user data.
     *
     * @param id The user's ID.
     * @param custody The user's custody address. Controls the ID.
     * @param username The user's username.
     * @param recovery The user's recovery address (Optional).
     *                 Can recover the ID to another custody address.
     */
    struct User {
        uint256 id;
        address custody;
        string username;
        address recovery; // Optional
    }

    /// @dev Struct argument for admin bulk register function,
    //       with user-specific recovery addresses.
    struct BulkRegisterData {
        address custody;
        string username;
        address recovery;
    }

    /// @dev Struct argument for admin bulk register function,
    ///      with a default recovery address.
    struct BulkRegisterWithDefaultRecoveryData {
        address custody;
        string username;
    }

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

    /// @dev Emitted when the Owner sets the IdGateway to a new value.
    event IdGatewaySet(address oldIdGateway, address newIdGateway);

    /// @dev Emitted when the Owner freezes the IdGateway dependency.
    event IdGatewayFrozen(address idGateway);

    /// @dev Emitted when the Owner sets the UsernameGateway to a new value.
    event UsernameGatewaySet(address oldUsernameGateway, address newUsernameGateway);

    /// @dev Emitted when the Owner freezes the UsernameGateway dependency.
    event UsernameGatewayFrozen(address usernameGateway);

    /// @dev Emitted when the Owner sets the DelegateRegistry to a new value.
    event DelegateRegistrySet(address oldDelegateRegistry, address newDelegateRegistry);

    /// @dev Emitted when the Owner freezes the DelegateRegistry dependency.
    event DelegateRegistryFrozen(address delegateRegistry);

    /// @dev Emitted when the Migrator sets the IdCounter to a new value as part of the migration process.
    event IdCounterSet(uint256 oldIdCounter, uint256 newIdCounter);

    // =============================================================
    //                          ERRORS
    // =============================================================

    /// @dev Revert when a non-IdGateway address attempts to call a gated function.
    error OnlyIdGateway();

    /// @dev Revert when a non-UsernameGateway address attempts to call a gated function.
    error OnlyUsernameGateway();

    /// @dev Revert when the provided custody address has already been registered by another ID.
    error CustodyAlreadyRegistered();

    /// @dev Revert when the relevant address is not the custody address of the ID.
    error OnlyCustody();

    /// @dev Revert when the relevant address is not the recovery address of the ID.
    error OnlyRecovery();

    /// @dev Revert when the DelegateRegistry or IdGateway dependency is permanently frozen and cannot be updated.
    error Frozen();

    /// @dev Revert when the relevant username/ID does not exist.
    error HasNoId();

    //
    // NOTE: None of the following errors are thrown by IdRegistry,
    //       but they are thrown by usernameGateway.checkUsername(),
    //       so are included here so that IdRegistry's ABI includes them.
    //
    //       Needed because the bulkRegisterX migration functions live on the IdRegistry contract,
    //       but they call out to UsernameGateway to validate usernames when validating the registration.
    //

    /// @dev Revert when the provided username has already been registered by another ID.
    error UsernameAlreadyRegistered();

    /// @dev Revert when the username is over 16 bytes.
    error UsernameTooLong();

    /// @dev Revert when the provided username is too short.
    error UsernameTooShort();

    /// @dev Revert when the username contains invalid characters.
    error UsernameContainsInvalidChar();

    // =============================================================
    //                        CONSTANTS
    // =============================================================

    // We write function interfaces for constants that should stylistically be UPPERCASED.
    /* solhint-disable func-name-mixedcase */

    /// @notice "Name" of the contract. Defined for compatibility with tools like Etherscan that detect ID transfers as token transfers. Intentionally lowercased.
    function name() external view returns (string memory);

    /// @notice Contract version specified in the RoyalProtocol version scheme.
    function VERSION() external view returns (string memory);

    /// @notice The EIP712 typehash for Transfer signatures.
    function TRANSFER_TYPEHASH() external view returns (bytes32);

    /// @notice The EIP712 typehash for Recover signatures.
    function RECOVER_TYPEHASH() external view returns (bytes32);

    /// @notice The EIP712 typehash for ChangeRecovery signatures.
    function CHANGE_RECOVERY_TYPEHASH() external view returns (bytes32);

    /* solhint-enable func-name-mixedcase */

    // =============================================================
    //                         STORAGE
    // =============================================================

    /**
     * @notice The address of the IdGateway contract - the only address that can register new IDs.
     *
     * The IdGateway wraps registration logic and provides a swappable abstraction layer around it.
     * This may be used in the future for more advanced registration logic.
     */
    function idGateway() external view returns (address);

    /// @notice Whether the IdGateway dependency is permanently frozen.
    function idGatewayFrozen() external view returns (bool);

    /**
     * @notice The address of the UsernameGateway contract - the only address that can change or transfer usernames.
     *
     * The UsernameGateway wraps username change logic and provides a swappable abstraction layer around it.
     * This may be used in the future for stricter/looser username validation.
     */
    function usernameGateway() external view returns (address);

    /// @notice Whether the UsernameGateway dependency is permanently frozen.
    function usernameGatewayFrozen() external view returns (bool);

    /**
     * @notice The address of the DelegateRegistry contract. (updatable).
     *
     * We use this contract for the `canAct() logic to check delegations against the custody address of the ID.
     * It MUST implement the delegate.xyz v2 interface, (and by default, is the delegate.xyz v2 contract).
     *
     * It is updatable so that we can extend / swap the functionality of `canAct()` in the future if necessary.
     */
    function delegateRegistry() external view returns (address);

    /// @notice Whether the DelegateRegistry dependency is permanently frozen.
    function delegateRegistryFrozen() external view returns (bool);

    /// @notice The last RoyalProtocol ID that was issued.
    function idCounter() external view returns (uint256);

    /// @notice Maps each custody address to its associated ID.
    function idOf(address wallet) external view returns (uint256);

    /// @notice Maps each ID to its associated custody address.
    function custodyOf(uint256 id) external view returns (address);

    /// @notice Maps each ID to its associated username.
    function usernameOf(uint256 id) external view returns (string memory);

    /// @notice Maps each (lowercased) username hash to its associated ID.
    function idOfUsernameHash(bytes32 usernameHash) external view returns (uint256);

    /// @notice Maps each ID to its associated recovery address.
    function recoveryOf(uint256 id) external view returns (address);

    // =============================================================
    //                      REGISTRATION
    // =============================================================

    /**
     * @notice Register a new RoyalProtocol ID to the custody address. Only callable by the IdGateway.
     *
     * @param custody The custody address for the ID. Controls the ID.
     * @param username The username for the ID.
     * @param recovery The recovery address for the ID. Can recover the ID to another custody address.
     */
    function register(address custody, string calldata username, address recovery) external returns (uint256 id);

    // =============================================================
    //                          TRANSFERS
    // =============================================================

    /// @notice Transfer the caller's ID to another address.
    ///
    /// NOTE: This leaves the `recovery` address unchanged.
    function transfer(address to, uint256 deadline, bytes calldata sig) external;

    /// @notice Transfer the provided ID to another address.
    ///
    /// NOTE: This leaves the `recovery` address unchanged.
    function transferFor(
        uint256 id,
        address to,
        uint256 fromDeadline,
        bytes calldata fromSig,
        uint256 toDeadline,
        bytes calldata toSig
    ) external;

    /// @notice Transfer the caller's ID to another address and clear the recovery address.
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
     * @notice Transfer the username of the caller's ID to another ID. Only callable by the UsernameGateway.
     *         Assumes username validation has happened in the UsernameGateway.
     *
     * @param fromId The ID to transfer the username from.
     * @param toId The ID to transfer the username to.
     * @param newFromUsername The new username for the `from` ID.
     */
    function unsafeTransferUsername(uint256 fromId, uint256 toId, string calldata newFromUsername) external;

    // =============================================================
    //                        CHANGE USERNAME
    // =============================================================

    /**
     * @notice Change the username for the provided ID. Only callable by the UsernameGateway.
     *         Assumes username validation has happened in the UsernameGateway.
     *
     * @param id The ID to change the username for.
     * @param newUsername The new username for the provided `id`.
     */
    function unsafeChangeUsername(uint256 id, string calldata newUsername) external;

    // =============================================================
    //                       RECOVERY LOGIC
    // =============================================================

    /// @notice Change the recovery address for the caller's ID.
    function changeRecovery(address newRecovery) external;

    /// @notice Change the recovery address for the provided ID.
    function changeRecoveryFor(uint256 id, address newRecovery, uint256 deadline, bytes calldata sig) external;

    /// @notice Recover the ID of the `from` address ` Called by the recovery address for that ID.
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

    /// @notice Set the IdGateway contract address.
    function setIdGateway(address idGateway_) external;

    /// @notice Freeze the IdGateway dependency.
    function freezeIdGateway() external;

    /// @notice Set the UsernameGateway contract address.
    function setUsernameGateway(address usernameGateway_) external;

    /// @notice Freeze the UsernameGateway dependency.
    function freezeUsernameGateway() external;

    /// @notice Set the DelegateRegistry contract address.
    function setDelegateRegistry(address delegateRegistry_) external;

    /// @notice Freeze the DelegateRegistry dependency.
    function freezeDelegateRegistry() external;

    // =============================================================
    //                          MIGRATION
    // =============================================================

    /// @notice Register a bunch of IDs as part of a migration.
    function bulkRegisterIds(BulkRegisterData[] calldata data) external;

    /// @notice Register a bunch of IDs with a default recovery address as part of a migration.
    function bulkRegisterIdsWithDefaultRecovery(BulkRegisterWithDefaultRecoveryData[] calldata data, address recovery)
        external;

    /**
     * @notice Set the idCounter to a new value.
     *
     * Used in migrations to allocate specific ID ranges.
     */
    function setIdCounter(uint256 counter) external;

    // =============================================================
    //                       VIEW FUNCTIONS
    // =============================================================

    /// @notice Get the User data for the provided ID.
    function getUserById(uint256 id) external view returns (User memory);

    /// @notice Gets the ID for a given username.
    function getIdByUsername(string calldata username) external view returns (uint256 id);

    /// @notice Gets the User data for the provided custody address.
    function getUserByAddress(address wallet) external view returns (User memory);

    /// @notice Gets the User data for a given username.
    function getUserByUsername(string calldata username) external view returns (User memory);

    // =============================================================
    //                          CAN ACT
    // =============================================================

    /**
     * @notice Check if an address can take a given action on behalf of an ID.
     *
     * NOTE: Because the logic here is based on the delegateRegistry, we can swap out
     *       the delegateRegistry from `delegate.xyz` to our own implementation in the future,
     *       if we ever want to update/upgrade the logic for `canAct()`.
     *
     * @param id The RoyalProtocol ID to check.
     * @param actor The address attempting to take the action.
     * @param contractAddr The address of the contract the action is being taken on.
     * @param rights The rights being requested. (Optional).
     */
    function canAct(uint256 id, address actor, address contractAddr, bytes32 rights) external view returns (bool);

    // =============================================================
    //                  SIGNATURE HELPERS - VIEW FNS
    // =============================================================

    /// @notice Verifies a signature for a given ID is from the `custody` address.
    function verifyIdSignature(uint256 id, bytes32 digest, bytes calldata sig) external returns (bool isValid);
}
