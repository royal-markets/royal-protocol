// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IIdGateway} from "./interfaces/IIdGateway.sol";
import {IIdRegistry} from "./interfaces/IIdRegistry.sol";

import {Withdrawable} from "./abstract/Withdrawable.sol";
import {Signatures} from "./abstract/Signatures.sol";
import {EIP712} from "./abstract/EIP712.sol";
import {Nonces} from "./abstract/Nonces.sol";

/**
 * @title RoyalProtocol IdGateway
 *
 * @notice An abstraction layer around registration for the IdRegistry.
 *         Having this abstraction layer allows for switching registration logic in the future if needed.
 */
contract IdGateway is IIdGateway, Withdrawable, Signatures, EIP712, Nonces {
    // =============================================================
    //                           CONSTANTS
    // =============================================================

    /* solhint-disable gas-small-strings */

    /// @inheritdoc IIdGateway
    string public constant VERSION = "2024-07-29";

    /// @inheritdoc IIdGateway
    bytes32 public constant REGISTER_TYPEHASH = keccak256(
        "Register(address custody,string username,address operator,address recovery,uint256 nonce,uint256 deadline)"
    );

    /* solhint-enable gas-small-strings */

    // =============================================================
    //                           IMMUTABLES
    // =============================================================

    /// @inheritdoc IIdGateway
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
    function register(string calldata username, address operator, address recovery)
        external
        override
        whenNotPaused
        returns (uint256 id)
    {
        id = ID_REGISTRY.register(msg.sender, username, operator, recovery);
    }

    /// @inheritdoc IIdGateway
    function registerFor(
        address custody,
        string calldata username,
        address operator,
        address recovery,
        uint256 deadline,
        bytes calldata sig
    ) external override whenNotPaused returns (uint256 id) {
        // Reverts if the signature is invalid
        _verifyRegisterSig({
            custody: custody,
            username: username,
            operator: operator,
            recovery: recovery,
            deadline: deadline,
            sig: sig
        });

        id = ID_REGISTRY.register(custody, username, operator, recovery);
    }

    // =============================================================
    //                       SIGNATURE HELPERS
    // =============================================================

    /// @dev Verify the EIP712 signature for a registerFor transaction.
    function _verifyRegisterSig(
        address custody,
        string calldata username,
        address operator,
        address recovery,
        uint256 deadline,
        bytes calldata sig
    ) internal {
        bytes32 digest = _hashTypedData(
            keccak256(
                abi.encode(
                    REGISTER_TYPEHASH,
                    custody,
                    keccak256(bytes(username)),
                    operator,
                    recovery,
                    _useNonce(custody),
                    deadline
                )
            )
        );

        _verifySig(digest, custody, deadline, sig);
    }
}
