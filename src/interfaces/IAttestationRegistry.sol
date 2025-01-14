// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Attestation, Signature} from "../Common.sol";

/// @notice A struct representing the arguments of the attestation request.
struct AttestationRequestData {
    uint64 expirationTime; // The time when the attestation expires (Unix timestamp).
    bool revocable; // Whether the attestation is revocable.
    bytes data; // Custom attestation data.
    uint256 value; // An explicit ETH amount to send to the resolver. This is important to prevent accidental user errors.
}

/// @notice A struct representing the full arguments of the attestation request.
struct AttestationRequest {
    bytes32 schema; // The unique identifier of the schema.
    AttestationRequestData data; // The arguments of the attestation request.
}

/// @notice A struct representing the full arguments of the full delegated attestation request.
struct DelegatedAttestationRequest {
    bytes32 schema; // The unique identifier of the schema.
    AttestationRequestData data; // The arguments of the attestation request.
    Signature signature; // The ECDSA signature data.
    uint256 originator; // The attesting account.
    uint256 deadline; // The deadline of the signature/request.
}

/// @notice A struct representing the full arguments of the multi attestation request.
struct MultiAttestationRequest {
    bytes32 schema; // The unique identifier of the schema.
    AttestationRequestData[] data; // The arguments of the attestation request.
}

/// @notice A struct representing the full arguments of the delegated multi attestation request.
struct MultiDelegatedAttestationRequest {
    bytes32 schema; // The unique identifier of the schema.
    AttestationRequestData[] data; // The arguments of the attestation requests.
    Signature[] signatures; // The ECDSA signatures data. Please note that the signatures are assumed to be signed with increasing nonces.
    uint256 originator; // The attesting account.
    uint256 deadline; // The deadline of the signature/request.
}

/// @notice A struct representing the arguments of the revocation request.
struct RevocationRequestData {
    bytes32 uid; // The UID of the attestation to revoke.
    uint256 value; // An explicit ETH amount to send to the resolver. This is important to prevent accidental user errors.
}

/// @notice A struct representing the full arguments of the revocation request.
struct RevocationRequest {
    bytes32 schema; // The unique identifier of the schema.
    RevocationRequestData data; // The arguments of the revocation request.
}

/// @notice A struct representing the arguments of the full delegated revocation request.
struct DelegatedRevocationRequest {
    bytes32 schema; // The unique identifier of the schema.
    RevocationRequestData data; // The arguments of the revocation request.
    Signature signature; // The ECDSA signature data.
    uint256 revoker; // The revoking account.
    uint64 deadline; // The deadline of the signature/request.
}

/// @notice A struct representing the full arguments of the multi revocation request.
struct MultiRevocationRequest {
    bytes32 schema; // The unique identifier of the schema.
    RevocationRequestData[] data; // The arguments of the revocation request.
}

/// @notice A struct representing the full arguments of the delegated multi revocation request.
struct MultiDelegatedRevocationRequest {
    bytes32 schema; // The unique identifier of the schema.
    RevocationRequestData[] data; // The arguments of the revocation requests.
    Signature[] signatures; // The ECDSA signatures data. Please note that the signatures are assumed to be signed with increasing nonces.
    uint256 revoker; // The revoking account.
    uint64 deadline; // The deadline of the signature/request.
}

/// @title IAttestationRegistry
/// @notice AttestationRegistry interface.
interface IAttestationRegistry {
    /// @notice Emitted when an attestation has been made.
    /// @param originator The attesting account.
    /// @param registrar The account that registered the attestation.
    /// @param uid The UID of the new attestation.
    /// @param schemaUID The UID of the schema.
    event Attested(uint256 indexed originator, uint256 indexed registrar, bytes32 uid, bytes32 indexed schemaUID);

    /// @notice Emitted when an attestation has been revoked.
    /// @param revoker The account ID of the revoker.
    /// @param registrar The account that registered the attestation.
    /// @param uid The UID the revoked attestation.
    /// @param schemaUID The UID of the schema.
    event Revoked(uint256 indexed revoker, uint256 indexed registrar, bytes32 uid, bytes32 indexed schemaUID);

