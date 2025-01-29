// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ISchemaResolver} from "../schema-resolver/ISchemaResolver.sol";

/// @notice A struct representing a record for a submitted schema.
struct SchemaRecord {
    bytes32 uid; // The unique identifier of the schema.
    uint256 ownerId; // The AccountID of the account that can maintain the schema.
    ISchemaResolver resolver; // Optional schema resolver.
    bool revocable; // Whether the schema allows revocations explicitly.
    bool appendable; // Whether the schema allows appending new fields, enum values, and allowable schema IDs.
    FieldDefinition[] fields; // Custom specification of the schema fields.
}

/// @notice A struct representing a field definition in a schema.
struct FieldDefinition {
    string fieldName;
    FieldType fieldType;
    bool isArray;
    bytes32[] allowedSchemaIds;
    // If FieldType == ENUM, this is the 0-indexed stringy values of that enum for human readability.
    // But the actual _value_ of this field would basically be a uint8.
    // TODO: Validation around enumValues?? That all strings are unique??
    string[] enumValues;
}

// Add more as needed... (TODO: explode uint, int, bytes1-32, ?? - any core value types missing?)
// TODO: Add inline code comments on the custom types.
enum FieldType {
    BOOL,
    ADDRESS,
    BYTES32,
    UINT32,
    UINT64,
    UINT256,
    INT32,
    INT64,
    INT256,
    STRING,
    BYTES,
    ACCOUNT_ID, // uint256 of an accountId on the IdRegistry contract living at...
    PROVENANCE_CLAIM_ID, // uint256
    CONTENT_HASH, // bytes32
    RECORD_ID, // bytes32
    SCHEMA_ID, // bytes32
    ENUM, // uint8?
    URL // string - but ideally a valid URL

}

/// @title ISchemaRegistry
/// @notice The interface of global attestation schemas for the Ethereum Attestation Service protocol.
interface ISchemaRegistry {
    /// @notice Emitted when a new schema has been registered
    /// @param uid The schema UID.
    /// @param originator The AccountID of the account used to register the schema.
    event SchemaRegistered(bytes32 indexed uid, uint256 indexed originator);

    /// @notice Emitted when a schema has been updated (fields were appended)
    /// @param uid The schema UID.
    event SchemaUpdated(bytes32 indexed uid, uint256 numAddedFields);

    /// @notice Emitted when a field (ENUM, RECORD_ID) has been updated.
    /// @param uid The schema UID.
    /// @param fieldIndex The index of the field.
    event SchemaFieldUpdated(bytes32 indexed uid, uint256 indexed fieldIndex);

    /// @dev Creates a new AttestationRegistry instance.
    /// @param initialOwner_ The address of the initial owner.
    /// @param idRegistry_ The address of the global ID registry.
    function initialize(address initialOwner_, address idRegistry_) external;

    /// @notice Submits and reserves a new schema
    /// @param fields The fields that make up the schema (ordered in the array).
    /// @param resolver An optional schema resolver.
    /// @param revocable Whether the schema allows revocations explicitly.
    /// @param appendable Whether the schema allows appending new fields, enum values, and allowable schema IDs.
    /// @return uid The UID of the new schema.
    function register(FieldDefinition[] calldata fields, ISchemaResolver resolver, bool revocable, bool appendable)
        external
        returns (bytes32 uid);

    /// @notice Returns an existing schema by UID
    /// @param uid The UID of the schema to retrieve.
    /// @return schema The schema data members.
    function getSchema(bytes32 uid) external view returns (SchemaRecord memory schema);
}
