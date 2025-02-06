// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IIdRegistry} from "./IIdRegistry.sol";
import {ISchemaRegistry} from "./ISchemaRegistry.sol";

import {Record, Signature} from "../Common.sol";

/// @notice A struct representing the arguments of the record request.
struct RecordRequestData {
    bool revocable; // Whether the record is revocable.
    bool updatable; // Whether the record is updatable.
    bytes data; // Custom record data.
    bytes32 salt; // A salt to use for UID generation. (In case the same (originator, registrar, schema, data) tuple is used multiple times.)
    uint256 value; // An explicit ETH amount to send to the resolver. This is important to prevent accidental user errors.
}

/// @notice A struct representing the full arguments of the record request.
struct RecordRequest {
    bytes32 schema; // The unique identifier of the schema.
    RecordRequestData data; // The arguments of the record request.
}

/// @notice A struct representing the full arguments of the full delegated record request.
struct DelegatedRecordRequest {
    bytes32 schema; // The unique identifier of the schema.
    RecordRequestData data; // The arguments of the record request.
    Signature signature; // The ECDSA signature data.
    uint256 originator; // The account that authored the Record.
    uint256 deadline; // The deadline of the signature/request.
}

/// @notice A struct representing the full arguments of the multi record request.
struct MultiRecordRequest {
    bytes32 schema; // The unique identifier of the schema.
    RecordRequestData[] data; // The arguments of the record request.
}

/// @notice A struct representing the full arguments of the delegated multi record request.
struct MultiDelegatedRecordRequest {
    bytes32 schema; // The unique identifier of the schema.
    RecordRequestData[] data; // The arguments of the record requests.
    Signature[] signatures; // The ECDSA signatures data. Please note that the signatures are assumed to be signed with increasing nonces.
    uint256 originator; // The account that authored the Record.
    uint256 deadline; // The deadline of the signature/request.
}

/// @notice A struct representing the arguments of the revocation request.
struct RevocationRequestData {
    bytes32 uid; // The UID of the record to revoke.
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

/// @title IRecordRegistry
/// @notice RecordRegistry interface.
interface IRecordRegistry {
    /// @notice Emitted when an record has been made.
    /// @param originatorId The account that authored the Record.
    /// @param registrarId The account that registered the Record.
    /// @param recordUID The UID of the new record.
    /// @param schemaUID The UID of the schema.
    event RecordRegistered(
        bytes32 indexed schemaUID, uint256 indexed originatorId, uint256 indexed registrarId, bytes32 recordUID
    );

    /// @notice Emitted when an record has been revoked.
    /// @param schemaUID The UID of the schema.
    /// @param revokerId The account ID of the revoker.
    /// @param registrarId The account that registered the record.
    /// @param recordUID The UID of the revoked record.
    event RecordRevoked(
        bytes32 indexed schemaUID, uint256 indexed revokerId, uint256 indexed registrarId, bytes32 recordUID
    );

    // TODO: Change this to reflect it's not arbitrary data, it's timestampping the UID of some offchain Record?
    /// @notice Emitted when a data has been timestamped.
    /// @param data The data.
    /// @param timestamp The timestamp.
    event Timestamped(bytes32 indexed data, uint64 indexed timestamp);

    // TODO: Is this useful?
    /// @notice Emitted when a data has been revoked.
    /// @param revokerId The account ID of the revoker.
    /// @param registrarId The account that registered the revocation.
    /// @param data The data.
    /// @param timestamp The timestamp.
    event RevokedOffchain(
        uint256 indexed revokerId, uint256 indexed registrarId, bytes32 indexed data, uint64 timestamp
    );

    /* solhint-disable func-name-mixedcase */

    /// @notice Returns the version of the contract.
    function VERSION() external pure returns (string memory);

    /// @notice Returns the typehash of the EIP712 Record struct.
    function REGISTER_TYPEHASH() external pure returns (bytes32);

    /// @notice Returns the typehash of the EIP712 Revoke struct.
    function REVOKE_TYPEHASH() external pure returns (bytes32);

    /// @dev Creates a new RecordRegistry instance.
    /// @param schemaRegistry_ The address of the protocol's SchemaRegistry.
    /// @param idRegistry_ The address of the protocol's IdRegistry for AccountIDs.
    /// @param initialOwner_ The address of the initial contract owner.
    function initialize(ISchemaRegistry schemaRegistry_, IIdRegistry idRegistry_, address initialOwner_) external;

    /* solhint-enable func-name-mixedcase */

    /// @notice Register a Record utilizing a specific schema.
    /// @param originator The account that authored the Record.
    /// @param request The arguments of the record request.
    /// @return uid The UID of the new record.
    ///
    /// Example:
    ///     register(
    ///         originator: 123,
    ///         request: {
    ///             schema: "0facc36681cbe2456019c1b0d1e7bedd6d1d40f6f324bf3dd3a4cef2999200a0",
    ///             data: {
    ///                 originatorId: 123,
    ///                 revocable: true,
    ///                 updatable: true,
    ///                 data: "0xF00D",
    ///                 value: 0
    ///             }
    ///         }
    ///     )
    function register(uint256 originator, RecordRequest calldata request) external payable returns (bytes32 uid);

