// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IProvenanceGateway} from "./interfaces/IProvenanceGateway.sol";
import {IProvenanceRegistry} from "./interfaces/IProvenanceRegistry.sol";
import {IIdRegistry} from "./interfaces/IIdRegistry.sol";

import {Withdrawable} from "./abstract/Withdrawable.sol";
import {Signatures} from "./abstract/Signatures.sol";
import {EIP712} from "./abstract/EIP712.sol";
import {Nonces} from "./abstract/Nonces.sol";
import {Initializable} from "solady/utils/Initializable.sol";
import {UUPSUpgradeable} from "solady/utils/UUPSUpgradeable.sol";

/**
 * @title RoyalProtocol ProvenanceGateway
 *
 * @notice An abstraction layer around registration for the ProvenanceRegistry.
 *         Having this abstraction layer allows for switching registration logic in the future if needed.
 */
contract ProvenanceGateway is
    IProvenanceGateway,
    Withdrawable,
    Signatures,
    EIP712,
    Nonces,
    Initializable,
    UUPSUpgradeable
{
    // =============================================================
    //                           CONSTANTS
    // =============================================================

    /* solhint-disable gas-small-strings */

    /// @inheritdoc IProvenanceGateway
    string public constant VERSION = "2024-09-07";

    /// @inheritdoc IProvenanceGateway
    bytes32 public constant REGISTER_TYPEHASH = keccak256(
        "Register(uint256 originatorId,bytes32 contentHash,address nftContract,uint256 nftTokenId,uint256 nonce,uint256 deadline)"
    );

    /// @inheritdoc IProvenanceGateway
    bytes32 public constant ASSIGN_NFT_TYPEHASH = keccak256(
        "AssignNft(uint256 provenanceClaimId,address nftContract,uint256 nftTokenId,uint256 nonce,uint256 deadline)"
    );

    /* solhint-enable gas-small-strings */

    // =============================================================
    //                           STORAGE
    // =============================================================
    /// @inheritdoc IProvenanceGateway
    IProvenanceRegistry public provenanceRegistry;

    /// @inheritdoc IProvenanceGateway
    IIdRegistry public idRegistry;

    /// @inheritdoc IProvenanceGateway
    uint256 public registerFee;

    // =============================================================
    //                    CONSTRUCTOR / INITIALIZATION
    // =============================================================

    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Configure ProvenanceRegistry and ownership of the contract.
     *
     * @param provenanceRegistry_ The RoyalProtocol ProvenanceRegistry contract address.
     * @param idRegistry_ The RoyalProtocol IdRegistry contract address.
     * @param initialOwner_ The initial owner of the contract.
     */
    function initialize(IProvenanceRegistry provenanceRegistry_, IIdRegistry idRegistry_, address initialOwner_)
        external
        override
        initializer
    {
        provenanceRegistry = provenanceRegistry_;
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
        payable
        override
        whenNotPaused
        returns (uint256 id)
    {
        if (msg.value < registerFee) revert InsufficientFee();

        uint256 registrarId = idRegistry.idOf(msg.sender);

        // Check that the registrar has permission to register provenance on behalf of the originator.
        if (!idRegistry.canAct(originatorId, registrarId, address(this), "registerProvenance")) {
            revert Unauthorized();
        }

        id = provenanceRegistry.register({
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
    ) external payable override whenNotPaused returns (uint256 id) {
        if (msg.value < registerFee) revert InsufficientFee();

        uint256 registrarId = idRegistry.idOf(msg.sender);

        _verifyRegisterSig({
            originatorId: originatorId,
            contentHash: contentHash,
            nftContract: nftContract,
            nftTokenId: nftTokenId,
            deadline: deadline,
            sig: sig
        });

        id = provenanceRegistry.register({
            originatorId: originatorId,
            registrarId: registrarId,
            contentHash: contentHash,
            nftContract: nftContract,
            nftTokenId: nftTokenId
        });
    }

    // =============================================================
    //                          ASSIGNING NFTs
    // =============================================================

    /// @inheritdoc IProvenanceGateway
    function assignNft(uint256 provenanceClaimId, address nftContract, uint256 nftTokenId)
        external
        payable
        override
        whenNotPaused
    {
        uint256 originatorId = provenanceRegistry.provenanceClaim(provenanceClaimId).originatorId;
        uint256 registrarId = idRegistry.idOf(msg.sender);

        // Check that the assigner has permission to assign an NFT to a ProvenanceClaim on behalf of the originator.
        if (!idRegistry.canAct(originatorId, registrarId, address(this), "assignNft")) {
            revert Unauthorized();
        }

        provenanceRegistry.assignNft(provenanceClaimId, nftContract, nftTokenId);
    }

    /// @inheritdoc IProvenanceGateway
    function assignNftFor(
        uint256 provenanceClaimId,
        address nftContract,
        uint256 nftTokenId,
        uint256 deadline,
        bytes calldata sig
    ) external payable override whenNotPaused {
        _verifyAssignNftSig({
            provenanceClaimId: provenanceClaimId,
            nftContract: nftContract,
            nftTokenId: nftTokenId,
            deadline: deadline,
            sig: sig
        });

        provenanceRegistry.assignNft(provenanceClaimId, nftContract, nftTokenId);
    }

    // =============================================================
    //                       SIGNATURE HELPERS
    // =============================================================

    /// @dev Verify the EIP712 signature for a registerFor transaction.
    function _verifyRegisterSig(
        uint256 originatorId,
        bytes32 contentHash,
        address nftContract,
        uint256 nftTokenId,
        uint256 deadline,
        bytes calldata sig
    ) internal {
        address custody = idRegistry.custodyOf(originatorId);

        bytes32 digest = _hashTypedData(
            keccak256(
                abi.encode(
                    REGISTER_TYPEHASH, originatorId, contentHash, nftContract, nftTokenId, _useNonce(custody), deadline
                )
            )
        );

        _verifySig(digest, custody, deadline, sig);
    }

    /// @dev Verify the EIP712 signature for a assignNftFor transaction.
    function _verifyAssignNftSig(
        uint256 provenanceClaimId,
        address nftContract,
        uint256 nftTokenId,
        uint256 deadline,
        bytes calldata sig
    ) internal {
        uint256 originatorId = provenanceRegistry.provenanceClaim(provenanceClaimId).originatorId;
        address custody = idRegistry.custodyOf(originatorId);

        bytes32 digest = _hashTypedData(
            keccak256(
                abi.encode(
                    ASSIGN_NFT_TYPEHASH, provenanceClaimId, nftContract, nftTokenId, _useNonce(custody), deadline
                )
            )
        );

        _verifySig(digest, custody, deadline, sig);
    }

    // =============================================================
    //                      FEE MANAGEMENT
    // =============================================================

    /// @inheritdoc IProvenanceGateway
    function setRegisterFee(uint256 fee) external override onlyOwner {
        registerFee = fee;

        emit RegisterFeeSet(fee);
    }

    // =============================================================
    //                          UUPS
    // =============================================================

    // solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