    /// @notice Emitted when a data has been timestamped.
    /// @param data The data.
    /// @param timestamp The timestamp.
    event Timestamped(bytes32 indexed data, uint64 indexed timestamp);

    /// @notice Emitted when a data has been revoked.
    /// @param revoker The account ID of the revoker.
    /// @param registrar The account that registered the revocation.
    /// @param data The data.
    /// @param timestamp The timestamp.
    event RevokedOffchain(uint256 indexed revoker, uint256 indexed registrar, bytes32 indexed data, uint64 timestamp);

    /* solhint-disable func-name-mixedcase */

    /// @notice Returns the version of the contract.
    function VERSION() external pure returns (string memory);

    /// @notice Returns the typehash of the EIP712 Attestation struct.
    function ATTEST_TYPEHASH() external pure returns (bytes32);

    /// @notice Returns the typehash of the EIP712 Revoke struct.
    function REVOKE_TYPEHASH() external pure returns (bytes32);

    /// @dev Creates a new AttestationRegistry instance.
    /// @param initialOwner_ The address of the initial owner.
    /// @param schemaRegistry_ The address of the global schema registry.
    /// @param idRegistry_ The address of the global IdRegistry.
    function initialize(address initialOwner_, address schemaRegistry_, address idRegistry_) external;

    /* solhint-enable func-name-mixedcase */

    /// @notice Attests to a specific schema.
    /// @param originator The attesting account.
    /// @param request The arguments of the attestation request.
    /// @return uid The UID of the new attestation.
    ///
    /// Example:
    ///     attest({
    ///         schema: "0facc36681cbe2456019c1b0d1e7bedd6d1d40f6f324bf3dd3a4cef2999200a0",
    ///         data: {
    ///             originatorId: 123,
    ///             expirationTime: 0,
    ///             revocable: true,
    ///             data: "0xF00D",
    ///             value: 0
    ///         }
    ///     })
    function attest(uint256 originator, AttestationRequest calldata request) external payable returns (bytes32 uid);

    /// @notice Attests to a specific schema via the provided ECDSA signature.
    /// @param delegatedRequest The arguments of the delegated attestation request.
    /// @return uid The UID of the new attestation.
    ///
    /// Example:
    ///     attestByDelegation({
    ///         schema: '0x8e72f5bc0a8d4be6aa98360baa889040c50a0e51f32dbf0baa5199bd93472ebc',
    ///         data: {
    ///             expirationTime: 1673891048,
    ///             revocable: true,
    ///             data: '0x1234',
    ///             value: 0
    ///         },
    ///         signature: {
    ///             v: 28,
    ///             r: '0x148c...b25b',
    ///             s: '0x5a72...be22'
    ///         },
    ///         originator: 123,
    ///         deadline: 1673891048
    ///     })
    function attestByDelegation(DelegatedAttestationRequest calldata delegatedRequest)
        external
        payable
        returns (bytes32 uid);

    /// @notice Attests to multiple schemas.
    /// @param originator The attesting account.
    /// @param multiRequests The arguments of the multi attestation requests. The requests should be grouped by distinct
    ///     schema ids to benefit from the best batching optimization.
    /// @return uids The UIDs of the new attestations.
    ///
    /// Example:
    ///     multiAttest([{
    ///         schema: '0x33e9094830a5cba5554d1954310e4fbed2ef5f859ec1404619adea4207f391fd',
    ///         data: [{
    ///             expirationTime: 1673891048,
    ///             revocable: true,
    ///             data: '0x1234',
    ///             value: 1000
    ///         },
    ///         {
    ///             expirationTime: 0,
    ///             revocable: false,
    ///             data: '0x00',
    ///             value: 0
    ///         }],
    ///     },
    ///     {
    ///         schema: '0x5ac273ce41e3c8bfa383efe7c03e54c5f0bff29c9f11ef6ffa930fc84ca32425',
    ///         data: [{
    ///             expirationTime: 0,
    ///             revocable: true,
    ///             data: '0x12345678',
    ///             value: 0
    ///         },
    ///     }])
    function multiAttest(uint256 originator, MultiAttestationRequest[] calldata multiRequests)
        external
        payable
        returns (bytes32[] memory uids);