    /// @notice Register a Record utilizing a specific schema via the provided ECDSA signature.
    /// @param delegatedRequest The arguments of the delegated record request.
    /// @return uid The UID of the new record.
    ///
    /// Example:
    ///     registerByDelegation({
    ///         schema: '0x8e72f5bc0a8d4be6aa98360baa889040c50a0e51f32dbf0baa5199bd93472ebc',
    ///         data: {
    ///             revocable: true,
    ///             updatable: true,
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
    function registerByDelegation(DelegatedRecordRequest calldata delegatedRequest)
        external
        payable
        returns (bytes32 uid);

    /// @notice Registers multiple Records utlizing multiple schemas.
    /// @param originator The account that authored the Records.
    /// @param multiRequests The arguments of the multi record requests. The requests should be grouped by distinct
    ///     schema ids to benefit from the best batching optimization.
    /// @return uids The UIDs of the new Records.
    ///
    /// Example:
    ///     multiRegister([{
    ///         schema: '0x33e9094830a5cba5554d1954310e4fbed2ef5f859ec1404619adea4207f391fd',
    ///         data: [{
    ///             revocable: true,
    ///             updatable: true,
    ///             data: '0x1234',
    ///             value: 1000
    ///         },
    ///         {
    ///             revocable: false,
    ///             updatable: false,
    ///             data: '0x00',
    ///             value: 0
    ///         }],
    ///     },
    ///     {
    ///         schema: '0x5ac273ce41e3c8bfa383efe7c03e54c5f0bff29c9f11ef6ffa930fc84ca32425',
    ///         data: [{
    ///             revocable: true,
    ///             updatable: true,
    ///             data: '0x12345678',
    ///             value: 0
    ///         },
    ///     }])
    function multiRegister(uint256 originator, MultiRecordRequest[] calldata multiRequests)
        external
        payable
        returns (bytes32[] memory uids);

    /// @notice Register Records utilzing multiple schemas using via provided ECDSA signatures.
    /// @param multiDelegatedRequests The arguments of the delegated multi record requests. The requests should be
    ///     grouped by distinct schema ids to benefit from the best batching optimization.
    /// @return uids The UIDs of the new records.
    ///
    /// Example:
    ///     multiRegisterByDelegation([{
    ///         schema: '0x8e72f5bc0a8d4be6aa98360baa889040c50a0e51f32dbf0baa5199bd93472ebc',
    ///         data: [{
    ///             revocable: true,
    ///             updatable: true,
    ///             data: '0x1234',
    ///             value: 0
    ///         },
    ///         {
    ///             revocable: false,
    ///             updatable: false,
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
    function multiRegisterByDelegation(MultiDelegatedRecordRequest[] calldata multiDelegatedRequests)
        external
        payable
        returns (bytes32[] memory uids);

    /// @notice Revokes an existing record to a specific schema.
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

    /// @notice Revokes an existing record to a specific schema via the provided ECDSA signature.
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

    /// @notice Revokes existing records to multiple schemas.
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

    /// @notice Revokes existing records to multiple schemas via provided ECDSA signatures.
    /// @param multiDelegatedRequests The arguments of the delegated multi revocation record requests. The requests
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

    /// @notice Returns an existing record by UID.
    /// @param recordUID The UID of the record to retrieve.
    /// @return record The record data members.
    function getRecord(bytes32 recordUID) external view returns (Record memory record);

    /// @notice Returns an existing record by UID.
    /// @param recordUIDs The UIDs of the records to retrieve.
    /// @return records The records.
    function getRecords(bytes32[] calldata recordUIDs) external view returns (Record[] memory records);

    /// @notice Checks whether an record exists.
    /// @param uid The UID of the record to retrieve.
    /// @return exists Whether an record exists.
    function isRecordValid(bytes32 uid) external view returns (bool exists);

    /// @notice Returns the timestamp that the specified data was timestamped with.
    /// @param data The data to query.
    /// @return timestamp The timestamp the data was timestamped with.
    function getTimestamp(bytes32 data) external view returns (uint64 timestamp);

    /// @notice Returns the timestamp that the specified data was timestamped with.
    /// @param data The data to query.
    /// @return revokeTimestamp The timestamp the data was timestamped with.
    function getRevokeOffchain(uint256 revoker, bytes32 data) external view returns (uint64 revokeTimestamp);

    /// @notice Reverts if the caller cannot register a Record on behalf of the originator.
    /// @param originator The authoring account.
    /// @return registrar The registrar of the record.
    function canRegister(uint256 originator) external view returns (uint256 registrar);

    /// @notice Reverts if the caller cannot revoke the record.
    /// @param revoker The account ID of the revoker.
    /// @return registrar The registrar of the record.
    function canRevoke(uint256 revoker) external view returns (uint256 registrar);
}
