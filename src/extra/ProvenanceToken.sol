// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {LibString} from "solady/utils/LibString.sol";

import {RegistrarRoles} from "./utils/RegistrarRoles.sol";
import {ERC721} from "solady/tokens/ERC721.sol";
import {Initializable} from "solady/utils/Initializable.sol";

/* solhint-disable comprehensive-interface */
contract ProvenanceToken is RegistrarRoles, ERC721, Initializable {
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
    uint256 public nextTokenId;

    // =============================================================
    //                   CONSTRUCTOR / INITIALIZER
    // =============================================================

    constructor() {
        _disableInitializers();
    }

    function initialize(
        address initialOwner_,
        string calldata name_,
        string calldata symbol_,
        string calldata metadataUrl_,
        string calldata contractURI_,
        RoleData[] calldata roles
    ) external initializer {
        _initializeOwner(initialOwner_);
        _initializeRoles(roles);

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
    function mintTo(address recipient) external whenNotPaused onlyRolesOrOwner(AIRDROPPER) returns (uint256 tokenId) {
        // Mint the token, increment the minted count, and increment the next token ID.
        tokenId = nextTokenId;

        unchecked {
            _mint(recipient, nextTokenId++);
        }
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
    //                       ROLE HELPERS
    // =============================================================

    /// @notice Check if an address has the AIRDROPPER role.
    function isAirdropper(address account) external view returns (bool) {
        return hasAnyRole(account, AIRDROPPER);
    }

    /// @notice Add the AIRDROPPER role to an address.
    function addAirdropper(address account) external onlyRolesOrOwner(ADMIN) {
        _grantRoles(account, AIRDROPPER);
    }

    /// @notice Remove the AIRDROPPER role from an address.
    function removeAirdropper(address account) external onlyRolesOrOwner(ADMIN) {
        _removeRoles(account, AIRDROPPER);
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
