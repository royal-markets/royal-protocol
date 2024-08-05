// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IProvenanceRegistry} from "./interfaces/IProvenanceRegistry.sol";

import {Withdrawable} from "./abstract/Withdrawable.sol";

contract ProvenanceRegistry is IProvenanceRegistry, Withdrawable {
    // =============================================================
    //                           CONSTANTS
    // =============================================================

    /// @inheritdoc IProvenanceRegistry
    string public constant VERSION = "2024-07-29";

    // =============================================================
    //                           STORAGE
    // =============================================================

    /// @inheritdoc IProvenanceRegistry
    address public provenanceGateway;

    /// @inheritdoc IProvenanceRegistry
    bool public provenanceGatewayFrozen;

    /// @inheritdoc IProvenanceRegistry
    uint256 public idCounter = 0;

    /// @inheritdoc IProvenanceRegistry
    mapping(uint256 originatorId => mapping(bytes32 contentHash => uint256 claimId)) public
        provenanceClaimIdOfOriginatorAndHash;

    /// @inheritdoc IProvenanceRegistry
    mapping(address nftContract => mapping(uint256 nftTokenId => uint256 provenanceClaimId)) public
        provenanceClaimIdOfNftToken;

    /// @dev Internal lookup for ProvenanceClaim by ID.
    ///
    /// NOTE: We have a separate helper method to read this externally so we can actually return a struct.
    mapping(uint256 claimId => ProvenanceClaim claim) internal _provenanceClaim;

    // =============================================================
    //                          MODIFIERS
    // =============================================================

    /// @dev Ensures that only the ProvenanceGateway contract can call the function. (for initial registration).
    modifier onlyProvenanceGateway() {
        if (msg.sender != provenanceGateway) revert OnlyProvenanceGateway();

        _;
    }

    // =============================================================
    //                          CONSTRUCTOR
    // =============================================================

    /**
     * @notice Configure ownership of the contract.
     *
     * @param initialOwner_ The initial owner of the contract.
     */
    constructor(address initialOwner_) {
        _initializeOwner(initialOwner_);
    }

    // =============================================================
    //                          REGISTRATION
    // =============================================================

    /// @inheritdoc IProvenanceRegistry
    function unsafeRegister(
        uint256 originatorId,
        uint256 registrarId,
        bytes32 contentHash,
        address nftContract,
        uint256 nftTokenId
    ) external override whenNotPaused onlyProvenanceGateway returns (uint256 id) {
        unchecked {
            id = ++idCounter;
        }

        // Set the provenance claim
        _provenanceClaim[id] = ProvenanceClaim({
            originatorId: originatorId,
            registrarId: registrarId,
            contentHash: contentHash,
            nftContract: nftContract,
            nftTokenId: nftTokenId,
            blockNumber: block.number
        });

        // Mark the originator and content hash as used
        provenanceClaimIdOfOriginatorAndHash[originatorId][contentHash] = id;

        // Mark the NFT token as used, if included
        if (nftContract != address(0)) {
            provenanceClaimIdOfNftToken[nftContract][nftTokenId] = id;
        }

        // Emit an event
        emit ProvenanceRegistered({
            id: id,
            originatorId: originatorId,
            registrarId: registrarId,
            contentHash: contentHash,
            nftContract: nftContract,
            nftTokenId: nftTokenId
        });
    }

    /// @inheritdoc IProvenanceRegistry
    function unsafeAssignNft(uint256 provenanceClaimId, address nftContract, uint256 nftTokenId)
        external
        override
        whenNotPaused
        onlyProvenanceGateway
    {
        // Get the existing provenance claim
        ProvenanceClaim storage pc = _provenanceClaim[provenanceClaimId];

        // Set the provenance claim NFT data
        pc.nftContract = nftContract;
        pc.nftTokenId = nftTokenId;

        // Mark the NFT token as used
        provenanceClaimIdOfNftToken[nftContract][nftTokenId] = provenanceClaimId;

        // Emit an event
        emit NftAssigned({provenanceClaimId: provenanceClaimId, nftContract: nftContract, nftTokenId: nftTokenId});
    }

    // =============================================================
    //                          ONLY OWNER
    // =============================================================

    /// @inheritdoc IProvenanceRegistry
    function setProvenanceGateway(address provenanceGateway_) external override onlyOwner {
        if (provenanceGatewayFrozen) revert Frozen();

        emit ProvenanceGatewaySet(provenanceGateway, provenanceGateway_);

        provenanceGateway = provenanceGateway_;
    }

    /// @inheritdoc IProvenanceRegistry
    function freezeProvenanceGateway() external override onlyOwner {
        if (provenanceGatewayFrozen) revert Frozen();

        emit ProvenanceGatewayFrozen(provenanceGateway);

        provenanceGatewayFrozen = true;
    }

    // =============================================================
    //                          STRUCT GETTER
    // =============================================================

    /// @inheritdoc IProvenanceRegistry
    function provenanceClaim(uint256 id) external view override returns (ProvenanceClaim memory) {
        return _provenanceClaim[id];
    }
}
