// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ProvenanceToken} from "./ProvenanceToken.sol";
import {IIdRegistry} from "../core/interfaces/IIdRegistry.sol";
import {IProvenanceGateway} from "../core/interfaces/IProvenanceGateway.sol";

import {Withdrawable} from "../core/abstract/Withdrawable.sol";
import {Initializable} from "solady/utils/Initializable.sol";
import {UUPSUpgradeable} from "solady/utils/UUPSUpgradeable.sol";

/* solhint-disable comprehensive-interface */
contract ProvenanceRegistrar is Withdrawable, Initializable, UUPSUpgradeable {
    // =============================================================
    //                          CONSTANTS
    // =============================================================

    /// @notice The bitmask for the ADMIN role.
    uint256 public constant ADMIN = 1 << 0;

    /// @notice The bitmask for the REGISTER_CALLER role.
    uint256 public constant REGISTER_CALLER = 1 << 1;

    // =============================================================
    //                           STORAGE
    // =============================================================

    /// @notice The address of the NFT contract to mint tokens for provenance claims.
    address public nftContract;

    /// @notice The address of the RoyalProtocol IdRegistry contract.
    address public idRegistry;

    /// @notice The address of the RoyalProtocol ProvenanceGateway contract.
    address public provenanceGateway;

    /// @notice The mapping of content hashes to claim IDs to prevent double claiming.
    mapping(bytes32 contentHash => uint256 provenanceClaimId) public provenanceClaimIdOfContentHash;

    // =============================================================
    //                           EVENTS
    // =============================================================

    /// @notice Emitted when the NFT contract is set.
    event NftContractSet(address indexed oldNftContract, address indexed newNftContract);

    /// @notice Emitted when the IdRegistry is set.
    event IdRegistrySet(address indexed oldIdRegistry, address indexed newIdRegistry);

    /// @notice Emitted when the ProvenanceGateway is set.
    event ProvenanceGatewaySet(address indexed oldProvenanceGateway, address indexed newProvenanceGateway);

    /// @notice Emitted when a ProvenanceClaim is registered on behalf of an originator.
    event ProvenanceClaimRegistered(
        uint256 provenanceClaimId,
        uint256 indexed originatorId,
        bytes32 indexed contentHash,
        address nftContract,
        uint256 nftTokenId
    );

    /// @notice Emitted when the contract receives ether.
    event Received(address indexed sender, uint256 value);

    // =============================================================
    //                          ERRORS
    // =============================================================

    /// @notice Error when the originator is not found in the IdRegistry.
    error OriginatorNotFound();

    /// @notice Error when the content hash is already claimed.
    error ContentHashAlreadyClaimed();

    // =============================================================
    //                          CONSTRUCTOR
    // =============================================================

    constructor() {
        _disableInitializers();
    }

    // =============================================================
    //                          INITIALIZER
    // =============================================================

    function initialize(address initialOwner_, address nftContract_, address idRegistry_, address provenanceGateway_)
        external
        initializer
    {
        _initializeOwner(initialOwner_);
        nftContract = nftContract_;
        idRegistry = idRegistry_;
        provenanceGateway = provenanceGateway_;
    }

    // =============================================================
    //                          REGISTRATION
    // =============================================================

    /// @notice Register a provenance claim on behalf of an originator.
    function registerProvenance(uint256 originatorId, bytes32 contentHash)
        external
        onlyRolesOrOwner(REGISTER_CALLER)
        returns (uint256 provenanceId)
    {
        address custody = IIdRegistry(idRegistry).custodyOf(originatorId);
        if (custody == address(0)) revert OriginatorNotFound();

        uint256 existingClaimId = provenanceClaimIdOfContentHash[contentHash];
        if (existingClaimId != 0) revert ContentHashAlreadyClaimed();

        uint256 nftTokenId = ProvenanceToken(nftContract).mintTo(custody);
        provenanceId =
            IProvenanceGateway(provenanceGateway).register(originatorId, contentHash, nftContract, nftTokenId);

        // We assume the NFT contract and ProvenanceGateway don't re-entry, and are trusted contracts.

        // slither-disable-next-line reentrancy-no-eth
        provenanceClaimIdOfContentHash[contentHash] = provenanceId;

        // slither-disable-next-line reentrancy-events
        emit ProvenanceClaimRegistered({
            provenanceClaimId: provenanceId,
            originatorId: originatorId,
            contentHash: contentHash,
            nftContract: nftContract,
            nftTokenId: nftTokenId
        });
    }

    // =============================================================
    //                          ADMIN FNs
    // =============================================================

    /// @notice Set the address of the NFT contract.
    function setNftContract(address nftContract_) external onlyRolesOrOwner(ADMIN) {
        emit NftContractSet(nftContract, nftContract_);

        nftContract = nftContract_;
    }

    /// @notice Set the address of the IdRegistry contract.
    function setIdRegistry(address idRegistry_) external onlyRolesOrOwner(ADMIN) {
        emit IdRegistrySet(idRegistry, idRegistry_);

        idRegistry = idRegistry_;
    }

    /// @notice Set the address of the ProvenanceGateway contract.
    function setProvenanceGateway(address provenanceGateway_) external onlyRolesOrOwner(ADMIN) {
        emit ProvenanceGatewaySet(provenanceGateway, provenanceGateway_);

        provenanceGateway = provenanceGateway_;
    }

    // =============================================================
    //                       ROLE HELPERS
    // =============================================================

    /// @notice Add the ADMIN role to an account.
    function addAdmin(address account) external onlyOwner {
        _grantRoles(account, ADMIN);
    }

    /// @notice Remove the ADMIN role from an account.
    function removeAdmin(address account) external onlyOwner {
        _removeRoles(account, ADMIN);
    }

    /// @notice Add the REGISTER_CALLER role to an account.
    function addRegisterCaller(address account) external onlyOwner {
        _grantRoles(account, REGISTER_CALLER);
    }

    /// @notice Remove the REGISTER_CALLER role from an account.
    function removeRegisterCaller(address account) external onlyOwner {
        _removeRoles(account, REGISTER_CALLER);
    }

    /// @notice Check if an account has the ADMIN role.
    function isAdmin(address account) external view returns (bool) {
        return hasAnyRole(account, ADMIN);
    }

    /// @notice Check if an account has the REGISTER_CALLER role.
    function isRegisterCaller(address account) external view returns (bool) {
        return hasAnyRole(account, REGISTER_CALLER);
    }

    // =============================================================
    //                          RECEIVE
    // =============================================================

    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

    // =============================================================
    //                          UUPS
    // =============================================================

    // solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address newImplementation) internal override onlyRolesOrOwner(ADMIN) {}
}
/* solhint-enable comprehensive-interface */
