// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IIdRegistry} from "./IIdRegistry.sol";

interface IProvenanceRegistry {
    // =============================================================
    //                        STRUCTS
    // =============================================================

    /// @dev A ProvenanceClaim without the ID field, used internally for storage.
    struct InternalProvenanceClaim {
        uint256 originatorId;
        uint256 registrarId;
        bytes32 contentHash;
        address nftContract;
        uint256 nftTokenId;
        uint256 blockNumber;
    }

    /**
     * @notice A provenance claim.
     *
     * @param id The ProvenanceClaim ID.
     * @param originatorId The RoyalProtocol ID of the originator. (who created the content which this ProvenanceClaim represents).
     * @param registrarId The RoyalProtocol ID of the registrar. (who registered this ProvenanceClaim on behalf of the originator).
     * @param contentHash The blake3 hash of the content which this ProvenanceClaim represents.
     *
     * @param nftContract The NFT contract of the associated NFT of this ProvenanceClaim (optional).
     * @param nftTokenId The token ID of the NFT associated with this ProvenanceClaim (optional).
     *
     * @param blockNumber The block number at which this ProvenanceClaim was registered.
     */
    struct ProvenanceClaim {
        uint256 id;
        uint256 originatorId;
        uint256 registrarId;
        bytes32 contentHash;
        address nftContract;
        uint256 nftTokenId;
        uint256 blockNumber;
    }

    /// @dev Struct argument for admin bulk register function, for migrating data.
    struct BulkRegisterData {
        uint256 originatorId;
        uint256 registrarId;
        bytes32 contentHash;
        address nftContract;
        uint256 nftTokenId;
    }

    // =============================================================
    //                           EVENTS
    // =============================================================

    /// @dev Emitted when a new ProvenanceClaim is registered.
    event ProvenanceRegistered(
        uint256 id, uint256 indexed originatorId, uint256 indexed registrarId, bytes32 indexed contentHash
    );

    /// @dev Emitted when an NFT is assigned to an existing ProvenanceClaim without an NFT.
    event NftAssigned(uint256 indexed provenanceClaimId, address indexed nftContract, uint256 nftTokenId);

    /// @dev Emitted when the Owner sets the ProvenanceGateway to a new value.
    event ProvenanceGatewaySet(address oldProvenanceGateway, address newProvenanceGateway);

    // =============================================================
    //                          ERRORS
    // =============================================================

    /// @dev Revert when a non-IdGateway address attempts to call a gated function.
    error OnlyProvenanceGateway();

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

    /* solhint-disable func-name-mixedcase */
    // =============================================================
    //                        CONSTANTS
    // =============================================================

    /// @notice Contract version specified in the RoyalProtocol version scheme.
    function VERSION() external view returns (string memory);

    /* solhint-enable func-name-mixedcase */

    // =============================================================
    //                           STORAGE
    // =============================================================

    /// @notice The ProvenanceGateway contract for the RoyalProtocol.
    function provenanceGateway() external view returns (address);

    /// @notice The IdRegistry contract for the RoyalProtocol.
    function idRegistry() external view returns (IIdRegistry);

    /// @notice The last ProvenanceClaim ID that was issued.
    function idCounter() external view returns (uint256);

    /// @notice The ProvenanceClaim ID for a given NFT token. (If one has been associated).
    function provenanceClaimIdOfNftToken(address nftContract, uint256 nftTokenId) external view returns (uint256);

    /// @notice The ProvenanceClaim ID for a given originator and content hash.
    function provenanceClaimIdOfOriginatorAndHash(uint256 originatorId, bytes32 contentHash)
        external
        view
        returns (uint256);

    // =============================================================
    //                        INITIALIZATION
    // =============================================================

    /**
     * @notice Initialize the IdRegistry contract with the provided `migrator_` and `initialOwner_`.
     *
     * @param idRegistry_ The IdRegistry of the RoyalProtocol.
     * @param migrator_ The migrator of the contract.
     * @param initialOwner_ The initial owner of the contract.
     */
    function initialize(IIdRegistry idRegistry_, address migrator_, address initialOwner_) external;

    // =============================================================
    //                          REGISTRATION
    // =============================================================

    /**
     * @notice Register a new ProvenanceClaim.
     *
     * Requirements:
     * - The ProvenanceRegistry must not be paused.
     * - Only callable by the ProvenanceGateway (validation happens there).
     * - The data must be valid.
     *
     * @param originatorId The RoyalProtocol ID of the originator.
     * @param registrarId The RoyalProtocol ID of the registrar.
     * @param contentHash The blake3 hash of the content which this ProvenanceClaim represents.
     * @param nftContract The NFT contract of the associated NFT of this ProvenanceClaim. (Optional)
     * @param nftTokenId The token ID of the NFT associated with this ProvenanceClaim. (Optional - but required if `nftContract` is included.)
     */
    function register(
        uint256 originatorId,
        uint256 registrarId,
        bytes32 contentHash,
        address nftContract,
        uint256 nftTokenId
    ) external returns (uint256 id);

    /**
     * @notice Assign an NFT to a ProvenanceClaim.
     *
     * Requirements:
     * - The ProvenanceRegistry must not be paused.
     * - Only callable by the ProvenanceGateway (validation happens there).
     * - The data must be valid.
     *
     * @param provenanceClaimId The RoyalProtocol ProvenanceClaim ID we wish to attach an NFT to.
     * @param nftContract The NFT contract of the NFT that will be associated with this ProvenanceClaim.
     * @param nftTokenId The token ID of the NFT that will be associated with this ProvenanceClaim.
     */
    function assignNft(uint256 provenanceClaimId, address nftContract, uint256 nftTokenId) external;

    // =============================================================
    //                          ONLY OWNER
    // =============================================================

    /// @notice Set the RoyalProtocol ProvenanceGateway contract.
    function setProvenanceGateway(address provenanceGateway_) external;

    // =============================================================
    //                          MIGRATION
    // =============================================================

    /// @notice Register a bunch of ProvenanceClaims as part of a migration.
    function bulkRegisterProvenanceClaims(BulkRegisterData[] calldata data) external;

    // =============================================================
    //                          VIEW FUNCTIONS
    // =============================================================

    /// @notice The ProvenanceClaim for a given ID.
    ///
    /// Need a separate helper for this because public mappings just return a tuple rather than a struct.
    function provenanceClaim(uint256 id) external view returns (ProvenanceClaim memory);

    /// @notice The ProvenanceClaim for a given originator ID and blake3 contentHash.
    function provenanceClaimOfOriginatorAndHash(uint256 originatorId, bytes32 contentHash)
        external
        view
        returns (ProvenanceClaim memory);

    /// @notice The ProvenanceClaim for a given NFT token.
    function provenanceClaimOfNftToken(address nftContract, uint256 nftTokenId)
        external
        view
        returns (ProvenanceClaim memory);
}
