// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IProvenanceRegistry} from "./interfaces/IProvenanceRegistry.sol";

import {Migration} from "./abstract/Migration.sol";

// TODO: Add Migration
contract ProvenanceRegistry is IProvenanceRegistry, Migration {
    // =============================================================
    //                           CONSTANTS
    // =============================================================

    /// @inheritdoc IProvenanceRegistry
    string public constant VERSION = "2024-08-22";

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
     * @param migrator_ The migrator contract address.
     * @param initialOwner_ The initial owner of the contract.
     */
    constructor(address migrator_, address initialOwner_) Migration(24 hours, migrator_, initialOwner_) {}

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
    ) public override whenNotPaused onlyProvenanceGateway returns (uint256 id) {
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
            contentHash: contentHash
        });

        if (nftContract != address(0)) {
            emit NftAssigned({provenanceClaimId: id, nftContract: nftContract, nftTokenId: nftTokenId});
        }
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
    //                          MIGRATION
    // =============================================================

    /// @inheritdoc IProvenanceRegistry
    function bulkRegisterProvenanceClaims(BulkRegisterData[] calldata data) external override onlyMigrator {
        uint256 length = data.length;
        unchecked {
            for (uint256 i = 0; i < length; i++) {
                BulkRegisterData calldata d = data[i];

                // NOTE: There is no validation here! We blindly trust the migrator to provide good data.
                unsafeRegister(d.originatorId, d.registrarId, d.contentHash, d.nftContract, d.nftTokenId);
            }
        }
    }

    // =============================================================
    //                          VIEW FUNCTIONS
    // =============================================================

    /// @inheritdoc IProvenanceRegistry
    function provenanceClaim(uint256 id) external view override returns (ProvenanceClaim memory) {
        if (id == 0) revert ProvenanceClaimNotFound();
        return _provenanceClaim[id];
    }

    function provenanceClaimOfOriginatorAndHash(uint256 originatorId, bytes32 contentHash)
        external
        view
        override
        returns (ProvenanceClaim memory)
    {
        uint256 id = provenanceClaimIdOfOriginatorAndHash[originatorId][contentHash];

        if (id == 0) revert ProvenanceClaimNotFound();
        return _provenanceClaim[id];
    }

    function provenanceClaimOfNftToken(address nftContract, uint256 nftTokenId)
        external
        view
        override
        returns (ProvenanceClaim memory)
    {
        uint256 id = provenanceClaimIdOfNftToken[nftContract][nftTokenId];

        if (id == 0) revert ProvenanceClaimNotFound();
        return _provenanceClaim[id];
    }
}
