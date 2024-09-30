// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IIdGateway} from "../core/interfaces/IIdGateway.sol";
import {IIdRegistry} from "../core/interfaces/IIdRegistry.sol";
import {IProvenanceGateway} from "../core/interfaces/IProvenanceGateway.sol";
import {IProvenanceRegistry} from "../core/interfaces/IProvenanceRegistry.sol";

abstract contract RoyalProtocolAccount {
    // =============================================================
    //                           STORAGE
    // =============================================================

    /// @notice The RoyalProtocol ID of this account.
    uint256 public royalProtocolAccountId;

    /// @notice The address of the RoyalProtocol IdRegistry contract.
    IIdRegistry public idRegistry;

    /// @notice The address of the RoyalProtocol IdGateway contract.
    IIdGateway public idGateway;

    /// @notice The address of the RoyalProtocol ProvenanceRegistry contract.
    IProvenanceRegistry public provenanceRegistry;

    /// @notice The address of the RoyalProtocol ProvenanceGateway contract.
    IProvenanceGateway public provenanceGateway;

    /// @notice Flag to disable the duplicate claim check.
    bool public isDuplicateClaimCheckEnabled;

    /// @notice The mapping of content hashes to claim IDs to prevent duplicate claims by different users.
    mapping(bytes32 contentHash => uint256 provenanceClaimId) public provenanceClaimIdOfContentHash;

    // =============================================================
    //                         EVENTS
    // =============================================================

    // Account Management Events

    /// @notice Emitted when the IdRegistry account is registered.
    event Registered(uint256 indexed accountId, string username, address recovery);

    /// @notice Emitted when the ownership of the IdRegistry account is transferred.
    event Transferred(address indexed newOwner);

    /// @notice Emitted when the username of the IdRegistry account is transferred.
    event UsernameTransferred(uint256 indexed newId);

    /// @notice Emitted when the username of the IdRegistry account is changed.
    event UsernameChanged(string newUsername);

    /// @notice Emitted when the recovery address of the IdRegistry account is changed.
    event RecoveryChanged(address indexed newRecovery);

    // Provenance Claim Events

    /// @notice Emitted when a ProvenanceClaim is registered on behalf of an originator.
    event ProvenanceClaimRegistered(
        uint256 provenanceClaimId,
        uint256 indexed originatorId,
        bytes32 indexed contentHash,
        address indexed nftContract,
        uint256 nftTokenId
    );

    /// @notice Emitted when an NFT is assigned to a ProvenanceClaim.
    event NftAssignedToProvenanceClaim(
        uint256 indexed provenanceClaimId, address indexed nftContract, uint256 nftTokenId
    );

    // Admin Events

    /// @notice Emitted when the IdRegistry is set.
    event IdRegistrySet(address indexed oldIdRegistry, address indexed newIdRegistry);

    /// @notice Emitted when the IdGateway is set.
    event IdGatewaySet(address indexed oldIdGateway, address indexed newIdGateway);

    /// @notice Emitted when the ProvenanceRegistry is set.
    event ProvenanceRegistrySet(address indexed oldProvenanceRegistry, address indexed newProvenanceRegistry);

    /// @notice Emitted when the ProvenanceGateway is set.
    event ProvenanceGatewaySet(address indexed oldProvenanceGateway, address indexed newProvenanceGateway);

    /// @notice Emitted when the duplicate claim check flag is set.
    event DuplicateClaimCheckFlagSet(bool oldValue, bool newValue);

    // =============================================================
    //                          ERRORS
    // =============================================================

    /// @notice Error when the content hash is already claimed.
    error ContentHashAlreadyClaimed();

    // =============================================================
    //                          INITIALIZER
    // =============================================================

    /// @dev initializer to set up the RoyalProtocol account.
    ///
    /// Should be called in the constructor/initializer of the inheriting contract.
    function _initializeRoyalProtocolAccount(
        string memory username,
        address recovery,
        bool isDuplicateClaimCheckEnabled_
    ) internal virtual returns (uint256 accountId) {
        // Set up the canonical addresses for RoyalProtocol contracts.
        idRegistry = IIdRegistry(0x0000002c243D1231dEfA58915324630AB5dBd4f4);
        idGateway = IIdGateway(0x000000aA0d40b46F0A78d145c321a9DcfD154Ba7);
        provenanceRegistry = IProvenanceRegistry(0x0000009F840EeF8A92E533468A0Ef45a1987Da66);
        provenanceGateway = IProvenanceGateway(0x000000456Bb9Fd42ADd75F4b5c2247f47D45a0A2);

        // Set the duplicate claim check flag,
        // to allow/disallow registering the same contentHash multiple times.
        isDuplicateClaimCheckEnabled = isDuplicateClaimCheckEnabled_;

        // Register a RoyalProtocol account for this contract.
        uint256 registerFee = idGateway.registerFee();

        // Safe because this is an internal function that should only be called by the initializer.
        // slither-disable-next-line arbitrary-send-eth
        royalProtocolAccountId = idGateway.register{value: registerFee}(username, recovery);
        // slither-disable-next-line reentrancy-events
        emit Registered(royalProtocolAccountId, username, recovery);

        return royalProtocolAccountId;
    }
    // =============================================================
    //                     ACCOUNT MANAGEMENT FNs
    // =============================================================

    /// @dev Please override this function to check if `msg.sender` is authorized
    /// to call the following RoyalProtocol account management functions.
    /// ```
    ///     function _authorizeAccountManagement() internal override onlyOwner {}
    /// ```
    function _authorizeAccountManagement() internal virtual {}

    /// @notice Register a RoyalProtocol IdRegistry account.
    ///
    /// @dev We actually register an account in our initializer,
    /// but it's possible that we might transfer that initial account to a different owner,
    /// in which case, we could register a new account from this address.
    function registerProtocolAccount(string memory username, address recovery)
        public
        payable
        virtual
        returns (uint256 accountId)
    {
        _authorizeAccountManagement();

        uint256 registerFee = idGateway.registerFee();

        // Guarded by override of _authorizeAccountManagement()
        // slither-disable-next-line arbitrary-send-eth
        royalProtocolAccountId = idGateway.register{value: registerFee}(username, recovery);

        // slither-disable-next-line reentrancy-events
        emit Registered(royalProtocolAccountId, username, recovery);

        return royalProtocolAccountId;
    }

    /// @notice Transfer the ownership of the RoyalProtocol IdRegistry account.
    function transferProtocolAccount(address to, uint256 deadline, bytes calldata sig) public payable virtual {
        _authorizeAccountManagement();

        emit Transferred(to);

        uint256 transferFee = idGateway.transferFee();

        // Guarded by override of _authorizeAccountManagement()
        // slither-disable-next-line arbitrary-send-eth
        idGateway.transfer{value: transferFee}(to, deadline, sig);
    }

    /// @notice Transfer the username for the RoyalProtocol IdRegistry.
    function transferProtocolAccountUsername(
        uint256 toId,
        string calldata newUsername,
        uint256 deadline,
        bytes calldata sig
    ) public payable virtual {
        _authorizeAccountManagement();

        emit UsernameTransferred(toId);
        emit UsernameChanged(newUsername);

        uint256 transferUsernameFee = idGateway.transferUsernameFee();

        // Guarded by override of _authorizeAccountManagement()
        // slither-disable-next-line arbitrary-send-eth
        idGateway.transferUsername{value: transferUsernameFee}(toId, newUsername, deadline, sig);
    }

    /// @notice Change the username for the RoyalProtocol IdRegistry.
    function changeProtocolAccountUsername(string calldata newUsername) public payable virtual {
        _authorizeAccountManagement();

        emit UsernameChanged(newUsername);

        uint256 changeUsernameFee = idGateway.changeUsernameFee();

        // Guarded by override of _authorizeAccountManagement()
        // slither-disable-next-line arbitrary-send-eth
        idGateway.changeUsername{value: changeUsernameFee}(newUsername);
    }

    /// @notice Change the recovery address for the RoyalProtocol IdRegistry.
    function changeProtocolAccountRecovery(address newRecovery) public payable virtual {
        _authorizeAccountManagement();

        emit RecoveryChanged(newRecovery);

        uint256 changeRecoveryFee = idGateway.changeRecoveryFee();

        // Guarded by override of _authorizeAccountManagement()
        // slither-disable-next-line arbitrary-send-eth
        idGateway.changeRecovery{value: changeRecoveryFee}(newRecovery);
    }

    /// @dev Please override this function with whatever logic is necessary to authorize ERC1271 signatures.
    /// ```
    ///     function isValidSignature(bytes32 hash, bytes calldata sig) external view override {
    ///         if (SignatureCheckerLib.isValidSignatureNowCalldata(owner(), hash, sig)) {
    ///             return 0x1626ba7e;
    ///         }
    ///
    ///         return 0xffffffff;
    ///     }
    /// ```
    function isValidSignature(bytes32, bytes calldata) external view virtual returns (bytes4 magicValue) {
        return 0xffffffff;
    }

    // =============================================================
    //                     PROVENANCE CLAIM FNs
    // =============================================================

    /// @dev Please override this function to check if `msg.sender` is authorized
    /// to call the following RoyalProtocol provenance claim functions.
    /// ```
    ///     function _authorizeProvenanceRegistration() internal override onlyOwner {}
    /// ```
    function _authorizeProvenanceRegistration() internal virtual {}

    /// @notice Register a new ProvenanceClaim without an associated NFT.
    ///
    /// @dev - Note that you can pass `royalProtocolAccountId` as the `originatorId` for self-registrations.
    function registerProvenanceWithoutNft(uint256 originatorId, bytes32 contentHash)
        public
        payable
        virtual
        returns (uint256 provenanceClaimId)
    {
        return registerProvenanceWithNft({
            originatorId: originatorId,
            contentHash: contentHash,
            nftContract: address(0),
            nftTokenId: 0
        });
    }

    /// @notice Register a new ProvenanceClaim without an associated NFT.
    ///
    /// Uses an EIP712 signature from the originator instead of assuming delegation.
    function registerProvenanceWithoutNftFor(
        uint256 originatorId,
        bytes32 contentHash,
        uint256 deadline,
        bytes calldata sig
    ) public payable virtual returns (uint256 provenanceClaimId) {
        return registerProvenanceWithNftFor({
            originatorId: originatorId,
            contentHash: contentHash,
            nftContract: address(0),
            nftTokenId: 0,
            deadline: deadline,
            sig: sig
        });
    }

    /// @notice Register a new ProvenanceClaim with an associated NFT.
    ///
    /// @dev - Note that you can pass `royalProtocolAccountId` as the `originatorId` for self-registrations.
    function registerProvenanceWithNft(
        uint256 originatorId,
        bytes32 contentHash,
        address nftContract,
        uint256 nftTokenId
    ) public payable virtual returns (uint256 provenanceClaimId) {
        _authorizeProvenanceRegistration();

        if (isDuplicateClaimCheckEnabled) {
            uint256 existingClaimId = provenanceClaimIdOfContentHash[contentHash];
            if (existingClaimId != 0) revert ContentHashAlreadyClaimed();

            // If registration fails, the whole tx reverts - so update the mapping first.
            provenanceClaimIdOfContentHash[contentHash] = provenanceClaimId;
        }

        uint256 registerFee = provenanceGateway.registerFee();

        // Guarded by override of _authorizeProvenanceRegistration()
        // slither-disable-next-line arbitrary-send-eth
        provenanceClaimId =
            provenanceGateway.register{value: registerFee}(originatorId, contentHash, nftContract, nftTokenId);

        // slither-disable-next-line reentrancy-events
        emit ProvenanceClaimRegistered({
            provenanceClaimId: provenanceClaimId,
            originatorId: originatorId,
            contentHash: contentHash,
            nftContract: nftContract,
            nftTokenId: nftTokenId
        });

        if (nftContract != address(0)) {
            // slither-disable-next-line reentrancy-events
            emit NftAssignedToProvenanceClaim(provenanceClaimId, nftContract, nftTokenId);
        }
    }

    /// @notice Register a new ProvenanceClaim with an associated NFT.
    ///
    /// Uses an EIP712 signature from the originator instead of assuming delegation.
    function registerProvenanceWithNftFor(
        uint256 originatorId,
        bytes32 contentHash,
        address nftContract,
        uint256 nftTokenId,
        uint256 deadline,
        bytes calldata sig
    ) public payable virtual returns (uint256 provenanceClaimId) {
        _authorizeProvenanceRegistration();

        if (isDuplicateClaimCheckEnabled) {
            uint256 existingClaimId = provenanceClaimIdOfContentHash[contentHash];
            if (existingClaimId != 0) revert ContentHashAlreadyClaimed();

            // If registration fails, the whole tx reverts - so update the mapping first.
            provenanceClaimIdOfContentHash[contentHash] = provenanceClaimId;
        }

        uint256 registerFee = provenanceGateway.registerFee();

        // Guarded by override of _authorizeProvenanceRegistration()
        // slither-disable-next-line arbitrary-send-eth
        provenanceClaimId = provenanceGateway.registerFor{value: registerFee}({
            originatorId: originatorId,
            contentHash: contentHash,
            nftContract: nftContract,
            nftTokenId: nftTokenId,
            deadline: deadline,
            sig: sig
        });

        // slither-disable-next-line reentrancy-events
        emit ProvenanceClaimRegistered({
            provenanceClaimId: provenanceClaimId,
            originatorId: originatorId,
            contentHash: contentHash,
            nftContract: nftContract,
            nftTokenId: nftTokenId
        });

        if (nftContract != address(0)) {
            // slither-disable-next-line reentrancy-events
            emit NftAssignedToProvenanceClaim(provenanceClaimId, nftContract, nftTokenId);
        }
    }

    /// @notice Assign an NFT to an existing ProvenanceClaim.
    function assignNftToProvenanceClaim(uint256 provenanceClaimId, address nftContract, uint256 nftTokenId)
        public
        payable
        virtual
    {
        _authorizeProvenanceRegistration();

        emit NftAssignedToProvenanceClaim(provenanceClaimId, nftContract, nftTokenId);

        // NOTE: Never a fee for assigning an NFT to an existing PC.
        provenanceGateway.assignNft(provenanceClaimId, nftContract, nftTokenId);
    }

    /// @notice Assign an NFT to an existing ProvenanceClaim.
    ///
    /// Uses an EIP712 signature from the originator instead of assuming delegation.
    function assignNftToProvenanceClaimFor(
        uint256 provenanceClaimId,
        address nftContract,
        uint256 nftTokenId,
        uint256 deadline,
        bytes calldata sig
    ) public payable virtual {
        _authorizeProvenanceRegistration();

        emit NftAssignedToProvenanceClaim(provenanceClaimId, nftContract, nftTokenId);

        // NOTE: Never a fee for assigning an NFT to an existing PC.
        provenanceGateway.assignNftFor({
            provenanceClaimId: provenanceClaimId,
            nftContract: nftContract,
            nftTokenId: nftTokenId,
            deadline: deadline,
            sig: sig
        });
    }

    // =============================================================
    //                          ADMIN FNs
    // =============================================================

    /// @dev Please override this function to check if `msg.sender` is authorized
    /// to call the following functions managing contract configuration.
    /// ```
    ///     function _authorizeContractConfiguration() internal override onlyOwner {}
    /// ```
    function _authorizeContractConfiguration() internal virtual {}

    /// @notice Set the address of the IdRegistry contract.
    function setIdRegistry(address idRegistry_) external {
        _authorizeContractConfiguration();

        emit IdRegistrySet(address(idRegistry), idRegistry_);

        idRegistry = IIdRegistry(idRegistry_);
    }

    /// @notice Set the address of the IdGateway contract.
    function setIdGateway(address idGateway_) external {
        _authorizeContractConfiguration();

        emit IdGatewaySet(address(idGateway), idGateway_);

        idGateway = IIdGateway(idGateway_);
    }

    /// @notice Set the address of the ProvenanceRegistry contract.
    function setProvenanceRegistry(address provenanceRegistry_) external {
        _authorizeContractConfiguration();

        emit ProvenanceRegistrySet(address(provenanceRegistry), provenanceRegistry_);

        provenanceRegistry = IProvenanceRegistry(provenanceRegistry_);
    }

    /// @notice Set the address of the ProvenanceGateway contract.
    function setProvenanceGateway(address provenanceGateway_) external {
        _authorizeContractConfiguration();

        emit ProvenanceGatewaySet(address(provenanceGateway), provenanceGateway_);

        provenanceGateway = IProvenanceGateway(provenanceGateway_);
    }

    /// @notice Set the flag to enable/disable the duplicate claim check.
    function setDuplicateClaimCheckFlag(bool enabled) external {
        _authorizeContractConfiguration();

        emit DuplicateClaimCheckFlagSet(isDuplicateClaimCheckEnabled, enabled);

        isDuplicateClaimCheckEnabled = enabled;
    }
}
