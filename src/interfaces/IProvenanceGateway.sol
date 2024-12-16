// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IProvenanceRegistry} from "./IProvenanceRegistry.sol";
import {IIdRegistry} from "./IIdRegistry.sol";

interface IProvenanceGateway {
    // NOTE: None of these events are actually emitted by ProvenanceGateway, but because they are emitted when calling the ProvenanceRegistry,
    //       they are included here so that ProvenanceGateway's ABI includes them.
    //
    // =============================================================
    //                           EVENTS
    // =============================================================

    /// @dev Emitted when a new ProvenanceClaim is registered.
    event ProvenanceRegistered(
        uint256 id, uint256 indexed originatorId, uint256 indexed registrarId, bytes32 indexed contentHash
    );

    /// @dev Emitted when an NFT is assigned to an existing ProvenanceClaim without an NFT.
    event NftAssigned(uint256 indexed provenanceClaimId, address indexed nftContract, uint256 nftTokenId);

    /// @dev Emitted when the RegisterFee for registering a ProvenanceClaim is updated.
    event RegisterFeeSet(uint256 fee);

    // =============================================================
    //                          ERRORS
    // =============================================================

    // The following errors are potentially emitted by the ProvenanceRegistry contract,
    // but included here for convenience.

    /// @dev Error emitted when the originator has no RoyalProtocol ID.
    error OriginatorDoesNotExist();

    /// @dev Error emitted when the registrar has no RoyalProtocol ID.
    error RegistrarDoesNotExist();

    /// @dev Revert when an originator has already registered a given bytes32 contentHash.
    error ContentHashAlreadyRegistered();

    /// @dev Revert when an NFT tokenId was provided on registration sbut the contract address was not.
    error NftContractRequired();

    /// @dev Error emitted when a ProvenanceClaim is not found.
    error ProvenanceClaimNotFound();

    /// @dev Error emitted when the ProvenanceClaim already has an assigned NFT.
    error NftAlreadyAssigned();

    /// @dev Error emitted when the NFT token is not owned by the originator.
    error NftNotOwnedByOriginator();

    /// @dev Error emitted when the NFT token has already been used by a different ProvenanceClaim.
    error NftTokenAlreadyUsed();

    /// @dev Revert when the msg.value is insufficient to cover the associated fee.
    error InsufficientFee();

    // =============================================================
    //                           CONSTANTS
    // =============================================================

    // Disable rule because we include function interfaces for constants/immutables that should stylistically be UPPERCASED.
    /* solhint-disable func-name-mixedcase */

    /// @notice Contract version specified in the RoyalProtocol version scheme.
    function VERSION() external view returns (string memory);

    /// @notice The EIP712 typehash for Register signatures (for registering ProvenanceClaims).
    function REGISTER_TYPEHASH() external view returns (bytes32);

    /// @notice The EIP712 typehash for AssignNft signatures (for assigning NFTs to an existing ProvenanceClaim without an assigned NFT).
    function ASSIGN_NFT_TYPEHASH() external view returns (bytes32);

    /* solhint-enable func-name-mixedcase */

    // =============================================================
    //                           STORAGE
    // =============================================================

    /// @notice The RoyalProtocol ProvenanceRegistry contract.
    function provenanceRegistry() external view returns (IProvenanceRegistry);

    /// @notice The RoyalProtocol IdRegistry contract.
    function idRegistry() external view returns (IIdRegistry);

    /// @notice The fee (in wei) to register a new ProvenanceClaim.
    function registerFee() external view returns (uint256);

    // =============================================================
    //                        INITIALIZATION
    // =============================================================

    /**
     * @notice Configure ProvenanceRegistry and ownership of the contract.
     *
     * @param provenanceRegistry_ The RoyalProtocol ProvenanceRegistry contract address.
     * @param idRegistry_ The RoyalProtocol IdRegistry contract address.
     * @param initialOwner_ The initial owner of the contract.
     */
    function initialize(IProvenanceRegistry provenanceRegistry_, IIdRegistry idRegistry_, address initialOwner_)
        external;

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
     * - The `msg.value` must be >= the registerFee.
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
        payable
        returns (uint256 id);

    /**
     * @notice Register a new ProvenanceClaim.
     *
     * Requirements:
     * - The originatorId must be valid.
     * - The caller (registrar) must have a valid RoyalProtocol ID.
     * - The NFT token must be owned by the originator.
     * - The NFT token must not have been used in a ProvenanceClaim before.
     * - The `msg.value` must be >= the registerFee.
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
     * @param sig The EIP712 "Register" signature from the originator. (Signed by the custody address).
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
    ) external payable returns (uint256 id);

    // =============================================================
    //                          ASSIGNING NFTs
    // =============================================================

    /**
     * @notice Assign an NFT to an existing ProvenanceClaim without an assigned NFT.
     *
     * Requirements:
     * - The ProvenanceClaim ID must be valid.
     * - The ProvenanceClaim must not already have an NFT assigned.
     * - The NFT token must be owned by the originator.
     * - The NFT token must not have been used in a ProvenanceClaim before.
     * - The assigner must have permission to assign an NFT on behalf of the originator.
     *
     * @param provenanceClaimId The RoyalProtocol ProvenanceClaim ID to assign an NFT to.
     * @param nftContract The NFT contract to associate with this ProvenanceClaim.
     * @param nftTokenId The token ID of the NFT to associate with this ProvenanceClaim.
     */
    function assignNft(uint256 provenanceClaimId, address nftContract, uint256 nftTokenId) external payable;

    /**
     * @notice Assign an NFT to an existing ProvenanceClaim without an assigned NFT.
     *
     * Requirements:
     * - The ProvenanceClaim ID must be valid.
     * - The ProvenanceClaim must not already have an NFT assigned.
     * - The NFT token must be owned by the originator.
     * - The NFT token must not have been used in a ProvenanceClaim before.
     *
     * NOTE: The assigner here doesn't need to be delegated on the delegateRegistry,
     *       because having an EIP712 signature is enough to prove that the assigner
     *       has permission to assign an NFT to **this** provenance claim on behalf of the originator.
     *
     * @param provenanceClaimId The RoyalProtocol ProvenanceClaim ID to assign an NFT to.
     * @param nftContract The NFT contract to associate with this ProvenanceClaim.
     * @param nftTokenId The token ID of the NFT to associate with this ProvenanceClaim.
     * @param deadline The expiration timestamp for the signature.
     * @param sig The EIP712 "AssignNft" signature from the originator. (Signed by the custody address).
     */
    function assignNftFor(
        uint256 provenanceClaimId,
        address nftContract,
        uint256 nftTokenId,
        uint256 deadline,
        bytes calldata sig
    ) external payable;

    // =============================================================
    //                      FEE MANAGEMENT
    // =============================================================

    /**
     * @notice Updates the fee to register a new ProvenanceClaim.
     *
     * Requirements:
     * - Only callable by the owner.
     *
     * @param fee The new fee in wei to register a ProvenanceClaim.
     */
    function setRegisterFee(uint256 fee) external;
}
