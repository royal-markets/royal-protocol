// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IProvenanceGateway} from "./interfaces/IProvenanceGateway.sol";
import {IProvenanceRegistry} from "./interfaces/IProvenanceRegistry.sol";
import {IIdRegistry} from "./interfaces/IIdRegistry.sol";

import {Withdrawable} from "./abstract/Withdrawable.sol";
import {EIP712} from "./abstract/EIP712.sol";
import {Nonces} from "./abstract/Nonces.sol";

import {SignatureCheckerLib} from "solady/utils/SignatureCheckerLib.sol";
import {IERC721} from "@openzeppelin/contracts/interfaces/IERC721.sol";

/**
 * @title RoyalProtocol ProvenanceGateway
 *
 * @notice An abstraction layer around registration for the ProvenanceRegistry.
 *         Having this abstraction layer allows for switching registration logic in the future if needed.
 */
contract ProvenanceGateway is IProvenanceGateway, Withdrawable, EIP712, Nonces {
    // =============================================================
    //                           CONSTANTS
    // =============================================================

    /* solhint-disable gas-small-strings */

    /// @inheritdoc IProvenanceGateway
    string public constant VERSION = "2024-07-29";

    /// @inheritdoc IProvenanceGateway
    bytes32 public constant REGISTER_TYPEHASH = keccak256(
        "Register(uint256 originatorId,bytes32 contentHash,address nftContract,uint256 nftTokenId,uint256 nonce,uint256 deadline)"
    );

    /* solhint-enable gas-small-strings */

    // =============================================================
    //                           IMMUTABLES
    // =============================================================

    /// @inheritdoc IProvenanceGateway
    IProvenanceRegistry public immutable PROVENANCE_REGISTRY;

    // =============================================================
    //                           STORAGE
    // =============================================================

    /// @inheritdoc IProvenanceGateway
    IIdRegistry public idRegistry;

    /// @inheritdoc IProvenanceGateway
    bool public idRegistryFrozen;

    // =============================================================
    //                          CONSTRUCTOR
    // =============================================================

    /**
     * @notice Configure ProvenanceRegistry and ownership of the contract.
     *
     * @param provenanceRegistry_ The RoyalProtocol ProvenanceRegistry contract address.
     * @param initialOwner_ The initial owner of the contract.
     */
    constructor(IProvenanceRegistry provenanceRegistry_, IIdRegistry idRegistry_, address initialOwner_) {
        PROVENANCE_REGISTRY = provenanceRegistry_;
        idRegistry = idRegistry_;
        _initializeOwner(initialOwner_);
    }

    // =============================================================
    //                          EIP712
    // =============================================================

    /// @dev Configure the EIP712 name and version for the domain separator.
    function _domainNameAndVersion() internal pure override returns (string memory name, string memory version) {
        name = "RoyalProtocol_ProvenanceGateway";
        version = "1";
    }

    // =============================================================
    //                          REGISTRATION
    // =============================================================

    /// @inheritdoc IProvenanceGateway
    function register(uint256 originatorId, bytes32 contentHash, address nftContract, uint256 nftTokenId)
        external
        override
        whenNotPaused
        returns (uint256 id)
    {
        uint256 registrarId = _validateRegister({
            originatorId: originatorId,
            registrar: msg.sender,
            contentHash: contentHash,
            nftContract: nftContract,
            nftTokenId: nftTokenId,
            withSignature: false
        });

        id = PROVENANCE_REGISTRY.unsafeRegister({
            originatorId: originatorId,
            registrarId: registrarId,
            contentHash: contentHash,
            nftContract: nftContract,
            nftTokenId: nftTokenId
        });
    }

    /// @inheritdoc IProvenanceGateway
    function registerFor(
        uint256 originatorId,
        bytes32 contentHash,
        address nftContract,
        uint256 nftTokenId,
        uint256 deadline,
        bytes calldata sig
    ) external override whenNotPaused returns (uint256 id) {
        uint256 registrarId = _validateRegister({
            originatorId: originatorId,
            registrar: msg.sender,
            contentHash: contentHash,
            nftContract: nftContract,
            nftTokenId: nftTokenId,
            withSignature: true
        });

        _verifyRegisterSig({
            originatorId: originatorId,
            contentHash: contentHash,
            nftContract: nftContract,
            nftTokenId: nftTokenId,
            deadline: deadline,
            sig: sig
        });

        id = PROVENANCE_REGISTRY.unsafeRegister({
            originatorId: originatorId,
            registrarId: registrarId,
            contentHash: contentHash,
            nftContract: nftContract,
            nftTokenId: nftTokenId
        });
    }

    // =============================================================
    //                          ONLY OWNER
    // =============================================================

    /// @inheritdoc IProvenanceGateway
    function setIdRegistry(address idRegistry_) external override onlyOwner {
        if (idRegistryFrozen) revert Frozen();

        emit IdRegistrySet(address(idRegistry), idRegistry_);

        idRegistry = IIdRegistry(idRegistry_);
    }

    /// @inheritdoc IProvenanceGateway
    function freezeIdRegistry() external override onlyOwner {
        if (idRegistryFrozen) revert Frozen();

        emit IdRegistryFrozen(address(idRegistry));

        idRegistryFrozen = true;
    }

    // =============================================================
    //                       VALIDATION HELPER
    // =============================================================

    /**
     * @dev Validate the registration of a new provenance claim.
     *
     * - The originator must have a registered ID.
     * - The registrar must have a registered ID.
     * - The NFT must exist and be owned by the originator (held by the custody or operator address).
     * - The NFT token must not already be associated with an existing ProvenanceClaim.
     * - The originator must not have already registered this contentHash.
     * - The registrar must have permission to register provenance on behalf of the originator.
     */
    function _validateRegister(
        uint256 originatorId,
        address registrar,
        bytes32 contentHash,
        address nftContract,
        uint256 nftTokenId,
        bool withSignature
    ) internal view returns (uint256 registrarId) {
        // Check that the originator exists in the idRegistry
        if (idRegistry.custodyOf(originatorId) == address(0)) revert OriginatorDoesNotExist();

        // Check that the registrar exists in the idRegistry
        registrarId = idRegistry.idOf(registrar);
        if (registrarId == 0) revert RegistrarDoesNotExist();

        // Check that the NFT exists and is owned by the originator
        if (idRegistry.idOf(IERC721(nftContract).ownerOf(nftTokenId)) != originatorId) {
            revert NftNotOwnedByOriginator();
        }

        // Check that the NFT token has not already been used
        if (PROVENANCE_REGISTRY.provenanceClaimIdOfNftToken(nftContract, nftTokenId) > 0) revert NftTokenAlreadyUsed();

        // Check that the originator has not already registered this contentHash previously.
        if (PROVENANCE_REGISTRY.provenanceClaimIdOfOriginatorAndHash(originatorId, contentHash) > 0) {
            revert ContentHashAlreadyRegistered();
        }

        // Check that the registrar has permission to register provenance on behalf of the originator.
        //
        // If there is a signature, the registrar must have permission to act on behalf of the originator for that specific ProvenanceClaim.
        // Otherwise, we need to check the IdRegistry delegation to see if the registrar has been delegated.
        if (!withSignature && !idRegistry.canAct(originatorId, registrar, address(this), "registerProvenance")) {
            revert Unauthorized();
        }
    }

    // =============================================================
    //                       SIGNATURE HELPERS
    // =============================================================

    /// @dev Verify the EIP712 signature for a registerFor transaction.
    ///
    /// NOTE: This follows a slightly different pattern than other _verifyXSig functions,
    ///       because this signature can be valid from either the custody OR operator wallet.
    function _verifyRegisterSig(
        uint256 originatorId,
        bytes32 contentHash,
        address nftContract,
        uint256 nftTokenId,
        uint256 deadline,
        bytes calldata sig
    ) internal {
        if (block.timestamp > deadline) revert SignatureExpired();

        address custody = idRegistry.custodyOf(originatorId);
        bytes32 custodyDigest = _hashTypedData(
            keccak256(
                abi.encode(
                    REGISTER_TYPEHASH, originatorId, contentHash, nftContract, nftTokenId, _useNonce(custody), deadline
                )
            )
        );

        bool isValid = SignatureCheckerLib.isValidSignatureNowCalldata(custody, custodyDigest, sig);
        if (isValid) return;

        // Get the operator address if it exists - if it's unset (address(0)), then there's no second digest to check.
        address operator = idRegistry.operatorOf(originatorId);
        if (operator == address(0)) revert InvalidSignature();

        bytes32 operatorDigest = _hashTypedData(
            keccak256(
                abi.encode(
                    REGISTER_TYPEHASH, originatorId, contentHash, nftContract, nftTokenId, _useNonce(operator), deadline
                )
            )
        );

        if (!SignatureCheckerLib.isValidSignatureNowCalldata(operator, operatorDigest, sig)) {
            revert InvalidSignature();
        }
    }
}