    /// @notice Attests to multiple schemas using via provided ECDSA signatures.
    /// @param multiDelegatedRequests The arguments of the delegated multi attestation requests. The requests should be
    ///     grouped by distinct schema ids to benefit from the best batching optimization.
    /// @return uids The UIDs of the new attestations.
    ///
    /// Example:
    ///     multiAttestByDelegation([{
    ///         schema: '0x8e72f5bc0a8d4be6aa98360baa889040c50a0e51f32dbf0baa5199bd93472ebc',
    ///         data: [{
    ///             expirationTime: 1673891048,
    ///             revocable: true,
    ///             data: '0x1234',
    ///             value: 0
    ///         },
    ///         {
    ///             expirationTime: 0,
    ///             revocable: false,
    ///             data: '0x00',
    ///             value: 0
    ///         }],
    ///         signatures: [{
    ///             v: 28,
    ///             r: '0x148c...b25b',
    ///             s: '0x5a72...be22'
    ///         },
    ///         {
    ///             v: 28,
    ///             r: '0x487s...67bb',
    ///             s: '0x12ad...2366'
    ///         }],
    ///         originator: 123,
    ///         deadline: 1673891048
    ///     }])
    function multiAttestByDelegation(MultiDelegatedAttestationRequest[] calldata multiDelegatedRequests)
        external
        payable
        returns (bytes32[] memory uids);

    /// @notice Revokes an existing attestation to a specific schema.
    /// @param revoker The account ID of the revoker.
    /// @param request The arguments of the revocation request.
    ///
    /// Example:
    ///     revoke({
    ///         schema: '0x8e72f5bc0a8d4be6aa98360baa889040c50a0e51f32dbf0baa5199bd93472ebc',
    ///         data: {
    ///             uid: '0x101032e487642ee04ee17049f99a70590c735b8614079fc9275f9dd57c00966d',
    ///             value: 0
    ///         }
    ///     })
    function revoke(uint256 revoker, RevocationRequest calldata request) external payable;

    /// @notice Revokes an existing attestation to a specific schema via the provided ECDSA signature.
    /// @param delegatedRequest The arguments of the delegated revocation request.
    ///
    /// Example:
    ///     revokeByDelegation({
    ///         schema: '0x8e72f5bc0a8d4be6aa98360baa889040c50a0e51f32dbf0baa5199bd93472ebc',
    ///         data: {
    ///             uid: '0xcbbc12102578c642a0f7b34fe7111e41afa25683b6cd7b5a14caf90fa14d24ba',
    ///             value: 0
    ///         },
    ///         signature: {
    ///             v: 27,
    ///             r: '0xb593...7142',
    ///             s: '0x0f5b...2cce'
    ///         },
    ///         revoker: 123,
    ///         deadline: 1673891048
    ///     })
    function revokeByDelegation(DelegatedRevocationRequest calldata delegatedRequest) external payable;

    /// @notice Revokes existing attestations to multiple schemas.
    /// @param revoker The account ID of the revoker.
    /// @param multiRequests The arguments of the multi revocation requests. The requests should be grouped by distinct
    ///     schema ids to benefit from the best batching optimization.
    ///
    /// Example:
    ///     multiRevoke([{
    ///         schema: '0x8e72f5bc0a8d4be6aa98360baa889040c50a0e51f32dbf0baa5199bd93472ebc',
    ///         data: [{
    ///             uid: '0x211296a1ca0d7f9f2cfebf0daaa575bea9b20e968d81aef4e743d699c6ac4b25',
    ///             value: 1000
    ///         },
    ///         {
    ///             uid: '0xe160ac1bd3606a287b4d53d5d1d6da5895f65b4b4bab6d93aaf5046e48167ade',
    ///             value: 0
    ///         }],
    ///     },
    ///     {
    ///         schema: '0x5ac273ce41e3c8bfa383efe7c03e54c5f0bff29c9f11ef6ffa930fc84ca32425',
    ///         data: [{
    ///             uid: '0x053d42abce1fd7c8fcddfae21845ad34dae287b2c326220b03ba241bc5a8f019',
    ///             value: 0
    ///         },
    ///     }])
    function multiRevoke(uint256 revoker, MultiRevocationRequest[] calldata multiRequests) external payable;

