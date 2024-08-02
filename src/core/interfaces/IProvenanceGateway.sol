// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IProvenanceRegistry} from "./IProvenanceRegistry.sol";
import {IIdRegistry} from "./IIdRegistry.sol";

interface IProvenanceGateway {
    // =============================================================
    //                           EVENTS
    // =============================================================

    /// @dev Emitted when a new ProvenanceClaim is registered.
    ////
    /// NOTE: This event is not actually emitted by ProvenanceGateway,
    ///       but because it is emitted when calling ProvenanceRegistry.register(),
    ///       it is included here.
    event ProvenanceRegistered(
        uint256 id,
        uint256 indexed originatorId,
        uint256 indexed registrarId,
        bytes32 indexed contentHash,
        address nftContract,
        uint256 nftTokenId
    );

    /// @dev Emitted when the Owner sets the IdRegistry to a new value.
    event IdRegistrySet(address oldIdRegistry, address newIdRegistry);

    /// @dev Emitted when the Owner freezes the IdRegistry dependency.
    event IdRegistryFrozen(address idRegistry);

    // =============================================================
    //                          ERRORS
    // =============================================================

    /// @dev Error emitted when the originator has no RoyalProtocol ID.
    error OriginatorDoesNotExist();

    /// @dev Error emitted when the registrar has no RoyalProtocol ID.
    error RegistrarDoesNotExist();

    /// @dev Error emitted when the NFT token is not owned by the originator.
    error NftNotOwnedByOriginator();

    /// @dev Error emitted when the NFT token has already been used by a different ProvenanceClaim.
    error NftTokenAlreadyUsed();

    /// @dev Revert when an originator has already registered a given bytes32 contentHash.
    error ContentHashAlreadyRegistered();

    /// @dev Revert when the signature provided is invalid.
    error InvalidSignature();

    /// @dev Revert when the block.timestamp is ahead of the signature deadline.
    error SignatureExpired();

    /// @dev Error emitted when the IdRegistry is frozen and it is attempting to be modified.
    error Frozen();

    // =============================================================
    //                           CONSTANTS
    // =============================================================

    // Disable rule because we include function interfaces for constants/immutables that should stylistically be UPPERCASED.
    /* solhint-disable func-name-mixedcase */

    /// @notice Contract version specified in the RoyalProtocol version scheme.
    function VERSION() external view returns (string memory);

    /// @notice The EIP712 typehash for Register signatures (for registering ProvenanceClaims).
    function REGISTER_TYPEHASH() external view returns (bytes32);

    // =============================================================
    //                           IMMUTABLES
    // =============================================================

    /// @notice The RoyalProtocol ProvenanceRegistry contract.
    function PROVENANCE_REGISTRY() external view returns (IProvenanceRegistry);

    /* solhint-enable func-name-mixedcase */

    // =============================================================
    //                           STORAGE
    // =============================================================

    /// @notice The RoyalProtocol IdRegistry contract.
    ///
    /// Intentionally updatable, because the account/identity system might evolve independently of the Provenance system.
    function idRegistry() external view returns (IIdRegistry);

    /// @notice Whether the IdRegistry dependency is permanently frozen.
    function idRegistryFrozen() external view returns (bool);

    // =============================================================
    //                          REGISTRATION
    // =============================================================

    /**
     * @notice Register a new ProvenanceClaim.
     *
     * Requirements:
     * - The originatorId must be valid.
     * - The caller (registrar) must have a valid RoyalProtocol ID.
     * - The NFT token must be owned by the originator.
     * - The NFT token must not have been used in a ProvenanceClaim before.
     * - The registrar must have permission to register provenance on behalf of the originator.
     *
     * @param originatorId The RoyalProtocol ID of the originator.
     * @param contentHash The blake3 hash of the content which this ProvenanceClaim represents.
     * @param nftContract The NFT contract of the associated NFT of this ProvenanceClaim.
     * @param nftTokenId The token ID of the NFT associated with this ProvenanceClaim.
     *
     * @return id The registered ProvenanceClaim ID.
     */
    function register(uint256 originatorId, bytes32 contentHash, address nftContract, uint256 nftTokenId)
        external
        returns (uint256 id);

    /**
     * @notice Register a new ProvenanceClaim.
     *
     * Requirements:
     * - The originatorId must be valid.
     * - The caller (registrar) must have a valid RoyalProtocol ID.
     * - The NFT token must be owned by the originator.
     * - The NFT token must not have been used in a ProvenanceClaim before.
     *
     * NOTE: The registrar here doesn't need to be delegated on the delegateRegistry,
     *       because having an EIP712 signature is enough to prove that the registrar
     *       has permission to register **this** provenance claim on behalf of the originator.
     *
     * @param originatorId The RoyalProtocol ID of the originator.
     * @param contentHash The blake3 hash of the content which this ProvenanceClaim represents.
     * @param nftContract The NFT contract of the associated NFT of this ProvenanceClaim.
     * @param nftTokenId The token ID of the NFT associated with this ProvenanceClaim.
     * @param deadline The expiration timestamp for the signature.
     * @param sig The EIP712 "Register" signature from the originator. (Signed by either custody or operator address).
     *
     * @return id The registered ProvenanceClaim ID.
     */
    function registerFor(
        uint256 originatorId,
        bytes32 contentHash,
        address nftContract,
        uint256 nftTokenId,
        uint256 deadline,
        bytes calldata sig
    ) external returns (uint256 id);

    // =============================================================
    //                      PERMISSIONED ACTIONS
    // =============================================================

    /// @notice Set the IdRegistry contract address.
    function setIdRegistry(address idRegistry_) external;

    /// @notice Freeze the IdRegistry dependency.
    function freezeIdRegistry() external;
}
