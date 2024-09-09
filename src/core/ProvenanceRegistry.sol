// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IProvenanceRegistry} from "./interfaces/IProvenanceRegistry.sol";

import {Migration} from "./abstract/Migration.sol";
import {Initializable} from "solady/utils/Initializable.sol";
import {UUPSUpgradeable} from "solady/utils/UUPSUpgradeable.sol";

import {IIdRegistry} from "./interfaces/IIdRegistry.sol";
import {IERC721} from "@openzeppelin/contracts/interfaces/IERC721.sol";

// We trust the IdRegistry to not DoS us when we call it in a loop.
// slither-disable-start calls-loop

contract ProvenanceRegistry is IProvenanceRegistry, Migration, Initializable, UUPSUpgradeable {
    // =============================================================
    //                           CONSTANTS
    // =============================================================

    /// @inheritdoc IProvenanceRegistry
    string public constant VERSION = "2024-09-07";

    // =============================================================
    //                           STORAGE
    // =============================================================

    /// @inheritdoc IProvenanceRegistry
    address public provenanceGateway;

    /// @inheritdoc IProvenanceRegistry
    IIdRegistry public idRegistry;

    /// @inheritdoc IProvenanceRegistry
    uint256 public idCounter;

    /// @inheritdoc IProvenanceRegistry
    mapping(uint256 originatorId => mapping(bytes32 contentHash => uint256 claimId)) public
        provenanceClaimIdOfOriginatorAndHash;

    /// @inheritdoc IProvenanceRegistry
    mapping(address nftContract => mapping(uint256 nftTokenId => uint256 claimId)) public provenanceClaimIdOfNftToken;

    /// @dev Internal lookup for ProvenanceClaim by ID.
    ///
    /// NOTE: We have a separate helper method to read this externally so we can actually return a struct.
    mapping(uint256 claimId => ProvenanceClaim claim) internal _provenanceClaim;

    // =============================================================
    //                          MODIFIERS
    // =============================================================

    /// @dev Ensures that only the ProvenanceGateway contract can call the function.
    modifier onlyProvenanceGateway() {
        if (msg.sender != provenanceGateway) revert OnlyProvenanceGateway();

        _;
    }

    // =============================================================
    //                    CONSTRUCTOR / INITIALIZATION
    // =============================================================

    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Configure ProvenanceRegistry and ownership of the contract.
     *
     * @param idRegistry_ The RoyalProtocol IdRegistry contract address.
     * @param migrator_ The address that can call migration functions on the contract.
     * @param initialOwner_ The initial owner of the contract.
     */
    function initialize(IIdRegistry idRegistry_, address migrator_, address initialOwner_)
        external
        override
        initializer
    {
        idRegistry = idRegistry_;
        _initializeOwner(initialOwner_);
        _initializeMigrator(24 hours, migrator_);
    }

    // =============================================================
    //                          REGISTRATION
    // =============================================================

    /// @inheritdoc IProvenanceRegistry
    function register(
        uint256 originatorId,
        address registrar,
        bytes32 contentHash,
        address nftContract,
        uint256 nftTokenId
    ) public override whenNotPaused onlyProvenanceGateway returns (uint256 id) {
        unchecked {
            id = ++idCounter;
        }

        // Validate the ProvenanceClaim, reverting on invalid data
        uint256 registrarId = _validateRegister({
            originatorId: originatorId,
            registrar: registrar,
            contentHash: contentHash,
            nftContract: nftContract,
            nftTokenId: nftTokenId
        });

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

        // Emit an event for the new ProvenanceClaim
        emit ProvenanceRegistered({
            id: id,
            originatorId: originatorId,
            registrarId: registrarId,
            contentHash: contentHash
        });

        // If an NFT was assigned, emit an event for that as well
        if (nftContract != address(0)) {
            emit NftAssigned({provenanceClaimId: id, nftContract: nftContract, nftTokenId: nftTokenId});
        }
    }

    /// @inheritdoc IProvenanceRegistry
    function assignNft(uint256 provenanceClaimId, address nftContract, uint256 nftTokenId)
        external
        override
        whenNotPaused
        onlyProvenanceGateway
    {
        // Validate the assignment of an NFT to a provenance claim, reverting on invalid data
        _validateAssignNft(provenanceClaimId, nftContract, nftTokenId);

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
        emit ProvenanceGatewaySet(provenanceGateway, provenanceGateway_);

        provenanceGateway = provenanceGateway_;
    }

    // =============================================================
    //                          VALIDATION
    // =============================================================

    /**
     * @dev Validate the registration DATA of a new provenance claim.
     *
     * - The originator must have a registered ID.
     * - The registrar must have a registered ID.
     * - The originator must not have already registered this contentHash.
     * - The NFT must exist and be owned by the originator (held by the custody address).
     * - The NFT token must not already be associated with an existing ProvenanceClaim.
     */
    function _validateRegister(
        uint256 originatorId,
        address registrar,
        bytes32 contentHash,
        address nftContract,
        uint256 nftTokenId
    ) internal view returns (uint256 registrarId) {
        // Check that the originator exists in the ID_REGISTRY
        if (idRegistry.custodyOf(originatorId) == address(0)) revert OriginatorDoesNotExist();

        // Check that the registrar exists in the ID_REGISTRY
        registrarId = idRegistry.idOf(registrar);
        if (registrarId == 0) revert RegistrarDoesNotExist();

        // Check that the originator has not already registered this contentHash previously.
        if (provenanceClaimIdOfOriginatorAndHash[originatorId][contentHash] > 0) {
            revert ContentHashAlreadyRegistered();
        }

        // If an NFT token ID was provided, check that the NFT contract is also provided
        if (nftTokenId > 0 && nftContract == address(0)) revert NftContractRequired();

        // If the NFT is provided:
        if (nftContract != address(0)) {
            _checkNft(originatorId, nftContract, nftTokenId);
        }
    }

    /**
     * @dev Validate the DATA of assigning an NFT to an existing ProvenanceClaim.
     *
     * - The ProvenanceClaim must exist.
     * - The ProvenanceClaim must not have a pre-existing NFT assigned.
     * - The NFT must exist and be owned by the originator (held by the custody address).
     * - The NFT token must not already be associated with an existing ProvenanceClaim.
     */
    function _validateAssignNft(uint256 provenanceClaimId, address nftContract, uint256 nftTokenId) internal view {
        // Check that the provenance claim exists
        if (provenanceClaimId > idCounter) revert ProvenanceClaimNotFound();
        uint256 originatorId = _provenanceClaim[provenanceClaimId].originatorId;

        // Check that the provenance claim does not already have an NFT assigned
        if (_provenanceClaim[provenanceClaimId].nftContract != address(0)) {
            revert NftAlreadyAssigned();
        }

        // NFT contract is required data for assigning an NFT
        if (nftContract == address(0)) revert NftContractRequired();

        // Check that the NFT exists and is owned by the originator
        _checkNft(originatorId, nftContract, nftTokenId);
    }

    /**
     * @dev Validate the assignment of an NFT to a provenance claim.
     *
     * - The NFT must exist and be owned by the originator (held by the custody address).
     * - The NFT token must not already be associated with an existing ProvenanceClaim.
     */
    function _checkNft(uint256 originatorId, address nftContract, uint256 nftTokenId) internal view {
        // Check that the NFT exists and is owned by the originator
        if (idRegistry.idOf(IERC721(nftContract).ownerOf(nftTokenId)) != originatorId) {
            revert NftNotOwnedByOriginator();
        }

        // Check that the NFT token has not already been used
        if (provenanceClaimIdOfNftToken[nftContract][nftTokenId] > 0) {
            revert NftTokenAlreadyUsed();
        }
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

                address registrar = idRegistry.custodyOf(d.registrarId);

                register({
                    originatorId: d.originatorId,
                    registrar: registrar,
                    contentHash: d.contentHash,
                    nftContract: d.nftContract,
                    nftTokenId: d.nftTokenId
                });
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

    /// @inheritdoc IProvenanceRegistry
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

    /// @inheritdoc IProvenanceRegistry
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

    // =============================================================
    //                          UUPS
    // =============================================================

    // solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
// slither-disable-end calls-loop