    /// @notice Revokes existing attestations to multiple schemas via provided ECDSA signatures.
    /// @param multiDelegatedRequests The arguments of the delegated multi revocation attestation requests. The requests
    ///     should be grouped by distinct schema ids to benefit from the best batching optimization.
    ///
    /// Example:
    ///     multiRevokeByDelegation([{
    ///         schema: '0x8e72f5bc0a8d4be6aa98360baa889040c50a0e51f32dbf0baa5199bd93472ebc',
    ///         data: [{
    ///             uid: '0x211296a1ca0d7f9f2cfebf0daaa575bea9b20e968d81aef4e743d699c6ac4b25',
    ///             value: 1000
    ///         },
    ///         {
    ///             uid: '0xe160ac1bd3606a287b4d53d5d1d6da5895f65b4b4bab6d93aaf5046e48167ade',
    ///             value: 0
    ///         }],
    ///         signatures: [{
    ///             v: 28,
    ///             r: '0x148c...b25b',
    ///             s: '0x5a72...be22'
    ///         },
    ///         {
    ///             v: 28,
    ///             r: '0x487s...67bb',
    ///             s: '0x12ad...2366'
    ///         }],
    ///         revoker: 123,
    ///         deadline: 1673891048
    ///     }])
    function multiRevokeByDelegation(MultiDelegatedRevocationRequest[] calldata multiDelegatedRequests)
        external
        payable;

    /// @notice Timestamps the specified bytes32 data.
    /// @param data The data to timestamp.
    /// @return The timestamp the data was timestamped with.
    function timestamp(bytes32 data) external returns (uint64);

    /// @notice Timestamps the specified multiple bytes32 data.
    /// @param data The data to timestamp.
    /// @return The timestamp the data was timestamped with.
    function multiTimestamp(bytes32[] calldata data) external returns (uint64);

    /// @notice Revokes the specified bytes32 data.
    /// @param revoker The account ID of the revoker.
    /// @param data The data to timestamp.
    /// @return revokeTimestamp The timestamp the data was revoked with.
    function revokeOffchain(uint256 revoker, bytes32 data) external returns (uint64 revokeTimestamp);

    /// @notice Revokes the specified multiple bytes32 data.
    /// @param revoker The account ID of the revoker.
    /// @param data The data to timestamp.
    /// @return revokeTimestamp The timestamp the data was revoked with.
    function multiRevokeOffchain(uint256 revoker, bytes32[] calldata data) external returns (uint64 revokeTimestamp);

    /// @notice Returns an existing attestation by UID.
    /// @param uid The UID of the attestation to retrieve.
    /// @return attestation The attestation data members.
    function getAttestation(bytes32 uid) external view returns (Attestation memory attestation);

    /// @notice Checks whether an attestation exists.
    /// @param uid The UID of the attestation to retrieve.
    /// @return exists Whether an attestation exists.
    function isAttestationValid(bytes32 uid) external view returns (bool exists);

    /// @notice Returns the timestamp that the specified data was timestamped with.
    /// @param data The data to query.
    /// @return timestamp The timestamp the data was timestamped with.
    function getTimestamp(bytes32 data) external view returns (uint64 timestamp);

    /// @notice Returns the timestamp that the specified data was timestamped with.
    /// @param data The data to query.
    /// @return revokeTimestamp The timestamp the data was timestamped with.
    function getRevokeOffchain(uint256 revoker, bytes32 data) external view returns (uint64 revokeTimestamp);

    /// @notice Reverts if the caller cannot attest on behalf of the originator.
    /// @param originator The attesting account.
    /// @return registrar The registrar of the attestation.
    function canAttest(uint256 originator) external view returns (uint256 registrar);

    /// @notice Reverts if the caller cannot revoke the attestation.
    /// @param revoker The account ID of the revoker.
    /// @return registrar The registrar of the attestation.
    function canRevoke(uint256 revoker) external view returns (uint256 registrar);
}
