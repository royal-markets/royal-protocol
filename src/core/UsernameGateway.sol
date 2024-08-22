// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IUsernameGateway} from "./interfaces/IUsernameGateway.sol";
import {IIdRegistry} from "./interfaces/IIdRegistry.sol";

import {LibString} from "solady/utils/LibString.sol";

import {Withdrawable} from "./abstract/Withdrawable.sol";
import {Signatures} from "./abstract/Signatures.sol";
import {EIP712} from "./abstract/EIP712.sol";
import {Nonces} from "./abstract/Nonces.sol";

/**
 * @title RoyalProtocol UsernameGateway
 *
 * @notice An abstraction layer around username logic for the IdRegistry.
 *         Having this abstraction layer allows for switching username logic in the future if needed.
 */
contract UsernameGateway is IUsernameGateway, Withdrawable, Signatures, EIP712, Nonces {
    // =============================================================
    //                           CONSTANTS
    // =============================================================

    /* solhint-disable gas-small-strings */

    /// @inheritdoc IUsernameGateway
    string public constant VERSION = "2024-08-22";

    /// @inheritdoc IUsernameGateway
    bytes32 public constant TRANSFER_USERNAME_TYPEHASH =
        keccak256("TransferUsername(uint256 fromId,uint256 toId,string newFromUsername,uint256 nonce,uint256 deadline)");

    /// @inheritdoc IUsernameGateway
    bytes32 public constant CHANGE_USERNAME_TYPEHASH =
        keccak256("ChangeUsername(uint256 id,string newUsername,uint256 nonce,uint256 deadline)");

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
    //                           IMMUTABLES
    // =============================================================

    /// @inheritdoc IUsernameGateway
    IIdRegistry public immutable ID_REGISTRY;

    // =============================================================
    //                          CONSTRUCTOR
    // =============================================================

    /**
     * @notice Configure IdRegistry and ownership of the contract.
     *
     * @param idRegistry_ The RoyalProtocol IdRegistry contract address.
     * @param initialOwner_ The initial owner of the contract.
     */
    constructor(IIdRegistry idRegistry_, address initialOwner_) {
        ID_REGISTRY = idRegistry_;
        _initializeOwner(initialOwner_);
    }

    // =============================================================
    //                            EIP712
    // =============================================================

    /// @dev Configure the EIP712 name and version for the domain separator.
    function _domainNameAndVersion() internal pure override returns (string memory name, string memory version) {
        name = "RoyalProtocol_UsernameGateway";
        version = "1";
    }

    // =============================================================
    //                       TRANSFER USERNAME
    // =============================================================

    /// @inheritdoc IUsernameGateway
    function transferUsername(uint256 toId, string calldata newFromUsername, uint256 toDeadline, bytes calldata toSig)
        external
        override
        whenNotPaused
    {
        uint256 fromId = ID_REGISTRY.idOf(msg.sender);
        if (ID_REGISTRY.custodyOf(fromId) != msg.sender) revert OnlyCustody();

        _validateUsername(newFromUsername);

        // Verify that the current username of `fromId` is what the `toId` agreed to receive.
        string memory transferredUsername = ID_REGISTRY.usernameOf(fromId);
        _verifyChangeUsernameSig({id: toId, newUsername: transferredUsername, deadline: toDeadline, sig: toSig});

        ID_REGISTRY.unsafeTransferUsername(fromId, toId, newFromUsername);
    }

    /// @inheritdoc IUsernameGateway
    function transferUsernameFor(
        uint256 fromId,
        uint256 toId,
        string calldata newFromUsername,
        uint256 fromDeadline,
        bytes calldata fromSig,
        uint256 toDeadline,
        bytes calldata toSig
    ) external override whenNotPaused {
        // Validate the new username.
        _validateUsername(newFromUsername);

        // Verify the signature by the `toId` account,
        // that the current username of `fromId` is the username the `toId` agreed to receive.
        string memory transferredUsername = ID_REGISTRY.usernameOf(fromId);
        _verifyChangeUsernameSig({id: toId, newUsername: transferredUsername, deadline: toDeadline, sig: toSig});

        // Verify the signature by the `fromId` account, that the username transfer is authorized.
        _verifyTransferUsernameSig({
            fromId: fromId,
            toId: toId,
            newFromUsername: newFromUsername,
            deadline: fromDeadline,
            sig: fromSig
        });

        ID_REGISTRY.unsafeTransferUsername(fromId, toId, newFromUsername);
    }

    // =============================================================
    //                        CHANGE USERNAME
    // =============================================================

    /// @inheritdoc IUsernameGateway
    function changeUsername(string calldata newUsername) external override whenNotPaused {
        uint256 id = ID_REGISTRY.idOf(msg.sender);
        if (ID_REGISTRY.custodyOf(id) != msg.sender) revert OnlyCustody();

        _validateUsername(newUsername);

        ID_REGISTRY.unsafeChangeUsername(id, newUsername);
    }

    /// @inheritdoc IUsernameGateway
    function changeUsernameFor(uint256 id, string calldata newUsername, uint256 deadline, bytes calldata sig)
        external
        override
        whenNotPaused
    {
        _validateUsername(newUsername);

        // Reverts if the signature is invalid
        _verifyChangeUsernameSig({id: id, newUsername: newUsername, deadline: deadline, sig: sig});

        ID_REGISTRY.unsafeChangeUsername(id, newUsername);
    }

    // =============================================================
    //                      PERMISSIONED ACTIONS
    // =============================================================

    /// @inheritdoc IUsernameGateway
    function forceTransferUsername(uint256 fromId, uint256 toId, string calldata newFromUsername)
        external
        override
        onlyOwner
    {
        _validateUsername(newFromUsername);
        ID_REGISTRY.unsafeTransferUsername(fromId, toId, newFromUsername);
    }

    /// @inheritdoc IUsernameGateway
    function forceChangeUsername(uint256 id, string calldata newUsername) external override onlyOwner {
        _validateUsername(newUsername);
        ID_REGISTRY.unsafeChangeUsername(id, newUsername);
    }

    // =============================================================
    //                      USERNAME VALIDATION
    // =============================================================

    /// @inheritdoc IUsernameGateway
    function checkUsername(string calldata username) external view override returns (bool) {
        _validateUsername(username);
        return true;
    }

    // =============================================================
    //                  USERNAME VALIDATION HELPERS
    // =============================================================

    /// @dev Validate that a username is:
    ///      - unique, and not already in use
    //       - is sufficiently short (<= 16 characters)
    //       -  is URL-safe (alphanumeric, hyphen, underscore)
    function _validateUsername(string calldata username) internal view {
        // Cannot register a username that is already in use.
        if (ID_REGISTRY.idOfUsernameHash(keccak256(bytes(LibString.lower(username)))) != 0) {
            revert UsernameAlreadyRegistered();
        }

        // Check that the username is:
        // - no more than 16 bytes (which will be 16 characters assuming ASCII).
        // - no less than 1 bytes (which will be 1 characters assuming ASCII).
        uint256 usernameLength = bytes(username).length;
        if (usernameLength > 16) revert UsernameTooLong();
        if (usernameLength < 1) revert UsernameTooShort();

        // Check that the username is URL-slug-safe.
        bool isValid = LibString.is7BitASCII(username, _ALLOWED_CHARACTERS);
        if (!isValid) revert UsernameContainsInvalidChar();
    }

    // =============================================================
    //                       SIGNATURE HELPERS
    // =============================================================

    /// @dev Verify the EIP712 signature for a changeUsernameFor transaction.
    function _verifyChangeUsernameSig(uint256 id, string memory newUsername, uint256 deadline, bytes calldata sig)
        internal
    {
        // Needed to get nonce for the user and to verify signature.
        address custody = ID_REGISTRY.custodyOf(id);

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
        address custody = ID_REGISTRY.custodyOf(fromId);

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
}
