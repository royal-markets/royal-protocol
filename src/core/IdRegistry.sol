// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IIdRegistry} from "./interfaces/IIdRegistry.sol";
import {IDelegateRegistry} from "./interfaces/IDelegateRegistry.sol";
import {IUsernameGateway} from "./interfaces/IUsernameGateway.sol";

import {EIP712} from "./abstract/EIP712.sol";
import {Nonces} from "./abstract/Nonces.sol";
import {Migration} from "./abstract/Migration.sol";
import {Signatures} from "./abstract/Signatures.sol";

import {SignatureCheckerLib} from "solady/utils/SignatureCheckerLib.sol";
import {LibString} from "solady/utils/LibString.sol";

/**
 * @title RoyalProtocol IdRegistry
 *
 * @notice The core User registry for the RoyalProtocol. Identities need to be registered here to act on the protocol.
 *
 *         Holds all the necessary information for a user, including custody, username, operator, and recovery addresses.
 *         Also includes the logic for transferring custody, recovering custody, and changing operator or recovery addresses.
 */
contract IdRegistry is IIdRegistry, EIP712, Nonces, Migration, Signatures {
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
    string public constant VERSION = "2024-07-29";

    /// @inheritdoc IIdRegistry
    bytes32 public constant TRANSFER_TYPEHASH =
        keccak256("Transfer(uint256 id,address to,uint256 nonce,uint256 deadline)");

    /// @inheritdoc IIdRegistry
    bytes32 public constant TRANSFER_AND_CHANGE_OPERATOR_AND_RECOVERY_TYPEHASH = keccak256(
        "TransferAndChangeOperatorAndRecovery(uint256 id,address to,address newOperator,address newRecovery,uint256 nonce,uint256 deadline)"
    );

    /// @inheritdoc IIdRegistry
    bytes32 public constant CHANGE_OPERATOR_TYPEHASH =
        keccak256("ChangeOperator(uint256 id,address newOperator,uint256 nonce,uint256 deadline)");

    /// @inheritdoc IIdRegistry
    bytes32 public constant CHANGE_RECOVERY_TYPEHASH =
        keccak256("ChangeRecovery(uint256 id,address newRecovery,uint256 nonce,uint256 deadline)");

    /* solhint-enable gas-small-strings */

    // =============================================================
    //                         STORAGE
    // =============================================================
    /// @inheritdoc IIdRegistry
    address public idGateway;

    /// @inheritdoc IIdRegistry
    bool public idGatewayFrozen;

    /// @inheritdoc IIdRegistry
    address public usernameGateway;

    /// @inheritdoc IIdRegistry
    bool public usernameGatewayFrozen;

    /// @inheritdoc IIdRegistry
    ///
    /// @dev Default to canonical address for the v2 delegate.xyz DelegateRegistry contract.
    address public delegateRegistry = 0x00000000000000447e69651d841bD8D104Bed493;

    /// @inheritdoc IIdRegistry
    bool public delegateRegistryFrozen;

    /// @inheritdoc IIdRegistry
    uint256 public idCounter = 0;

    /// @inheritdoc IIdRegistry
    mapping(address wallet => uint256 id) public idOf;

    /// @inheritdoc IIdRegistry
    mapping(uint256 id => address custody) public custodyOf;

    /// @inheritdoc IIdRegistry
    mapping(uint256 id => string username) public usernameOf;

    /// @inheritdoc IIdRegistry
    mapping(bytes32 usernameHash => uint256 id) public idOfUsernameHash;

    /// @inheritdoc IIdRegistry
    mapping(uint256 id => address operator) public operatorOf;

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

    /// @dev Ensures that only the UsernameGateway contract can call the function. (for username operations).
    modifier onlyUsernameGateway() {
        if (msg.sender != usernameGateway) revert OnlyUsernameGateway();

        _;
    }

    // =============================================================
    //                          CONSTRUCTOR
    // =============================================================

    /**
     * @notice Sets up roles on the contract and pauses it so migrations can take place (if any).
     *         Pausing takes place in Migration() constructor.
     *
     * @param migrator_     Migrator address.
     * @param initialOwner_ Initial owner address.
     *
     */
    constructor(address migrator_, address initialOwner_) Migration(24 hours, migrator_, initialOwner_) {}

    // =============================================================
    //                          EIP712
    // =============================================================

    /// @dev Configure the EIP712 name and version for the domain separator.
    function _domainNameAndVersion() internal pure override returns (string memory name_, string memory version) {
        name_ = "RoyalProtocol_IdRegistry";
        version = "1";
    }

    // =============================================================
    //                      REGISTRATION
    // =============================================================

    /// @inheritdoc IIdRegistry
    ///
    /// @dev Includes `whenNotPaused` because the IdRegistry is paused on deploy, and we may want to run a migration before unpausing.
    ///      Technically you could handle this by just pausing the IdGateway, but this is more explicit / less error-prone.
    function register(address custody, string calldata username, address operator, address recovery)
        external
        override
        onlyIdGateway
        whenNotPaused
        returns (uint256 id)
    {
        _validateRegister(custody, username, operator);
        id = _unsafeRegister({custody: custody, username: username, operator: operator, recovery: recovery});
    }

    /**
     * @dev Validate the registration of a new ID.
     *
     * - The custody address must not already have a registered ID.
     * - The username is valid according to the UsernameGateway.
     * - The operator address must not already have a registered ID.
     * - The operator address must not be the same as the custody address.
     */
    function _validateRegister(address custody, string calldata username, address operator) internal view {
        if (idOf[custody] != 0) revert CustodyAlreadyRegistered();

        // We do validate registers inside a loop in bulk migrations,
        // but we control the UsernameGateway, so no risk to call out to an external contract.
        // Also, we don't need to check a return value because checkUsername reverts on failure.
        //
        // Can also ignore the return value because the UsernameGateway reverts on any errors, which is all we care about.
        //
        // slither-disable-start unused-return
        // slither-disable-next-line calls-loop
        IUsernameGateway(usernameGateway).checkUsername(username);
        // slither-disable-end unused-return

        // The operator cannot be the same as the custody address,
        // due to the logic in handling transfers and changeOperator().
        if (idOf[operator] != 0) revert OperatorAlreadyRegistered();
        if (operator == custody) revert OperatorCannotBeCustody();
    }

    /**
     * @dev Registers a new ID.
     *
     * Sets up the custody address and username of a new ID.
     * If the operator and/or recovery addresses are provided, they are also set up.
     *
     * Emits a Registered event.
     */
    function _unsafeRegister(address custody, string calldata username, address operator, address recovery)
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

        string memory lowercaseUsername = LibString.lower(username);
        idOfUsernameHash[keccak256(bytes(lowercaseUsername))] = id;

        // Only set operator if it's not the zero address, because we dont want idOf[address(0)] to be set.
        if (operator != address(0)) {
            idOf[operator] = id;
            operatorOf[id] = operator;
        }

        // Set up recovery
        recoveryOf[id] = recovery;

        emit Registered({id: id, custody: custody, username: username, operator: operator, recovery: recovery});
    }

    // =============================================================
    //                          TRANSFERS
    // =============================================================

    /// @inheritdoc IIdRegistry
    function transfer(address to, uint256 deadline, bytes calldata sig) external override {
        uint256 id = idOf[msg.sender];
        if (custodyOf[id] != msg.sender) revert OnlyCustody();

        _validateTransfer(to);
        _verifyTransferSig({id: id, to: to, deadline: deadline, signer: to, sig: sig});
        _unsafeTransfer(id, to);
    }

    /// @inheritdoc IIdRegistry
    function transferFor(
        uint256 id,
        address to,
        uint256 fromDeadline,
        bytes calldata fromSig,
        uint256 toDeadline,
        bytes calldata toSig
    ) external override {
        _validateTransfer(to);

        address from = custodyOf[id];
        _verifyTransferSig({id: id, to: to, deadline: fromDeadline, signer: from, sig: fromSig});
        _verifyTransferSig({id: id, to: to, deadline: toDeadline, signer: to, sig: toSig});

        _unsafeTransfer(id, to);
    }

    /// @inheritdoc IIdRegistry
    function transferAndChangeOperatorAndRecovery(
        address to,
        address newOperator,
        address newRecovery,
        uint256 deadline,
        bytes calldata sig
    ) external override {
        uint256 id = idOf[msg.sender];
        if (custodyOf[id] != msg.sender) revert OnlyCustody();

        _validateTransfer(to);
        _validateChangeOperator(newOperator);

        _verifyTransferAndChangeRecoverySig({
            id: id,
            to: to,
            newOperator: newOperator,
            newRecovery: newRecovery,
            deadline: deadline,
            signer: to,
            sig: sig
        });

        _unsafeTransfer(id, to);
        _unsafeChangeOperator(id, newOperator);
        _unsafeChangeRecovery(id, newRecovery);
    }

    /// @inheritdoc IIdRegistry
    function transferAndChangeOperatorAndRecoveryFor(
        uint256 id,
        address to,
        address newOperator,
        address newRecovery,
        uint256 fromDeadline,
        bytes calldata fromSig,
        uint256 toDeadline,
        bytes calldata toSig
    ) external override {
        _validateTransfer(to);
        _validateChangeOperator(newOperator);

        address from = custodyOf[id];
        _verifyTransferAndChangeRecoverySig({
            id: id,
            to: to,
            newOperator: newOperator,
            newRecovery: newRecovery,
            deadline: fromDeadline,
            signer: from,
            sig: fromSig
        });

        _verifyTransferAndChangeRecoverySig({
            id: id,
            to: to,
            newOperator: newOperator,
            newRecovery: newRecovery,
            deadline: toDeadline,
            signer: to,
            sig: toSig
        });

        _unsafeTransfer(id, to);
        _unsafeChangeOperator(id, newOperator);
        _unsafeChangeRecovery(id, newRecovery);
    }

    /// @dev Validate the transfer of an ID from one address to another.
    function _validateTransfer(address to) internal view {
        // The recipient must not already have an ID.
        if (idOf[to] != 0) revert CustodyAlreadyRegistered();
    }

    /// @dev Transfer an ID from one address to another.
    function _unsafeTransfer(uint256 id, address to) internal whenNotPaused {
        // Delete old custody lookup.
        address from = custodyOf[id];
        idOf[from] = 0;

        // Set new custody address.
        custodyOf[id] = to;

        // This can't actually happen, because of the signature checks.
        if (to != address(0)) {
            idOf[to] = id;
        }

        emit Transfer(from, to, id);
    }

    // =============================================================
    //                       TRANSFER USERNAME
    // =============================================================

    /// @inheritdoc IIdRegistry
    function unsafeTransferUsername(uint256 fromId, uint256 toId, string calldata newFromUsername)
        external
        override
        onlyUsernameGateway
    {
        _unsafeTransferUsername(fromId, toId, newFromUsername);
    }

    /// @dev Transfer the current username of `fromId` to `toId`, and set `fromId`'s username to `newFromUsername`.
    ///
    /// NOTE: Intentionally omits `whenNotPaused`, because that is handled by the UsernameGateway.
    function _unsafeTransferUsername(uint256 fromId, uint256 toId, string calldata newFromUsername) internal {
        string memory transferredUsername = usernameOf[fromId];

        _unsafeChangeUsername(fromId, newFromUsername);
        _unsafeChangeUsername(toId, transferredUsername);

        emit UsernameTransferred(fromId, toId, transferredUsername);
    }

    // =============================================================
    //                        CHANGE USERNAME
    // =============================================================

    /// @inheritdoc IIdRegistry
    function unsafeChangeUsername(uint256 id, string calldata newUsername) external override onlyUsernameGateway {
        _unsafeChangeUsername(id, newUsername);
    }

    /// @dev Change the username for an ID.
    ///
    /// NOTE: Intentionally omits `whenNotPaused`, because that is handled by the UsernameGateway.
    function _unsafeChangeUsername(uint256 id, string memory newUsername) internal {
        // Delete old username lookup hash
        idOfUsernameHash[keccak256(bytes(LibString.lower(usernameOf[id])))] = 0;

        // Update username
        usernameOf[id] = newUsername;
        idOfUsernameHash[keccak256(bytes(LibString.lower(newUsername)))] = id;

        emit UsernameChanged(id, newUsername);
    }

    // =============================================================
    //                        CHANGE OPERATOR
    // =============================================================

    /// @inheritdoc IIdRegistry
    function changeOperator(address newOperator) external override {
        uint256 id = idOf[msg.sender];
        if (custodyOf[id] != msg.sender) revert OnlyCustody();

        _validateChangeOperator(newOperator);
        _unsafeChangeOperator(id, newOperator);
    }

    /// @inheritdoc IIdRegistry
    function changeOperatorFor(uint256 id, address newOperator, uint256 deadline, bytes calldata sig)
        external
        override
    {
        _validateChangeOperator(newOperator);
        _verifyChangeOperatorSig({id: id, newOperator: newOperator, deadline: deadline, sig: sig});
        _unsafeChangeOperator(id, newOperator);
    }

    function _validateChangeOperator(address newOperator) internal view {
        // The operator must not already have an ID.
        if (idOf[newOperator] != 0) revert OperatorAlreadyRegistered();
    }

    /// @dev Change the operator address for an ID.
    function _unsafeChangeOperator(uint256 id, address newOperator) internal whenNotPaused {
        // Remove old operator
        idOf[operatorOf[id]] = 0;

        // Set new operator
        operatorOf[id] = newOperator;

        // Only set the idOf for the operator if its not address(0)
        if (newOperator != address(0)) {
            idOf[newOperator] = id;
        }

        emit OperatorAddressChanged(id, newOperator);
    }

    // =============================================================
    //                        RECOVERY LOGIC
    // =============================================================

    /// @inheritdoc IIdRegistry
    function changeRecovery(address newRecovery) external override {
        uint256 id = idOf[msg.sender];
        if (custodyOf[id] != msg.sender) revert OnlyCustody();

        _unsafeChangeRecovery(id, newRecovery);
    }

    /// @inheritdoc IIdRegistry
    function changeRecoveryFor(uint256 id, address newRecovery, uint256 deadline, bytes calldata sig)
        external
        override
    {
        _verifyChangeRecoverySig({id: id, newRecovery: newRecovery, deadline: deadline, sig: sig});

        _unsafeChangeRecovery(id, newRecovery);
    }

    /// @dev Change the recovery address for an ID.
    function _unsafeChangeRecovery(uint256 id, address newRecovery) internal whenNotPaused {
        recoveryOf[id] = newRecovery;

        emit RecoveryAddressChanged(id, newRecovery);
    }

    /// @inheritdoc IIdRegistry
    function recover(uint256 id, address to, uint256 deadline, bytes calldata sig) external override {
        // Revert if the caller is not the recovery address
        if (recoveryOf[id] != msg.sender) revert OnlyRecovery();

        _validateTransfer(to);
        _verifyTransferSig({id: id, to: to, deadline: deadline, signer: to, sig: sig});

        _unsafeTransfer(id, to);
        emit Recovered(id, to);
    }

    /// @inheritdoc IIdRegistry
    function recoverFor(
        uint256 id,
        address to,
        uint256 recoveryDeadline,
        bytes calldata recoverySig,
        uint256 toDeadline,
        bytes calldata toSig
    ) external override {
        _validateTransfer(to);

        address recovery = recoveryOf[id];
        _verifyTransferSig({id: id, to: to, deadline: recoveryDeadline, signer: recovery, sig: recoverySig});
        _verifyTransferSig({id: id, to: to, deadline: toDeadline, signer: to, sig: toSig});

        _unsafeTransfer(id, to);
        emit Recovered(id, to);
    }

    // =============================================================
    //                      PERMISSIONED ACTIONS
    // =============================================================

    /// @inheritdoc IIdRegistry
    function setIdGateway(address idGateway_) external override onlyOwner {
        if (idGatewayFrozen) revert Frozen();

        emit IdGatewaySet(idGateway, idGateway_);
        idGateway = idGateway_;
    }

    /// @inheritdoc IIdRegistry
    function freezeIdGateway() external override onlyOwner {
        if (idGatewayFrozen) revert Frozen();

        emit IdGatewayFrozen(idGateway);
        idGatewayFrozen = true;
    }

    /// @inheritdoc IIdRegistry
    function setUsernameGateway(address usernameGateway_) external override onlyOwner {
        if (usernameGatewayFrozen) revert Frozen();

        emit UsernameGatewaySet(usernameGateway, usernameGateway_);
        usernameGateway = usernameGateway_;
    }

    /// @inheritdoc IIdRegistry
    function freezeUsernameGateway() external override onlyOwner {
        if (usernameGatewayFrozen) revert Frozen();

        emit UsernameGatewayFrozen(usernameGateway);
        usernameGatewayFrozen = true;
    }

    /// @inheritdoc IIdRegistry
    function setDelegateRegistry(address delegateRegistry_) external override onlyOwner {
        if (delegateRegistryFrozen) revert Frozen();

        emit DelegateRegistrySet(delegateRegistry, delegateRegistry_);
        delegateRegistry = delegateRegistry_;
    }

    /// @inheritdoc IIdRegistry
    function freezeDelegateRegistry() external override onlyOwner {
        if (delegateRegistryFrozen) revert Frozen();

        emit DelegateRegistryFrozen(delegateRegistry);
        delegateRegistryFrozen = true;
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

                _validateRegister(d.custody, d.username, address(0));
                _unsafeRegister({custody: d.custody, username: d.username, operator: address(0), recovery: d.recovery});
            }
        }
    }

    /// @inheritdoc IIdRegistry
    function bulkRegisterIdsWithOperator(BulkRegisterWithOperatorData[] calldata data) external override onlyMigrator {
        uint256 length = data.length;
        unchecked {
            for (uint256 i = 0; i < length; i++) {
                BulkRegisterWithOperatorData calldata d = data[i];

                _validateRegister(d.custody, d.username, d.operator);
                _unsafeRegister({custody: d.custody, username: d.username, operator: d.operator, recovery: d.recovery});
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

                _validateRegister(d.custody, d.username, address(0));
                _unsafeRegister({custody: d.custody, username: d.username, operator: address(0), recovery: recovery});
            }
        }
    }

    /// @inheritdoc IIdRegistry
    function bulkRegisterIdsWithOperatorAndDefaultRecovery(
        BulkRegisterWithOperatorAndDefaultRecoveryData[] calldata data,
        address recovery
    ) external override onlyMigrator {
        uint256 length = data.length;
        unchecked {
            for (uint256 i = 0; i < length; i++) {
                BulkRegisterWithOperatorAndDefaultRecoveryData calldata d = data[i];

                _validateRegister(d.custody, d.username, d.operator);
                _unsafeRegister({custody: d.custody, username: d.username, operator: d.operator, recovery: recovery});
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
    function getUserById(uint256 id) external view override returns (User memory user) {
        if (id > idCounter) revert HasNoId();

        return User({
            id: id,
            custody: custodyOf[id],
            username: usernameOf[id],
            operator: operatorOf[id],
            recovery: recoveryOf[id]
        });
    }

    /// @inheritdoc IIdRegistry
    function getIdByUsername(string calldata username) external view override returns (uint256 id) {
        id = idOfUsernameHash[keccak256(bytes(LibString.lower(username)))];

        if (id == 0) revert HasNoId();
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

        // If the actor is the custody or operator address, they can act.
        address custody = custodyOf[id];
        if (actor == custody) return true;

        address operator = operatorOf[id];
        if (actor == operator) return true;

        // If the actor is a delegate for the custody or operator, they can act.
        bool custodyDelegation =
            IDelegateRegistry(delegateRegistry).checkDelegateForContract(actor, custody, contractAddr, rights);
        if (custodyDelegation) return true;

        bool operatorDelegation =
            IDelegateRegistry(delegateRegistry).checkDelegateForContract(actor, operator, contractAddr, rights);
        if (operatorDelegation) return true;

        // If none of the above, the actor cannot act for that ID.
        return false;
    }

    // =============================================================
    //                  SIGNATURE HELPERS - VIEW FNS
    // =============================================================

    /// @inheritdoc IIdRegistry
    function verifyCustodySignature(uint256 id, bytes32 digest, bytes calldata sig)
        external
        view
        override
        returns (bool isValid)
    {
        address custody = custodyOf[id];
        isValid = SignatureCheckerLib.isValidSignatureNowCalldata(custody, digest, sig);
    }

    /// @inheritdoc IIdRegistry
    function verifyIdSignature(uint256 id, bytes32 digest, bytes calldata sig)
        external
        view
        override
        returns (bool isValid)
    {
        address custody = custodyOf[id];
        address operator = operatorOf[id];

        isValid = SignatureCheckerLib.isValidSignatureNowCalldata(custody, digest, sig)
            || SignatureCheckerLib.isValidSignatureNowCalldata(operator, digest, sig);
    }

    // =============================================================
    //                       SIGNATURE HELPERS
    // =============================================================

    /// @dev Verify the EIP712 signature for a transfer(For) transaction.
    function _verifyTransferSig(uint256 id, address to, uint256 deadline, address signer, bytes calldata sig)
        internal
    {
        bytes32 digest = _hashTypedData(keccak256(abi.encode(TRANSFER_TYPEHASH, id, to, _useNonce(signer), deadline)));

        _verifySig(digest, signer, deadline, sig);
    }

    /// @dev Verify the EIP712 signature for a transferAndChangeRecovery(For) transaction.
    function _verifyTransferAndChangeRecoverySig(
        uint256 id,
        address to,
        address newOperator,
        address newRecovery,
        uint256 deadline,
        address signer,
        bytes calldata sig
    ) internal {
        bytes32 digest = _hashTypedData(
            keccak256(
                abi.encode(
                    TRANSFER_AND_CHANGE_OPERATOR_AND_RECOVERY_TYPEHASH,
                    id,
                    to,
                    newOperator,
                    newRecovery,
                    _useNonce(signer),
                    deadline
                )
            )
        );

        _verifySig(digest, signer, deadline, sig);
    }

    /// @dev Verify the EIP712 signature for a changeOperatorFor transaction.
    function _verifyChangeOperatorSig(uint256 id, address newOperator, uint256 deadline, bytes calldata sig) internal {
        // Needed to get nonce for the user and to verify signature.
        address custody = custodyOf[id];

        bytes32 digest = _hashTypedData(
            keccak256(abi.encode(CHANGE_OPERATOR_TYPEHASH, id, newOperator, _useNonce(custody), deadline))
        );

        _verifySig(digest, custody, deadline, sig);
    }

    /// @dev Verify the EIP712 signature for a changeRecoveryFor transaction.
    function _verifyChangeRecoverySig(uint256 id, address newRecovery, uint256 deadline, bytes calldata sig) internal {
        // Needed to get nonce for the user and to verify signature.
        address custody = custodyOf[id];

        bytes32 digest = _hashTypedData(
            keccak256(abi.encode(CHANGE_RECOVERY_TYPEHASH, id, newRecovery, _useNonce(custody), deadline))
        );

        _verifySig(digest, custody, deadline, sig);
    }
}
