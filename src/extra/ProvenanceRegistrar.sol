// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {RegistrarRoles} from "./utils/RegistrarRoles.sol";
import {RoyalProtocolAccount} from "./RoyalProtocolAccount.sol";
import {Initializable} from "solady/utils/Initializable.sol";
import {UUPSUpgradeable} from "solady/utils/UUPSUpgradeable.sol";

import {SignatureCheckerLib} from "solady/utils/SignatureCheckerLib.sol";

interface IProvenanceToken {
    function mintTo(address recipient) external returns (uint256 tokenId);
}

/* solhint-disable comprehensive-interface */
contract ProvenanceRegistrar is RegistrarRoles, RoyalProtocolAccount, Initializable, UUPSUpgradeable {
    // =============================================================
    //                           STORAGE
    // =============================================================

    /// @notice The address of the NFT contract to mint tokens for provenance claims.
    address public nftContract;

    /// @notice An additional address that can sign ERC1271 signatures for this contract.
    address public signer;

    // =============================================================
    //                           EVENTS
    // =============================================================

    /// @notice Emitted when the NFT contract is set.
    event NftContractSet(address indexed oldNftContract, address indexed newNftContract);

    /// @notice Emitted when the signer is set.
    event SignerSet(address indexed oldSigner, address indexed newSigner);

    /// @notice Emitted when ETH is deposited into the contract (without a corresponding function call).
    event Received(address indexed sender, uint256 amount);

    /// @notice Emitted when an arbitrary `execute` call is made to another address.
    event Call(address indexed caller, address indexed to, bytes data, bool success, bytes response);

    // =============================================================
    //                          ERRORS
    // =============================================================

    /// @notice Error when the originator is not found in the IdRegistry.
    error OriginatorNotFound();

    // =============================================================
    //                          CONSTRUCTOR
    // =============================================================

    constructor() {
        _disableInitializers();
    }

    // =============================================================
    //                          INITIALIZER
    // =============================================================

    /// @dev This is payable because initializing a protocol count _may_ require a registration fee.
    function initialize(
        string calldata username,
        address recovery,
        address initialOwner_,
        address nftContract_,
        RoleData[] calldata roles
    ) external payable initializer returns (uint256 accountId) {
        _initializeOwner(initialOwner_);
        _initializeRoles(roles);

        nftContract = nftContract_;

        accountId = _initializeRoyalProtocolAccount({
            username: username,
            recovery: recovery,
            isDuplicateClaimCheckEnabled_: true
        });
    }

    // =============================================================
    //                          REGISTRATION
    // =============================================================

    /// @notice Register a provenance claim on behalf of an originator.
    function registerProvenanceAndMintNft(uint256 originatorId, bytes32 contentHash)
        external
        payable
        returns (uint256 provenanceClaimId)
    {
        // Even though the ProvenanceRegistry will do this exact same check, (that the originator is in the IdRegistry),
        // It's nice to double-check that we mint the NFT to an actually valid custody address,
        // rather than rely on functionality in the ProvenanceRegistry to revert for us.
        address custody = idRegistry.custodyOf(originatorId);
        if (custody == address(0)) revert OriginatorNotFound();

        // Mint the NFT and register the provenance claim.
        uint256 nftTokenId = IProvenanceToken(nftContract).mintTo(custody);
        provenanceClaimId = registerProvenanceWithNft(originatorId, contentHash, nftContract, nftTokenId);
    }

    // =============================================================
    //                     ERC1271 SIGNATURE VALIDATION
    // =============================================================

    /// @notice ERC1271 signature validation for this contract.
    ///
    /// Check if the signature is from the owner or the `signer` address.
    function isValidSignature(bytes32 hash, bytes calldata sig) external view override returns (bytes4 magicValue) {
        // Validate if signature is from OWNER
        if (SignatureCheckerLib.isValidSignatureNowCalldata(owner(), hash, sig)) {
            return 0x1626ba7e;
        }

        // Validate if signature is from SIGNER
        if (SignatureCheckerLib.isValidSignatureNowCalldata(signer, hash, sig)) {
            return 0x1626ba7e;
        }

        // Signature validation failed.
        return 0xffffffff;
    }

    // =============================================================
    //                          ADMIN FNs
    // =============================================================

    /// @notice Set the address of the NFT contract.
    function setNftContract(address nftContract_) external onlyRolesOrOwner(ADMIN) {
        emit NftContractSet(nftContract, nftContract_);

        nftContract = nftContract_;
    }

    /// @notice Set the address of the signer.
    function setSigner(address signer_) external onlyRolesOrOwner(ADMIN) {
        emit SignerSet(signer, signer_);

        signer = signer_;
    }

    /// @notice Arbitrary call to another contract. (only ADMIN or owner)
    function execute(address payable to, bytes calldata data)
        external
        payable
        onlyRolesOrOwner(ADMIN)
        returns (bool, bytes memory)
    {
        (bool success, bytes memory response) = to.call{value: msg.value}(data);

        // slither-disable-next-line reentrancy-events
        emit Call({caller: msg.sender, to: to, data: data, success: success, response: response});

        return (success, response);
    }

    // =============================================================
    //                       ROLE HELPERS
    // =============================================================

    /// @notice Check if an account has the REGISTER_CALLER role.
    function isRegisterCaller(address account) external view returns (bool) {
        return hasAnyRole(account, REGISTER_CALLER);
    }

    /// @notice Add the REGISTER_CALLER role to an account.
    function addRegisterCaller(address account) external onlyRolesOrOwner(ADMIN) {
        _grantRoles(account, REGISTER_CALLER);
    }

    /// @notice Remove the REGISTER_CALLER role from an account.
    function removeRegisterCaller(address account) external onlyRolesOrOwner(ADMIN) {
        _removeRoles(account, REGISTER_CALLER);
    }

    // =============================================================
    //                          RECEIVE
    // =============================================================

    /// @notice Fallback function to receive ETH.
    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

    // =============================================================
    //                          AUTH GUARDS
    // =============================================================

    function _authorizeContractConfiguration() internal override onlyRolesOrOwner(ADMIN) {}

    function _authorizeAccountManagement() internal override onlyRolesOrOwner(ADMIN) {}

    function _authorizeProvenanceRegistration() internal override onlyRolesOrOwner(REGISTER_CALLER) whenNotPaused {}

    function _authorizeUpgrade(address newImplementation) internal override onlyRolesOrOwner(ADMIN) {}
}
/* solhint-enable comprehensive-interface */
