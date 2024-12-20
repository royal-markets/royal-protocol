// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console, Test} from "forge-std/Test.sol";

import {IdGateway} from "../../src/IdGateway.sol";
import {IdRegistry} from "../../src/IdRegistry.sol";

import {ProvenanceGateway} from "../../src/ProvenanceGateway.sol";
import {ProvenanceRegistry} from "../../src/ProvenanceRegistry.sol";

import {LibString} from "solady/utils/LibString.sol";
import {LibClone} from "solady/utils/LibClone.sol";

import {DelegateRegistry} from "../../src/delegation/DelegateRegistry.sol";
import {IDelegateRegistry} from "../../src/delegation/IDelegateRegistry.sol";

import {ERC721Mock} from "./Utils.sol";

abstract contract ProvenanceTest is Test {
    // =============================================================
    //                          COMMON ERRORS
    // =============================================================

    error EnforcedPause();

    error InvalidSignature();
    error SignatureExpired();

    error Unauthorized();

    // =============================================================
    //                          CONSTANTS
    // =============================================================

    // The set of valid characters for a username. (63 characters).
    string internal constant _USERNAME_CHARSET = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_";

    // There are 63 characters in the charset, but indexing into the charset starts at 0.
    uint256 private constant _USERNAME_CHARSET_MAX_INDEX = 62;

    // The canonical addresses for the protocol contracts.
    address public constant ID_REGISTRY_ADDR = 0x0000002c243D1231dEfA58915324630AB5dBd4f4;
    address public constant ID_GATEWAY_ADDR = 0x000000aA0d40b46F0A78d145c321a9DcfD154Ba7;
    address public constant PROVENANCE_REGISTRY_ADDR = 0x0000009F840EeF8A92E533468A0Ef45a1987Da66;
    address public constant PROVENANCE_GATEWAY_ADDR = 0x000000456Bb9Fd42ADd75F4b5c2247f47D45a0A2;
    address public constant DELEGATE_REGISTRY_ADDR = 0x000000f1CABe81De9e020C9fac95318b14B80F14;

    bytes32 internal constant _ERC1967_IMPLEMENTATION_SLOT =
        0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    // =============================================================
    //                         IMMUTABLES
    // =============================================================

    address public immutable ID_REGISTRY_MIGRATOR;
    address public immutable ID_REGISTRY_OWNER;
    address public immutable ID_GATEWAY_OWNER;

    address public immutable PROVENANCE_REGISTRY_MIGRATOR;
    address public immutable PROVENANCE_REGISTRY_OWNER;
    address public immutable PROVENANCE_GATEWAY_OWNER;

    address public immutable DELEGATE_REGISTRY_OWNER;

    // =============================================================
    //                           STORAGE
    // =============================================================

    // Protocol contract objects
    IdRegistry public idRegistry;
    IdGateway public idGateway;
    ProvenanceRegistry public provenanceRegistry;
    ProvenanceGateway public provenanceGateway;
    DelegateRegistry public delegateRegistry;

    // Track registered usernames to ensure uniqueness.
    mapping(string username => bool isRegistered) internal _registeredUsernames;

    // =============================================================
    //                       TEST CONSTRUCTOR
    // =============================================================

    constructor() {
        ID_REGISTRY_MIGRATOR = vm.addr(0x01);
        ID_REGISTRY_OWNER = vm.addr(0x02);
        ID_GATEWAY_OWNER = vm.addr(0x03);

        PROVENANCE_REGISTRY_MIGRATOR = vm.addr(0x05);
        PROVENANCE_REGISTRY_OWNER = vm.addr(0x06);
        PROVENANCE_GATEWAY_OWNER = vm.addr(0x07);

        DELEGATE_REGISTRY_OWNER = vm.addr(0x08);
    }

    // =============================================================
    //                       PER TEST SETUP
    // =============================================================

    // Set up a fresh IdRegistry/IdGateway for each test
    function setUp() public virtual {
        // Set up the IdRegistry
        address implementation = address(new IdRegistry());
        address proxy = LibClone.deployERC1967(implementation);
        bytes memory proxyCode = address(proxy).code;
        vm.etch(ID_REGISTRY_ADDR, proxyCode);
        vm.store(ID_REGISTRY_ADDR, _ERC1967_IMPLEMENTATION_SLOT, bytes32(uint256(uint160(implementation))));
        idRegistry = IdRegistry(ID_REGISTRY_ADDR);
        idRegistry.initialize(ID_REGISTRY_MIGRATOR, ID_REGISTRY_OWNER);

        // Set up the IdGateway
        implementation = address(new IdGateway());
        proxy = LibClone.deployERC1967(implementation);
        proxyCode = address(proxy).code;
        vm.etch(ID_GATEWAY_ADDR, proxyCode);
        vm.store(ID_GATEWAY_ADDR, _ERC1967_IMPLEMENTATION_SLOT, bytes32(uint256(uint160(implementation))));
        idGateway = IdGateway(ID_GATEWAY_ADDR);
        idGateway.initialize(idRegistry, ID_GATEWAY_OWNER);
        vm.prank(ID_GATEWAY_OWNER);
        idGateway.setDelegateRegistry(DELEGATE_REGISTRY_ADDR);

        // Point the IdRegistry at the IdGateway
        vm.startPrank(ID_REGISTRY_OWNER);
        idRegistry.setIdGateway(address(idGateway));
        idRegistry.unpause();
        vm.stopPrank();

        // Set up the ProvenanceRegistry
        implementation = address(new ProvenanceRegistry());
        proxy = LibClone.deployERC1967(implementation);
        proxyCode = address(proxy).code;
        vm.etch(PROVENANCE_REGISTRY_ADDR, proxyCode);
        vm.store(PROVENANCE_REGISTRY_ADDR, _ERC1967_IMPLEMENTATION_SLOT, bytes32(uint256(uint160(implementation))));
        provenanceRegistry = ProvenanceRegistry(PROVENANCE_REGISTRY_ADDR);
        provenanceRegistry.initialize(idRegistry, PROVENANCE_REGISTRY_MIGRATOR, PROVENANCE_REGISTRY_OWNER);

        // Set up the ProvenanceGateway
        implementation = address(new ProvenanceGateway());
        proxy = LibClone.deployERC1967(implementation);
        proxyCode = address(proxy).code;
        vm.etch(PROVENANCE_GATEWAY_ADDR, proxyCode);
        vm.store(PROVENANCE_GATEWAY_ADDR, _ERC1967_IMPLEMENTATION_SLOT, bytes32(uint256(uint160(implementation))));
        provenanceGateway = ProvenanceGateway(PROVENANCE_GATEWAY_ADDR);
        provenanceGateway.initialize(provenanceRegistry, idRegistry, PROVENANCE_GATEWAY_OWNER);

        // Point the ProvenanceRegistry at the ProvenanceGateway
        vm.startPrank(PROVENANCE_REGISTRY_OWNER);
        provenanceRegistry.setProvenanceGateway(address(provenanceGateway));
        provenanceRegistry.unpause();
        vm.stopPrank();

        // Set up DelegateRegistry for delegation tests,
        // and set bytecode to the expected delegate.xyz v2 address
        implementation = address(new DelegateRegistry());
        proxy = LibClone.deployERC1967(implementation);
        proxyCode = address(proxy).code;
        vm.etch(address(DELEGATE_REGISTRY_ADDR), proxyCode);
        vm.store(
            address(DELEGATE_REGISTRY_ADDR), _ERC1967_IMPLEMENTATION_SLOT, bytes32(uint256(uint160(implementation)))
        );
        delegateRegistry = DelegateRegistry(DELEGATE_REGISTRY_ADDR);
        delegateRegistry.initialize(address(idRegistry), DELEGATE_REGISTRY_OWNER);
        vm.prank(DELEGATE_REGISTRY_OWNER);
        delegateRegistry.setIdGateway(ID_GATEWAY_ADDR);
    }

    // =============================================================
    //                        RANDOMNESS HELPERS
    // =============================================================

    /// @dev Get a random valid username of the given length.
    function _getRandomValidUniqueUsername(uint256 length) internal returns (string memory) {
        bytes memory usernameBytes = new bytes(length);
        for (uint256 i = 0; i < length; i++) {
            uint256 randomIndex = vm.randomUint(0, _USERNAME_CHARSET_MAX_INDEX);
            usernameBytes[i] = bytes(_USERNAME_CHARSET)[randomIndex];
        }

        string memory username = string(usernameBytes);

        // NOTE: This might not guarantee uniqueness, since you can call this helper without fuzzing,
        //       but it's good enough for our current use cases.
        //
        // Also note how we lowercase usernames, becuase we are case-insensitive when it comes to uniqueness.
        string memory lowercaseUsername = LibString.lower(username);
        vm.assume(!_registeredUsernames[lowercaseUsername]);
        _registeredUsernames[lowercaseUsername] = true;

        return username;
    }

    /// @dev Validate a username has only valid characters.
    ///      (a-z, A-Z, 0-9, hyphen, underscore)
    ///
    ///      The code here is basically a carbon-copy of _validateUrlSafe in the IdGateway,
    ///      but we need to be able to generate **invalid** usernames in our tests,
    ///      and it's nice to not have an implicit dependency on a specific internal function in the IdGateway
    ///
    ///      We generate invalid usernames by fuzzing byte16s (since 16 characters is the max length of a username),
    ///      and then calling vm.assume(!_validateUsernameCharacters(username)) to ensure it's invalid.
    function _validateUsernameCharacters(string memory username) internal pure returns (bool isValid) {
        isValid = true;
        bytes memory usernameBytes = bytes(username);

        for (uint256 i = 0; i < usernameBytes.length; i++) {
            bytes1 charCode = usernameBytes[i];

            // a-z, A-Z, hyphen, underscore
            if (
                (charCode > 0x60 && charCode < 0x7B) // a-z
                    || (charCode > 0x40 && charCode < 0x5B) // A-Z
                    || (charCode == 0x2D) // hyphen (-)
                    || (charCode == 0x5F) // underscore (_)
            ) continue;

            // numbers (0-9)
            if (charCode > 0x2F && charCode < 0x3A) continue;

            // If we reached here, we have an invalid character.
            isValid = false;
        }
    }

    /// @dev Bound a fuzzed uint256 privateKey to the valid range for a secp256k1 private key.
    function _boundPk(uint256 pk) internal pure returns (uint256) {
        uint256 SECP_256K1_ORDER = 0xfffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364141;

        return bound(pk, 1, SECP_256K1_ORDER - 1);
    }

    /// @dev Transform a fuzzed uint8 length to the valid range for a username length.
    function _boundUsernameLength(uint8 length) internal pure returns (uint256) {
        // Username length must be between 2 and 16 characters.
        return (length % 15) + 2;
    }

    function _boundUsernameLengthTooLong(uint8 length) internal pure returns (uint256) {
        return bound(length, 17, 255);
    }

    /// @dev Transform a fuzzed uint40 value into a valid deadline.
    function _boundDeadline(uint40 deadline) internal view returns (uint256) {
        return block.timestamp + uint256(deadline);
    }

    // =============================================================
    //                        REGISTER HELPERS
    // =============================================================

    /// @dev Register just a username with the IdGateway.
    function _register(address custody, string memory username) internal returns (uint256 id) {
        vm.prank(custody);
        id = idGateway.register(username, address(0));
    }

    /// @dev Register a new account with a uesrname and recovery address.
    function _register(address custody, string memory username, address recovery) internal returns (uint256 id) {
        vm.startPrank(custody);
        id = idGateway.register(username, recovery);

        vm.stopPrank();
    }

    // =============================================================
    //                        PROVENANCE HELPERS
    // =============================================================

    /// @dev Register the given accounts and the ProvenanceClaim.
    function _registerProvenance(address originator, address registrar, bytes32 contentHash)
        internal
        returns (uint256 id)
    {
        uint256 originatorId = _register(originator, "originator");
        uint256 registrarId = _register(registrar, "registrar");

        if (registrar != originator) {
            vm.prank(originator);
            delegateRegistry.delegateContract(registrarId, address(provenanceGateway), "registerProvenance", true);
        }

        address nftContract = address(0);
        uint256 tokenId = 0;

        vm.prank(registrar);
        id = provenanceGateway.register(originatorId, contentHash, nftContract, tokenId);
    }

    /// @dev Register the given accounts and the ProvenanceClaim, with NFT token.
    function _registerProvenance(
        address originator,
        address registrar,
        bytes32 contentHash,
        address nftContract,
        uint256 tokenId
    ) internal returns (uint256 id) {
        uint256 originatorId = _register(originator, "originator");
        uint256 registrarId = _register(registrar, "registrar");

        if (registrar != originator) {
            vm.prank(originator);
            delegateRegistry.delegateContract(registrarId, address(provenanceGateway), "registerProvenance", true);
        }

        ERC721Mock erc721 = new ERC721Mock();
        vm.etch(nftContract, address(erc721).code);
        erc721.mint(originator, tokenId);

        vm.prank(registrar);
        id = provenanceGateway.register(originatorId, contentHash, nftContract, tokenId);
    }

    /// @dev Register provenance with the given (already registered) account IDs.
    function _registerProvenance(uint256 originatorId, uint256 registrarId, bytes32 contentHash)
        internal
        returns (uint256 id)
    {
        address originator = idRegistry.custodyOf(originatorId);
        address registrar = idRegistry.custodyOf(registrarId);

        if (originatorId != registrarId) {
            vm.prank(originator);
            delegateRegistry.delegateContract(registrarId, address(provenanceGateway), "registerProvenance", true);
        }

        address nftContract = address(0);
        uint256 tokenId = 0;

        vm.prank(registrar);
        id = provenanceGateway.register(originatorId, contentHash, nftContract, tokenId);
    }

    /// @dev Register provenance with the given (already registered) account IDs, and NFT token.
    function _registerProvenance(
        uint256 originatorId,
        uint256 registrarId,
        bytes32 contentHash,
        address nftContract,
        uint256 tokenId
    ) internal returns (uint256 id) {
        address originator = idRegistry.custodyOf(originatorId);
        address registrar = idRegistry.custodyOf(registrarId);

        if (originatorId != registrarId) {
            vm.prank(originator);
            delegateRegistry.delegateContract(registrarId, address(provenanceGateway), "registerProvenance", true);
        }

        ERC721Mock erc721 = new ERC721Mock();
        vm.etch(nftContract, address(erc721).code);
        erc721.mint(originator, tokenId);

        vm.prank(registrar);
        id = provenanceGateway.register(originatorId, contentHash, nftContract, tokenId);
    }

    function _createMockERC721(bytes32 salt) internal returns (address mockNftAddress) {
        ERC721Mock mockNft = new ERC721Mock{salt: salt}();
        mockNftAddress = address(mockNft);
    }

    // =============================================================
    //                          DELEGATION HELPERS
    // =============================================================

    /// @dev Delegate a username to a new address.
    function _delegateProvenanceRegistration(address delegator, uint256 delegateeId) internal {
        vm.prank(delegator);
        delegateRegistry.delegateContract(delegateeId, address(provenanceGateway), "registerProvenance", true);
    }
}
