// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IIdGateway} from "./interfaces/IIdGateway.sol";
import {IIdRegistry} from "./interfaces/IIdRegistry.sol";

import {Withdrawable} from "./abstract/Withdrawable.sol";
import {Signatures} from "./abstract/Signatures.sol";
import {EIP712} from "./abstract/EIP712.sol";
import {Nonces} from "./abstract/Nonces.sol";
import {Initializable} from "solady/utils/Initializable.sol";
import {UUPSUpgradeable} from "solady/utils/UUPSUpgradeable.sol";

import {LibString} from "solady/utils/LibString.sol";

/**
 * @title RoyalProtocol IdGateway
 *
 * @notice An abstraction layer around registration for the IdRegistry.
 *         Having this abstraction layer allows for switching registration logic in the future if needed.
 */
contract IdGateway is IIdGateway, Withdrawable, Signatures, EIP712, Nonces, Initializable, UUPSUpgradeable {
    // =============================================================
    //                           CONSTANTS
    // =============================================================

    /* solhint-disable gas-small-strings */

    /// @inheritdoc IIdGateway
    string public constant VERSION = "2024-09-07";

    /// @inheritdoc IIdGateway
    bytes32 public constant REGISTER_TYPEHASH =
        keccak256("Register(address custody,string username,address recovery,uint256 nonce,uint256 deadline)");

    /// @inheritdoc IIdGateway
    bytes32 public constant TRANSFER_TYPEHASH =
        keccak256("Transfer(uint256 id,address to,uint256 nonce,uint256 deadline)");

    /// @inheritdoc IIdGateway
    bytes32 public constant TRANSFER_USERNAME_TYPEHASH =
        keccak256("TransferUsername(uint256 fromId,uint256 toId,string newFromUsername,uint256 nonce,uint256 deadline)");

    /// @inheritdoc IIdGateway
    bytes32 public constant CHANGE_USERNAME_TYPEHASH =
        keccak256("ChangeUsername(uint256 id,string newUsername,uint256 nonce,uint256 deadline)");

    /// @inheritdoc IIdGateway
    bytes32 public constant CHANGE_RECOVERY_TYPEHASH =
        keccak256("ChangeRecovery(uint256 id,address newRecovery,uint256 nonce,uint256 deadline)");

    /// @inheritdoc IIdGateway
    bytes32 public constant RECOVER_TYPEHASH =
        keccak256("Recover(uint256 id,address to,uint256 nonce,uint256 deadline)");

    /// @dev The Solady "allowed lookup" for the username charset.
    ///
    // This is solady.LibString.to7BitASCIIAllowedLookup(USERNAME_CHARSET),
    // Where USERNAME_CHARSET = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_";
    //
    // NOTE: Even though usernames are displayed and stored with case-senstivity,
    //       uniqueness checks are done when the username is lowercased.
    uint128 internal constant _ALLOWED_CHARACTERS = 0x7fffffe87fffffe03ff000000000000;

    /* solhint-enable gas-small-strings */

    // =============================================================
    //                           STORAGE
    // =============================================================

    /// @inheritdoc IIdGateway
    IIdRegistry public idRegistry;

    /// @inheritdoc IIdGateway
    uint256 public registerFee;

    /// @inheritdoc IIdGateway
    uint256 public transferFee;

    /// @inheritdoc IIdGateway
    uint256 public transferUsernameFee;

    /// @inheritdoc IIdGateway
    uint256 public changeUsernameFee;

    /// @inheritdoc IIdGateway
    uint256 public changeRecoveryFee;

    /// @inheritdoc IIdGateway
    uint256 public recoverFee;

    // =============================================================
    //                  CONSTRUCTOR / INITIALIZATION
    // =============================================================

    constructor() {
        _disableInitializers();
    }

    /// @inheritdoc IIdGateway
    function initialize(IIdRegistry idRegistry_, address initialOwner_) external override initializer {
        idRegistry = idRegistry_;
        _initializeOwner(initialOwner_);
    }

    // =============================================================
    //                          EIP712
    // =============================================================

    /// @dev Configure the EIP712 name and version for the domain separator.
    function _domainNameAndVersion() internal pure override returns (string memory name, string memory version) {
        name = "RoyalProtocol_IdGateway";
        version = "1";
    }

    // =============================================================
    //                          REGISTRATION
    // =============================================================

    /// @inheritdoc IIdGateway
    function register(string calldata username, address recovery)
        external
        payable
        override
        whenNotPaused
        returns (uint256 id)
    {
        if (msg.value < registerFee) revert InsufficientFee();

        // Validate the new username.
        _validateUsername(username);

        // Register the new ID.
        id = idRegistry.register(msg.sender, username, recovery);
    }

    /// @inheritdoc IIdGateway
    function registerFor(
        address custody,
        string calldata username,
        address recovery,
        uint256 deadline,
        bytes calldata sig
    ) external payable override whenNotPaused returns (uint256 id) {
        if (msg.value < registerFee) revert InsufficientFee();

        // Validate the new username.
        _validateUsername(username);

        // Reverts if the signature is invalid
        _verifyRegisterSig({custody: custody, username: username, recovery: recovery, deadline: deadline, sig: sig});

        // Register the new ID.
        id = idRegistry.register(custody, username, recovery);
    }

    // =============================================================
    //                          TRANSFERS
    // =============================================================

    /// @inheritdoc IIdGateway
    function transfer(address to, uint256 deadline, bytes calldata sig) external payable override whenNotPaused {
        if (msg.value < transferFee) revert InsufficientFee();

        uint256 id = idRegistry.getIdByAddress(msg.sender);

        // Reverts if the signature is invalid
        _verifyTransferSig({id: id, to: to, deadline: deadline, signer: to, sig: sig});

        // Transfer the ID.
        idRegistry.transfer(id, to);
    }

    /// @inheritdoc IIdGateway
    function transferFor(
        uint256 id,
        address to,
        uint256 fromDeadline,
        bytes calldata fromSig,
        uint256 toDeadline,
        bytes calldata toSig
    ) external payable override whenNotPaused {
        if (msg.value < transferFee) revert InsufficientFee();

        address from = idRegistry.custodyOf(id);
        _verifyTransferSig({id: id, to: to, deadline: fromDeadline, signer: from, sig: fromSig});
        _verifyTransferSig({id: id, to: to, deadline: toDeadline, signer: to, sig: toSig});

        idRegistry.transfer(id, to);
    }

    /// @inheritdoc IIdGateway
    function transferAndClearRecovery(address to, uint256 deadline, bytes calldata sig)
        external
        payable
        override
        whenNotPaused
    {
        if (msg.value < transferFee) revert InsufficientFee();

        // Get the ID of the sender.
        uint256 id = idRegistry.getIdByAddress(msg.sender);

        // Reverts if the signature is invalid
        _verifyTransferSig({id: id, to: to, deadline: deadline, signer: to, sig: sig});

        // Transfer the ID.
        idRegistry.transferAndClearRecovery(id, to);
    }

    /// @inheritdoc IIdGateway
    function transferAndClearRecoveryFor(
        uint256 id,
        address to,
        uint256 fromDeadline,
        bytes calldata fromSig,
        uint256 toDeadline,
        bytes calldata toSig
    ) external payable override {
        if (msg.value < transferFee) revert InsufficientFee();

        address from = idRegistry.custodyOf(id);
        _verifyTransferSig({id: id, to: to, deadline: fromDeadline, signer: from, sig: fromSig});
        _verifyTransferSig({id: id, to: to, deadline: toDeadline, signer: to, sig: toSig});

        idRegistry.transferAndClearRecovery(id, to);
    }

    // =============================================================
    //                       TRANSFER USERNAME
    // =============================================================

    /// @inheritdoc IIdGateway
    function transferUsername(uint256 toId, string calldata newFromUsername, uint256 toDeadline, bytes calldata toSig)
        external
        payable
        override
        whenNotPaused
    {
        if (msg.value < transferUsernameFee) revert InsufficientFee();

        uint256 fromId = idRegistry.getIdByAddress(msg.sender);

        _validateUsername(newFromUsername);

        // Verify that the current username of `fromId` is what the `toId` agreed to receive.
        string memory transferredUsername = idRegistry.usernameOf(fromId);
        _verifyChangeUsernameSig({id: toId, newUsername: transferredUsername, deadline: toDeadline, sig: toSig});

        idRegistry.transferUsername(fromId, toId, newFromUsername);
    }

    /// @inheritdoc IIdGateway
    function transferUsernameFor(
        uint256 fromId,
        uint256 toId,
        string calldata newFromUsername,
        uint256 fromDeadline,
        bytes calldata fromSig,
        uint256 toDeadline,
        bytes calldata toSig
    ) external payable override whenNotPaused {
        if (msg.value < transferUsernameFee) revert InsufficientFee();

        // Validate the new username.
        _validateUsername(newFromUsername);

        // Verify the signature by the `toId` account,
        // that the current username of `fromId` is the username the `toId` agreed to receive.
        string memory transferredUsername = idRegistry.usernameOf(fromId);
        _verifyChangeUsernameSig({id: toId, newUsername: transferredUsername, deadline: toDeadline, sig: toSig});

        // Verify the signature by the `fromId` account, that the username transfer is authorized.
        _verifyTransferUsernameSig({
            fromId: fromId,
            toId: toId,
            newFromUsername: newFromUsername,
            deadline: fromDeadline,
            sig: fromSig
        });

        idRegistry.transferUsername(fromId, toId, newFromUsername);
    }

    // =============================================================
    //                        CHANGE USERNAME
    // =============================================================

    /// @inheritdoc IIdGateway
    function changeUsername(string calldata newUsername) external payable override whenNotPaused {
        if (msg.value < changeUsernameFee) revert InsufficientFee();

        uint256 id = idRegistry.getIdByAddress(msg.sender);

        _validateUsername(newUsername);

        idRegistry.changeUsername(id, newUsername);
    }

    /// @inheritdoc IIdGateway
    function changeUsernameFor(uint256 id, string calldata newUsername, uint256 deadline, bytes calldata sig)
        external
        payable
        override
        whenNotPaused
    {
        if (msg.value < changeUsernameFee) revert InsufficientFee();

        _validateUsername(newUsername);

        // Reverts if the signature is invalid
        _verifyChangeUsernameSig({id: id, newUsername: newUsername, deadline: deadline, sig: sig});

        idRegistry.changeUsername(id, newUsername);
    }

    // =============================================================
    //                        RECOVERY LOGIC
    // =============================================================

    /// @inheritdoc IIdGateway
    function changeRecovery(address newRecovery) external payable override whenNotPaused {
        if (msg.value < changeRecoveryFee) revert InsufficientFee();

        uint256 id = idRegistry.getIdByAddress(msg.sender);

        idRegistry.changeRecovery(id, newRecovery);
    }

    /// @inheritdoc IIdGateway
    function changeRecoveryFor(uint256 id, address newRecovery, uint256 deadline, bytes calldata sig)
        external
        payable
        override
        whenNotPaused
    {
        if (msg.value < changeRecoveryFee) revert InsufficientFee();

        _verifyChangeRecoverySig({id: id, newRecovery: newRecovery, deadline: deadline, sig: sig});

        idRegistry.changeRecovery(id, newRecovery);
    }

    /// @inheritdoc IIdGateway
    function recover(uint256 id, address to, uint256 deadline, bytes calldata sig)
        external
        payable
        override
        whenNotPaused
    {
        if (msg.value < recoverFee) revert InsufficientFee();

        // Revert if the caller is not the recovery address
        if (idRegistry.recoveryOf(id) != msg.sender) revert OnlyRecovery();

        _verifyRecoverSig({id: id, to: to, deadline: deadline, signer: to, sig: sig});

        idRegistry.recover(id, to);
    }

    /// @inheritdoc IIdGateway
    function recoverFor(
        uint256 id,
        address to,
        uint256 recoveryDeadline,
        bytes calldata recoverySig,
        uint256 toDeadline,
        bytes calldata toSig
    ) external payable override whenNotPaused {
        if (msg.value < recoverFee) revert InsufficientFee();

        address recovery = idRegistry.recoveryOf(id);
        _verifyRecoverSig({id: id, to: to, deadline: recoveryDeadline, signer: recovery, sig: recoverySig});
        _verifyRecoverSig({id: id, to: to, deadline: toDeadline, signer: to, sig: toSig});

        idRegistry.recover(id, to);
    }

    // =============================================================
    //                      PERMISSIONED ACTIONS
    // =============================================================

    /// @inheritdoc IIdGateway
    function forceTransferUsername(uint256 fromId, uint256 toId, string calldata newFromUsername)
        external
        override
        onlyOwner
    {
        _validateUsername(newFromUsername);
        idRegistry.transferUsername(fromId, toId, newFromUsername);
    }

    /// @inheritdoc IIdGateway
    function forceChangeUsername(uint256 id, string calldata newUsername) external override onlyOwner {
        _validateUsername(newUsername);
        idRegistry.changeUsername(id, newUsername);
    }

    // =============================================================
    //                      USERNAME VALIDATION
    // =============================================================

    /// @inheritdoc IIdGateway
    function checkUsername(string calldata username) external view override returns (bool) {
        _validateUsername(username);
        if (idRegistry.checkIfUsernameExists(username)) revert UsernameAlreadyRegistered();

        return true;
    }

    // =============================================================
    //                  USERNAME VALIDATION HELPERS
    // =============================================================

    /// @dev Validate that a username is:
    //       - is non-empty
    //       - is sufficiently short (<= 16 characters)
    //       - is URL-safe (alphanumeric, underscore)
    function _validateUsername(string calldata username) internal pure {
        // Check that the username is:
        // - at least 1 byte long (non-empty)
        // - no more than 16 bytes (which will be 16 characters assuming ASCII).
        uint256 usernameLength = bytes(username).length;
        if (usernameLength < 1) revert UsernameTooShort();
        if (usernameLength > 16) revert UsernameTooLong();

        // Check that the username is URL-slug-safe.
        bool isValid = LibString.is7BitASCII(username, _ALLOWED_CHARACTERS);
        if (!isValid) revert UsernameContainsInvalidChar();
    }

    // =============================================================
    //                       SIGNATURE HELPERS
    // =============================================================

    /// @dev Verify the EIP712 signature for a registerFor transaction.
    function _verifyRegisterSig(
        address custody,
        string calldata username,
        address recovery,
        uint256 deadline,
        bytes calldata sig
    ) internal {
        bytes32 digest = _hashTypedData(
            keccak256(
                abi.encode(
                    REGISTER_TYPEHASH, custody, keccak256(bytes(username)), recovery, _useNonce(custody), deadline
                )
            )
        );

        _verifySig(digest, custody, deadline, sig);
    }

    /// @dev Verify the EIP712 signature for a transfer(For) transaction.
    function _verifyTransferSig(uint256 id, address to, uint256 deadline, address signer, bytes calldata sig)
        internal
    {
        bytes32 digest = _hashTypedData(keccak256(abi.encode(TRANSFER_TYPEHASH, id, to, _useNonce(signer), deadline)));

        _verifySig(digest, signer, deadline, sig);
    }

    /// @dev Verify the EIP712 signature for a changeUsernameFor transaction.
    function _verifyChangeUsernameSig(uint256 id, string memory newUsername, uint256 deadline, bytes calldata sig)
        internal
    {
        // Needed to get nonce for the user and to verify signature.
        address custody = idRegistry.custodyOf(id);

        bytes32 digest = _hashTypedData(
            keccak256(
                abi.encode(CHANGE_USERNAME_TYPEHASH, id, keccak256(bytes(newUsername)), _useNonce(custody), deadline)
            )
        );

        _verifySig(digest, custody, deadline, sig);
    }

    /// @dev Verify the EIP712 signature from the sender for a transferUsername transaction.
    function _verifyTransferUsernameSig(
        uint256 fromId,
        uint256 toId,
        string calldata newFromUsername,
        uint256 deadline,
        bytes calldata sig
    ) internal {
        // Needed to get nonce for the user and to verify signature.
        address custody = idRegistry.custodyOf(fromId);

        bytes32 digest = _hashTypedData(
            keccak256(
                abi.encode(
                    TRANSFER_USERNAME_TYPEHASH,
                    fromId,
                    toId,
                    keccak256(bytes(newFromUsername)),
                    _useNonce(custody),
                    deadline
                )
            )
        );

        _verifySig(digest, custody, deadline, sig);
    }

    /// @dev Verify the EIP712 signature for a changeRecoveryFor transaction.
    function _verifyChangeRecoverySig(uint256 id, address newRecovery, uint256 deadline, bytes calldata sig) internal {
        // Needed to get nonce for the user and to verify signature.
        address custody = idRegistry.custodyOf(id);

        bytes32 digest = _hashTypedData(
            keccak256(abi.encode(CHANGE_RECOVERY_TYPEHASH, id, newRecovery, _useNonce(custody), deadline))
        );

        _verifySig(digest, custody, deadline, sig);
    }

    /// @dev Verify the EIP712 signature for a recover transaction.
    function _verifyRecoverSig(uint256 id, address to, uint256 deadline, address signer, bytes calldata sig) internal {
        bytes32 digest = _hashTypedData(keccak256(abi.encode(RECOVER_TYPEHASH, id, to, _useNonce(signer), deadline)));

        _verifySig(digest, signer, deadline, sig);
    }

    // =============================================================
    //                      FEE MANAGEMENT
    // =============================================================

    /// @inheritdoc IIdGateway
    function setFees(
        uint256 registerFee_,
        uint256 transferFee_,
        uint256 transferUsernameFee_,
        uint256 changeUsernameFee_,
        uint256 changeRecoveryFee_,
        uint256 recoverFee_
    ) external override onlyOwner {
        registerFee = registerFee_;
        transferFee = transferFee_;
        transferUsernameFee = transferUsernameFee_;
        changeUsernameFee = changeUsernameFee_;
        changeRecoveryFee = changeRecoveryFee_;
        recoverFee = recoverFee_;

        emit RegisterFeeSet(registerFee_);
        emit TransferFeeSet(transferFee_);
        emit TransferUsernameFeeSet(transferUsernameFee_);
        emit ChangeUsernameFeeSet(changeUsernameFee_);
        emit ChangeRecoveryFeeSet(changeRecoveryFee_);
        emit RecoverFeeSet(recoverFee_);
    }

    // =============================================================
    //                          UUPS
    // =============================================================

    // solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
