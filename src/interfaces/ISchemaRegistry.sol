// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ISchemaResolver} from "../schema-resolver/ISchemaResolver.sol";

/// @notice A struct representing a record for a submitted schema.
struct SchemaRecord {
    bytes32 uid; // The unique identifier of the schema.
    ISchemaResolver resolver; // Optional schema resolver.
    bool revocable; // Whether the schema allows revocations explicitly.
    string schema; // Custom specification of the schema (e.g., an ABI).
}

/// @title ISchemaRegistry
/// @notice The interface of global attestation schemas for the Ethereum Attestation Service protocol.
interface ISchemaRegistry {
    /// @notice Emitted when a new schema has been registered
    /// @param uid The schema UID.
    /// @param registerer The address of the account used to register the schema.
    /// @param schema The schema data.
    event Registered(bytes32 indexed uid, address indexed registerer, SchemaRecord schema);

    /// @dev Creates a new AttestationRegistry instance.
    /// @param initialOwner_ The address of the initial owner.
    function initialize(address initialOwner_) external;

    /// @notice Submits and reserves a new schema
    /// @param schema The schema data schema.
    /// @param resolver An optional schema resolver.
    /// @param revocable Whether the schema allows revocations explicitly.
    /// @return uid The UID of the new schema.
    function register(string calldata schema, ISchemaResolver resolver, bool revocable)
        external
        returns (bytes32 uid);

    /// @notice Returns an existing schema by UID
    /// @param uid The UID of the schema to retrieve.
    /// @return schema The schema data members.
    function getSchema(bytes32 uid) external view returns (SchemaRecord memory schema);
}