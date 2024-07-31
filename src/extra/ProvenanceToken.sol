// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {LibString} from "solady/utils/LibString.sol";

import {Withdrawable} from "../core/abstract/Withdrawable.sol";
import {ERC721} from "solady/tokens/ERC721.sol";

/* solhint-disable comprehensive-interface */
contract ProvenanceToken is Withdrawable, ERC721 {
    // =============================================================
    //                         EVENTS
    // =============================================================

    /// @dev Emitted when the NFT metadata base URL is updated.
    event MetadataUrlUpdated();

    /// @dev Emitted when the `contractURI` (ERC7572) is updated.
    event ContractURIUpdated();

    /// @dev This event emits when the metadata of a token is changed. (ERC4906)
    event MetadataUpdate(uint256 tokenId);

    /// @dev This event emits when the metadata of a range of tokens is changed. (ERC4906)
    event BatchMetadataUpdate(uint256 fromTokenId, uint256 toTokenId);

    // =============================================================
    //                        CONSTANTS
    // =============================================================

    /// @notice The bitmask for the ADMIN role.
    uint256 public constant ADMIN = 1 << 0;

    /// @notice The bitmask for the AIRDROPPER role.
    uint256 public constant AIRDROPPER = 1 << 1;

    // =============================================================
    //                         STORAGE
    // =============================================================

    // ERC721 name of contract token collection.
    string internal _name;

    // ERC721 symbol of contract token collection.
    string internal _symbol;

    /// @notice The URL to which we append the tokenId to get the token's metadata.
    string public metadataUrl;

    /// @notice The URL which points to the contract's metadata in ERC-7572 format.
    string public contractURI;

    /// @notice The token ID of the next token to be minted.
    uint64 public nextTokenId;

    // =============================================================
    //                         CONSTRUCTOR
    // =============================================================

    constructor(
        address initialOwner_,
        string memory name_,
        string memory symbol_,
        string memory metadataUrl_,
        string memory contractURI_
    ) {
        _initializeOwner(initialOwner_);

        // Set all the strings
        _name = name_;
        _symbol = symbol_;
        metadataUrl = metadataUrl_;
        contractURI = contractURI_;

        // Initialize the next token ID to 1, since token IDs are 1-indexed.
        nextTokenId = 1;

        // Emitted to adhere to ERC-7572 spec.
        emit ContractURIUpdated();
    }

    // =============================================================
    //                     CONTRACT CONFIGURATION
    // =============================================================

    /// @notice Update the metadata URL for the NFTs. (Only callable by ADMIN role or OWNER)
    function updateMetadataUrl(string calldata newMetadataUrl) external onlyRolesOrOwner(ADMIN) {
        metadataUrl = newMetadataUrl;

        emit MetadataUrlUpdated();
    }

    /// @notice Update the contract URI for the NFTs. (Only callable by ADMIN role or OWNER)
    function updateContractURI(string calldata newContractURI) external onlyRolesOrOwner(ADMIN) {
        contractURI = newContractURI;

        emit ContractURIUpdated();
    }

    /// @notice Update the metadata for a token (ERC4906). (Only callable by ADMIN role or OWNER)
    function updateTokenMetadata(uint256 tokenId) external onlyRolesOrOwner(ADMIN) {
        emit MetadataUpdate(tokenId);
    }

    /// @notice Update the metadata for a range of tokens (ERC4906). (Only callable by ADMIN role or OWNER)
    function updateBatchTokenMetadata(uint256 fromTokenId, uint256 toTokenId) external onlyRolesOrOwner(ADMIN) {
        emit BatchMetadataUpdate(fromTokenId, toTokenId);
    }

    // =============================================================
    //                        MINTING
    // =============================================================

    /// @notice Mint a new token to the recipient. (Only callable by AIRDROPPER role or OWNER).
    function mintTo(address recipient) external payable onlyRolesOrOwner(AIRDROPPER) returns (uint256 tokenId) {
        // Mint the token, increment the minted count, and increment the next token ID.
        tokenId = nextTokenId;

        unchecked {
            _mint(recipient, nextTokenId++);
        }
    }

    // =============================================================
    //                       ROLE HELPERS
    // =============================================================

    /// @notice Add the ADMIN role to an address.
    function addAdmin(address admin) external onlyOwner {
        _grantRoles(admin, ADMIN);
    }

    /// @notice Remove the ADMIN role from an address.
    function removeAdmin(address admin) external onlyOwner {
        _removeRoles(admin, ADMIN);
    }

    /// @notice Add the AIRDROPPER role to an address.
    function addAirdropper(address airdropper) external onlyOwner {
        _grantRoles(airdropper, AIRDROPPER);
    }

    /// @notice Remove the AIRDROPPER role from an address.
    function removeAirdropper(address airdropper) external onlyOwner {
        _removeRoles(airdropper, AIRDROPPER);
    }

    /// @notice Check if an address has the ADMIN role.
    function isAdmin(address account) external view returns (bool) {
        return hasAnyRole(account, ADMIN);
    }

    /// @notice Check if an address has the AIRDROPPER role.
    function isAirdropper(address account) external view returns (bool) {
        return hasAnyRole(account, AIRDROPPER);
    }

    // =============================================================
    //                       ERC721 FUNCTIONS
    // =============================================================

    /// @notice Returns the name of the token collection.
    function name() public view override returns (string memory) {
        return _name;
    }

    /// @notice Returns the symbol of the token collection.
    function symbol() public view override returns (string memory) {
        return _symbol;
    }

    /// @notice Returns the metadata URI for a given token ID.
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        if (!_exists(tokenId)) revert TokenDoesNotExist();

        // Example: https://example.com/path/to/contract/metadata/{tokenId}
        return string.concat(metadataUrl, LibString.toString(tokenId));
    }

    // =============================================================
    //                      ERC4906 FUNCTIONS
    // =============================================================

    /// @dev Implements the ERC4906 interface. (In addition to the ERC721 interface).
    function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
        return interfaceId == bytes4(0x49064906) || super.supportsInterface(interfaceId);
    }
}
/* solhint-enable comprehensive-interface */
