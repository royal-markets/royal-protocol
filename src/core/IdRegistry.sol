// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IIdRegistry} from "./interfaces/IIdRegistry.sol";
import {IDelegateRegistry} from "./interfaces/IDelegateRegistry.sol";

import {Migration} from "./abstract/Migration.sol";

import {LibString} from "solady/utils/LibString.sol";
import {Initializable} from "solady/utils/Initializable.sol";
import {UUPSUpgradeable} from "solady/utils/UUPSUpgradeable.sol";

/**
 * @title RoyalProtocol IdRegistry
 *
 * @notice The core User registry for the RoyalProtocol. Identities need to be registered here to act on the protocol.
 *
 *         Holds all the necessary information for a user, including the custody address, the username, and the recovery address.
 *         Also includes the logic for transferring custody, recovering custody, and changing the recovery address.
 */
contract IdRegistry is IIdRegistry, Migration, Initializable, UUPSUpgradeable {
    // =============================================================
    //                        CONSTANTS
    // =============================================================

    /* solhint-disable gas-small-strings */

    // `name` is intentionally lowercased for compatibility with tools like Etherscan,
    // that detect account ID transfers as token transfers, due to us using the `Transfer` event.
    /* solhint-disable const-name-snakecase */

    /// @inheritdoc IIdRegistry
    string public constant name = "RoyalProtocol ID";

    /* solhint-enable const-name-snakecase */

    /// @inheritdoc IIdRegistry
    string public constant VERSION = "2024-09-07";

    /* solhint-enable gas-small-strings */

    // =============================================================
    //                         STORAGE
    // =============================================================
    /// @inheritdoc IIdRegistry
    address public idGateway;

    /// @inheritdoc IIdRegistry
    address public delegateRegistry;

    /// @inheritdoc IIdRegistry
    uint256 public idCounter;

    /// @inheritdoc IIdRegistry
    mapping(address wallet => uint256 id) public idOf;

    /// @inheritdoc IIdRegistry
    mapping(uint256 id => address custody) public custodyOf;

    /// @inheritdoc IIdRegistry
    mapping(uint256 id => string username) public usernameOf;

    /// @inheritdoc IIdRegistry
    mapping(bytes32 usernameHash => uint256 id) public idOfUsernameHash;

    /// @inheritdoc IIdRegistry
    mapping(uint256 id => address recovery) public recoveryOf;

    // =============================================================
    //                          MODIFIERS
    // =============================================================

    /// @dev Ensures that only the IdGateway contract can call the function. (for initial registration).
    modifier onlyIdGateway() {
        if (msg.sender != idGateway) revert OnlyIdGateway();

        _;
    }

    // =============================================================
    //                    CONSTRUCTOR / INITIALIZATION
    // =============================================================

    constructor() {
        _disableInitializers();
    }

    /// @inheritdoc IIdRegistry
    function initialize(address migrator_, address initialOwner_) external override initializer {
        _initializeOwner(initialOwner_);
        _initializeMigrator(24 hours, migrator_);

        // Default to canonical address for the v2 delegate.xyz DelegateRegistry contract.
        delegateRegistry = 0x00000000000000447e69651d841bD8D104Bed493;
    }

    // =============================================================
    //                      REGISTRATION
    // =============================================================

    /// @inheritdoc IIdRegistry
    function register(address custody, string calldata username, address recovery)
        external
        override
        onlyIdGateway
        whenNotPaused
        returns (uint256 id)
    {
        _validateRegister(custody, username);
        id = _unsafeRegister(custody, username, recovery);
    }

    /**
     * @dev Validate the registration of a new ID.
     *
     * - The custody address must not already have a registered ID.
     * - The username must not already be in use.
     */
    function _validateRegister(address custody, string calldata username) internal view {
        // Cannot register a custody address that is already in use.
        if (idOf[custody] != 0) revert CustodyAlreadyRegistered();

        // Cannot register a username that is already in use.
        if (idOfUsernameHash[_calculateUsernameHash(username)] != 0) {
            revert UsernameAlreadyRegistered();
        }
    }

    /**
     * @dev Registers a new ID.
     *
     * Sets up the custody address and username of a new ID.
     * If the recovery address is provided, it is also set up.
     *
     * Emits a Registered event.
     */
    function _unsafeRegister(address custody, string calldata username, address recovery)
        internal
        returns (uint256 id)
    {
        // Increment before assignment - so no-one gets an ID of `0`.
        // Thus `0` can be reserved for a falsy value in various checks.
        unchecked {
            id = ++idCounter;
        }

        // Set up custody
        idOf[custody] = id;
        custodyOf[id] = custody;

        // Set up username
        usernameOf[id] = username;
        idOfUsernameHash[_calculateUsernameHash(username)] = id;

        // Set up recovery
        recoveryOf[id] = recovery;

        // Emit event
        emit Registered({id: id, custody: custody, username: username, recovery: recovery});
    }

    /// @dev Calculate the hash of a username, ensuring it is lowercased, because usernames are case-insensitive.
    function _calculateUsernameHash(string memory username) internal pure returns (bytes32) {
        return keccak256(bytes(LibString.lower(username)));
    }

    // =============================================================
    //                          TRANSFERS
    // =============================================================

    /// @inheritdoc IIdRegistry
    function transfer(uint256 id, address to) external override onlyIdGateway whenNotPaused {
        _validateTransfer(to);
        _unsafeTransfer(id, to);
    }

    /// @inheritdoc IIdRegistry
    function transferAndClearRecovery(uint256 id, address to) external override onlyIdGateway whenNotPaused {
        _validateTransfer(to);

        _unsafeTransfer(id, to);
        _unsafeChangeRecovery(id, address(0));
    }

    /// @dev Validate the transfer of an ID from one address to another.
    function _validateTransfer(address to) internal view {
        // The recipient must not already have an ID.
        if (idOf[to] != 0) revert CustodyAlreadyRegistered();
    }

    /// @dev Transfer an ID from one address to another.
    function _unsafeTransfer(uint256 id, address to) internal {
        // Delete old custody lookup.
        address from = custodyOf[id];
        idOf[from] = 0;

        // Set new custody address.
        custodyOf[id] = to;

        // `to` will NEVER == address(0), but this is a data sanity check.
        if (to != address(0)) {
            idOf[to] = id;
        }

        emit Transfer(from, to, id);
    }

    // =============================================================
    //                       TRANSFER USERNAME
    // =============================================================

    /// @inheritdoc IIdRegistry
    function transferUsername(uint256 fromId, uint256 toId, string calldata newFromUsername)
        external
        override
        onlyIdGateway
        whenNotPaused
    {
        _validateUsername(newFromUsername);
        _unsafeTransferUsername(fromId, toId, newFromUsername);
    }

    /// @dev Transfer the current username of `fromId` to `toId`, and set `fromId`'s username to `newFromUsername`.
    function _unsafeTransferUsername(uint256 fromId, uint256 toId, string calldata newFromUsername) internal {
        string memory transferredUsername = usernameOf[fromId];

        _unsafeChangeUsername(fromId, newFromUsername);
        _unsafeChangeUsername(toId, transferredUsername);

        emit UsernameTransferred(fromId, toId, transferredUsername);
    }

    /// @dev Validate that the proposed username is not already in use.
    function _validateUsername(string calldata username) internal view {
        // Cannot register a username that is already in use.
        if (idOfUsernameHash[_calculateUsernameHash(username)] != 0) {
            revert UsernameAlreadyRegistered();
        }
    }

    // =============================================================
    //                        CHANGE USERNAME
    // =============================================================

    /// @inheritdoc IIdRegistry
    function changeUsername(uint256 id, string calldata newUsername) external override onlyIdGateway whenNotPaused {
        _validateUsername(newUsername);

        _unsafeChangeUsername(id, newUsername);
    }

    /// @dev Change the username for an ID.
    function _unsafeChangeUsername(uint256 id, string memory newUsername) internal {
        // Delete old username lookup hash
        idOfUsernameHash[_calculateUsernameHash(usernameOf[id])] = 0;

        // Update username
        usernameOf[id] = newUsername;
        idOfUsernameHash[_calculateUsernameHash(newUsername)] = id;

        emit UsernameChanged(id, newUsername);
    }

    // =============================================================
    //                        RECOVERY LOGIC
    // =============================================================

    /// @inheritdoc IIdRegistry
    function changeRecovery(uint256 id, address newRecovery) external override onlyIdGateway whenNotPaused {
        _unsafeChangeRecovery(id, newRecovery);
    }

    /// @dev Change the recovery address for an ID.
    function _unsafeChangeRecovery(uint256 id, address newRecovery) internal {
        recoveryOf[id] = newRecovery;

        emit RecoveryAddressChanged(id, newRecovery);
    }

    /// @inheritdoc IIdRegistry
    function recover(uint256 id, address to) external override onlyIdGateway whenNotPaused {
        _validateTransfer(to);
        _unsafeTransfer(id, to);

        emit Recovered(id, to);
    }

    // =============================================================
    //                      PERMISSIONED ACTIONS
    // =============================================================
    /// @inheritdoc IIdRegistry
    function setIdGateway(address idGateway_) external override onlyOwner {
        emit IdGatewaySet(idGateway, idGateway_);
        idGateway = idGateway_;
    }

    /// @inheritdoc IIdRegistry
    function setDelegateRegistry(address delegateRegistry_) external override onlyOwner {
        emit DelegateRegistrySet(delegateRegistry, delegateRegistry_);
        delegateRegistry = delegateRegistry_;
    }

    // =============================================================
    //                          MIGRATION
    // =============================================================

    /// @inheritdoc IIdRegistry
    function bulkRegisterIds(BulkRegisterData[] calldata data) external override onlyMigrator {
        uint256 length = data.length;
        unchecked {
            for (uint256 i = 0; i < length; i++) {
                BulkRegisterData calldata d = data[i];

                _validateRegister(d.custody, d.username);
                _unsafeRegister({custody: d.custody, username: d.username, recovery: d.recovery});
            }
        }
    }

    /// @inheritdoc IIdRegistry
    function bulkRegisterIdsWithDefaultRecovery(BulkRegisterWithDefaultRecoveryData[] calldata data, address recovery)
        external
        override
        onlyMigrator
    {
        uint256 length = data.length;
        unchecked {
            for (uint256 i = 0; i < length; i++) {
                BulkRegisterWithDefaultRecoveryData calldata d = data[i];

                _validateRegister(d.custody, d.username);
                _unsafeRegister({custody: d.custody, username: d.username, recovery: recovery});
            }
        }
    }

    /// @inheritdoc IIdRegistry
    function setIdCounter(uint256 counter) external override onlyMigrator {
        emit IdCounterSet(idCounter, counter);
        idCounter = counter;
    }

    // =============================================================
    //                       VIEW FUNCTIONS
    // =============================================================

    /// @inheritdoc IIdRegistry
    function getUserById(uint256 id) public view override returns (User memory user) {
        if (id == 0 || id > idCounter) revert HasNoId();

        return User({id: id, custody: custodyOf[id], username: usernameOf[id], recovery: recoveryOf[id]});
    }

    /// @inheritdoc IIdRegistry
    function getUserByAddress(address wallet) external view override returns (User memory user) {
        uint256 id = idOf[wallet];

        return getUserById(id);
    }

    /// @inheritdoc IIdRegistry
    function getUserByUsername(string calldata username) external view override returns (User memory user) {
        uint256 id = getIdByUsername(username);

        return getUserById(id);
    }

    /// @inheritdoc IIdRegistry
    function getIdByAddress(address wallet) external view override returns (uint256 id) {
        id = idOf[wallet];

        if (id == 0) revert HasNoId();
    }

    /// @inheritdoc IIdRegistry
    function getIdByUsername(string calldata username) public view override returns (uint256 id) {
        id = idOfUsernameHash[_calculateUsernameHash(username)];

        if (id == 0) revert HasNoId();
    }

    /// @inheritdoc IIdRegistry
    function checkIfUsernameExists(string calldata username) external view override returns (bool doesUsernameExist) {
        doesUsernameExist = idOfUsernameHash[_calculateUsernameHash(username)] != 0;
    }

    // =============================================================
    //                          CAN ACT
    // =============================================================

    /// @inheritdoc IIdRegistry
    ///
    /// @dev bytes32 rights follows delegate.xyz interface. (Could be role, functionSignature, etc.)
    function canAct(uint256 id, address actor, address contractAddr, bytes32 rights)
        external
        view
        override
        returns (bool)
    {
        // The actor must have _some_ registered ID.
        // (which could be different than the ID they are acting on behalf of).
        if (idOf[actor] == 0) return false;

        // If the actor is the custody address, they can act.
        address custody = custodyOf[id];
        if (actor == custody) return true;

        // If the actor is a delegate for the custody, they can act.
        bool delegated =
            IDelegateRegistry(delegateRegistry).checkDelegateForContract(actor, custody, contractAddr, rights);
        if (delegated) return true;

        // If none of the above, the actor cannot act for that ID.
        return false;
    }

    // =============================================================
    //                          UUPS
    // =============================================================

    // solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
