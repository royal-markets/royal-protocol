// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IProvenanceRegistry {
    // =============================================================
    //                        STRUCTS
    // =============================================================

    /**
     * @notice A provenance claim.
     *
     * @param originatorId The RoyalProtocol ID of the originator. (who created the content which this ProvenanceClaim represents).
     * @param registrarId The RoyalProtocol ID of the registrar. (who registered this ProvenanceClaim on behalf of the originator).
     * @param contentHash The keccak256 hash of the content which this ProvenanceClaim represents.
     *
     * @param nftContract The NFT contract of the associated NFT of this ProvenanceClaim.
     * @param nftTokenId The token ID of the NFT associated with this ProvenanceClaim.
     */
    struct ProvenanceClaim {
        uint256 originatorId;
        uint256 registrarId;
        bytes32 contentHash;
        address nftContract;
        uint256 nftTokenId;
        uint256 blockNumber;
    }

    // =============================================================
    //                           EVENTS
    // =============================================================

    /// @dev Emitted when a new ProvenanceClaim is registered.
    event ProvenanceRegistered(
        uint256 id,
        uint256 indexed originatorId,
        uint256 indexed registrarId,
        bytes32 indexed contentHash,
        address nftContract,
        uint256 nftTokenId
    );

    /// @dev Emitted when the Owner sets the ProvenanceGateway to a new value.
    event ProvenanceGatewaySet(address oldProvenanceGateway, address newProvenanceGateway);

    /// @dev Emitted when the Owner freezes the ProvenanceGateway dependency.
    event ProvenanceGatewayFrozen(address provenanceGateway);

    // =============================================================
    //                          ERRORS
    // =============================================================

    /// @dev Revert when a non-IdGateway address attempts to call a gated function.
    error OnlyProvenanceGateway();

    /// @dev Error emitted when the ProvenanceGateway is frozen and it is attempting to be modified.
    error Frozen();

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

    /// @notice Whether the ProvenanceGateway dependency is permanently frozen.
    function provenanceGatewayFrozen() external view returns (bool);

    /// @notice The last ProvenanceClaim ID that was issued.
    function idCounter() external view returns (uint256);

    /// @notice The ProvenanceClaim ID for a given NFT token.
    function provenanceClaimIdOfNftToken(address nftContract, uint256 nftTokenId) external view returns (uint256);

    /// @notice The ProvenanceClaim ID for a given originator and content hash.
    function provenanceClaimIdOfOriginatorAndHash(uint256 originatorId, bytes32 contentHash)
        external
        view
        returns (uint256);

    // =============================================================
    //                          REGISTRATION
    // =============================================================

    /**
     * @notice Register a new ProvenanceClaim.
     *
     * Requirements:
     * - The ProvenanceRegistry must not be paused.
     * - Only callable by the ProvenanceGateway (validation happens there).
     *
     * @param originatorId The RoyalProtocol ID of the originator.
     * @param registrarId The RoyalProtocol ID of the registrar.
     * @param contentHash The keccak256 hash of the content which this ProvenanceClaim represents.
     * @param nftContract The NFT contract of the associated NFT of this ProvenanceClaim.
     * @param nftTokenId The token ID of the NFT associated with this ProvenanceClaim.
     */
    function unsafeRegister(
        uint256 originatorId,
        uint256 registrarId,
        bytes32 contentHash,
        address nftContract,
        uint256 nftTokenId
    ) external returns (uint256 id);

    // =============================================================
    //                          ONLY OWNER
    // =============================================================

    /// @notice Set the RoyalProtocol ProvenanceGateway contract.
    function setProvenanceGateway(address provenanceGateway_) external;

    /// @notice Freeze the ProvenanceGateway dependency.
    function freezeProvenanceGateway() external;

    // =============================================================
    //                          STRUCT GETTERS
    // =============================================================

    /// @notice The ProvenanceClaim for a given ID.
    ///
    /// Need a separate helper for this because public mappings just return a tuple rather than a struct.
    function provenanceClaim(uint256 id) external view returns (ProvenanceClaim memory);
}
