// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IIdRegistry {
    // =============================================================
    //                        STRUCTS
    // =============================================================

    /**
     * @dev Struct used in getters for user data.
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

    /// @dev Emitted when the Owner sets the DelegateRegistry to a new value.
    event DelegateRegistrySet(address oldDelegateRegistry, address newDelegateRegistry);

    /// @dev Emitted when the Migrator sets the IdCounter to a new value as part of the migration process.
    event IdCounterSet(uint256 oldIdCounter, uint256 newIdCounter);

    // =============================================================
    //                          ERRORS
    // =============================================================

    /// @dev Revert when a non-IdGateway address attempts to call a gated function.
    error OnlyIdGateway();

    /// @dev Revert when the provided custody address has already been registered by another ID.
    error CustodyAlreadyRegistered();

    /// @dev Revert when the provided username has already been registered by another ID.
    error UsernameAlreadyRegistered();

    /// @dev Revert when the relevant username/ID does not exist.
    error HasNoId();

    // =============================================================
    //                        CONSTANTS
    // =============================================================

    // We write function interfaces for constants that should stylistically be UPPERCASED.
    /* solhint-disable func-name-mixedcase */

    /// @notice "Name" of the contract. Defined for compatibility with tools like Etherscan that detect ID transfers as token transfers. Intentionally lowercased.
    function name() external view returns (string memory);

    /// @notice Contract version specified in the RoyalProtocol version scheme.
    function VERSION() external view returns (string memory);

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

    /**
     * @notice The address of the DelegateRegistry contract. (updatable).
     *
     * We use this contract for the `canAct() logic to check delegations against the custody address of the ID.
     * It MUST implement the delegate.xyz v2 interface, (and by default, is the delegate.xyz v2 contract).
     *
     * It is updatable so that we can extend / swap the functionality of `canAct()` in the future if necessary.
     */
    function delegateRegistry() external view returns (address);

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
    //                        INITIALIZATION
    // =============================================================

    /**
     * @notice Initialize the IdRegistry contract with the provided `migrator_` and `initialOwner_`.
     *
     * @param migrator_ The address that can migrate.
     * @param initialOwner_ The initial owner of the contract.
     */
    function initialize(address migrator_, address initialOwner_) external;

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

    /**
     * @notice Transfer the given ID to another custody address. Only callable by the IdGateway.
     *
     * @param id The ID to transfer.
     * @param to The address to transfer the ID to.
     */
    function transfer(uint256 id, address to) external;

    /**
     * @notice Transfer the given ID to another custody address and clear the recovery address. Only callable by the IdGateway.
     *
     * @param id The ID to transfer.
     * @param to The address to transfer the ID to.
     */
    function transferAndClearRecovery(uint256 id, address to) external;

    // =============================================================
    //                       TRANSFER USERNAME
    // =============================================================

    /**
     * @notice Transfer the username of the caller's ID to another ID. Only callable by the IdGateway.
     *         Assumes most username validation has happened in the IdGateway.
     *
     * @param fromId The ID to transfer the username from.
     * @param toId The ID to transfer the username to.
     * @param newFromUsername The new username for the `from` ID.
     */
    function transferUsername(uint256 fromId, uint256 toId, string calldata newFromUsername) external;

    // =============================================================
    //                        CHANGE USERNAME
    // =============================================================

    /**
     * @notice Change the username for the provided ID. Only callable by the IdGateway.
     *         Assumes most username validation has happened in the IdGateway.
     *
     * @param id The ID to change the username for.
     * @param newUsername The new username for the provided `id`.
     */
    function changeUsername(uint256 id, string calldata newUsername) external;

    // =============================================================
    //                       RECOVERY LOGIC
    // =============================================================

    /// @notice Change the recovery address for the provided ID. Only callable by the IdGateway.
    function changeRecovery(uint256 id, address newRecovery) external;

    /**
     * @notice Recover the ID of the `from` address ` Only callable by the IdGateway.
     *
     * @param id The ID to recover.
     * @param to The address to transfer the ID to.
     */
    function recover(uint256 id, address to) external;

    // =============================================================
    //                      PERMISSIONED ACTIONS
    // =============================================================

    /// @notice Set the IdGateway contract address.
    function setIdGateway(address idGateway_) external;

    /// @notice Set the DelegateRegistry contract address. Only callable by the owner.
    function setDelegateRegistry(address delegateRegistry_) external;

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

    /// @notice Gets the User data for the provided custody address.
    function getUserByAddress(address wallet) external view returns (User memory);

    /// @notice Gets the User data for a given username.
    function getUserByUsername(string calldata username) external view returns (User memory);

    /// @notice Gets the ID for a given custody address.
    function getIdByAddress(address wallet) external view returns (uint256 id);

    /// @notice Gets the ID for a given username.
    function getIdByUsername(string calldata username) external view returns (uint256 id);

    function checkIfUsernameExists(string calldata username) external view returns (bool doesUsernameExist);

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
}
