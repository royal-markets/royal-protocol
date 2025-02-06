// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IIdRegistry} from "./IIdRegistry.sol";
import {ISchemaResolver} from "../schema-resolver/ISchemaResolver.sol";

/// @notice A struct representing a schema definition.
struct Schema {
    bytes32 uid; // The unique identifier of the schema.
    uint256 ownerId; // The AccountID of the account that can maintain the schema.
    string name; // The name of the schema.
    FieldDefinition[] fields; // Specification of the schema fields.
    bool revocable; // Whether the schema allows corresponding Records to be revoked.
    bool updatable; // Whether the schema allows corresponding Records to be updated.
    ISchemaResolver resolver; // Optional schema resolver.
}

/// @notice A struct representing a field definition in a schema.
struct FieldDefinition {
    string fieldName; // The name of the field.
    FieldType fieldType; // The type of the field.
    bool isArray; // Whether the field is an array.
    bytes32[] allowedSchemaIds; // If the field type is RECORD_ID, the allowed schema IDs.
    string[] enumValues; // If the field type is ENUM, the enum values.
}

/// @notice The enumeration of valid field types for a schema field.
///
/// @dev There are a few custom types not found in Solidity.
///      These help indexers and other off-chain systems parse and make sense of Records / Schemas.
///
/// - ACCOUNT_ID (uint256):          An ACCOUNT_ID from the IdRegistry contract.
/// - PROVENANCE_CLAIM_ID (uint256): A PROVENANCE_CLAIM_ID from the ProvenanceRegistry contract.
/// - CONTENT_HASH (bytes32):        A blake3 hash of some content. (Often used with a ProvenanceClaim).
/// - RECORD_ID (bytes32):           A RECORD_ID from the RecordRegistry contract.
/// - SCHEMA_ID (bytes32):           A SCHEMA_ID from the SchemaRegistry contract.
/// - ENUM (uint8):                  An ENUM value from a schema field's enumValues array.
/// - URL (string):                  ideally a valid URL!
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
    ACCOUNT_ID,
    PROVENANCE_CLAIM_ID,
    CONTENT_HASH,
    RECORD_ID,
    SCHEMA_ID,
    ENUM,
    URL
}

/// @title ISchemaRegistry
/// @notice The interface for the SchemaRegistry contract.
interface ISchemaRegistry {
    // =============================================================
    //                           EVENTS
    // =============================================================

    /// @notice Emitted when a new schema has been registered
    /// @param schemaUID The schema UID.
    /// @param originatorId The AccountID of the account used to register the schema.
    event SchemaRegistered(bytes32 indexed schemaUID, uint256 indexed originatorId);

    /// @notice Emitted when a schemas's name has been updated
    /// @param schemaUID The schema UID.
    /// @param name The new name of the schema.
    event SchemaNameUpdated(bytes32 indexed schemaUID, string name);

    /// @notice Emitted when a schema resolver has been updated
    /// @param schemaUID The schema UID.
    /// @param resolver The address of the new schema resolver.
    event SchemaResolverUpdated(bytes32 indexed schemaUID, address resolver);

    /// @notice Emitted when a schema has had new fields appended to its definition
    /// @param schemaUID The schema UID.
    /// @param numAddedFields The number of fields added.
    event SchemaFieldsAdded(bytes32 indexed schemaUID, uint256 numAddedFields);

    /// @notice Emitted when a schema field (of type ENUM or RECORD_ID) has been updated.
    /// @param schemaUID The schema UID.
    /// @param fieldIndex The index of the field in the fields array.
    event SchemaFieldUpdated(bytes32 indexed schemaUID, uint256 indexed fieldIndex);

    /// @notice Emitted when a schema is transferred to a new owner
    /// @param schemaUID The schema UID.
    /// @param newOwnerId The AccountID of the new owner.
    event SchemaOwnershipTransferred(bytes32 indexed schemaUID, uint256 indexed newOwnerId);

    /// @notice Emitted when a schema has its ownership revoked (i.e. it can no longer be updated)
    /// @param schemaUID The schema UID.
    event SchemaOwnershipRevoked(bytes32 indexed schemaUID);

    // =============================================================
    //                          ERRORS
    // =============================================================

    /// @dev Revert when the caller or transferee does not (yet) have a protocol account.
    error MissingProtocolAccount();

    /// @dev Revert when a schema with the same UID already exists.
    error SchemaAlreadyExists();

    /// @dev Revert when an empty string is provided for the schema name.
    error InvalidName();

    /// @dev Revert when an invalid field definition is provided.
    error InvalidFieldDefinition();

    /// @dev Revert when attempting to update a schema that does not exist.
    error SchemaNonexistent();

    // =============================================================
    //                           CONSTANTS
    // =============================================================

    /* solhint-disable func-name-mixedcase */

    /// @notice Contract version specified in the RoyalProtocol version scheme.
    function VERSION() external view returns (string memory);

    /* solhint-enable func-name-mixedcase */

    // =============================================================
    //                            STORAGE
    // =============================================================

    /// @notice The RoyalProtocol IdRegistry contract.
    function idRegistry() external view returns (IIdRegistry);

    // =============================================================
    //                        INITIALIZATION
    // =============================================================

    /**
     * @notice Initialize the SchemaRegistry contract with the provided `idRegistry_` and `initialOwner_`.
     *
     * @param idRegistry_ The RoyalProtocol IdRegistry contract address.
     * @param initialOwner_ The initial owner of the contract.
     */
    function initialize(IIdRegistry idRegistry_, address initialOwner_) external;

    // =============================================================
    //                          REGISTRATION
    // =============================================================

    /**
     * @notice Register a new schema.
     *
     * NOTE: The caller's AccountID is set to the initial ownerId of the schema.
     *
     * @param name The name of the schema.
     * @param fields The fields that make up the schema definition.
     * @param resolver A (optional) schema resolver.
     * @param revocable Whether the schema allows corresponding Records to be revoked.
     * @param updatable Whether the schema allows corresponding Records to be updated.
     * @param salt A (optional) salt to use for the schema UID calculation.
     *
     * @return schemaUID The UID of the new schema.
     */
    function register(
        string calldata name,
        FieldDefinition[] calldata fields,
        bool revocable,
        bool updatable,
        ISchemaResolver resolver,
        bytes32 salt
    ) external returns (bytes32 schemaUID);

    // =============================================================
    //                      UPDATE SCHEMA
    // =============================================================
    /**
     * @notice Updates the name of an existing schema (only callable by the schema owner)
     *
     * @param schemaUID The UID of the schema to update.
     * @param name The new name of the schema.
     */
    function updateName(bytes32 schemaUID, string calldata name) external;
    /**
     * @notice Updates the schema resolver of an existing schema (only callable by the schema owner)
     *
     * @param schemaUID The UID of the schema to update.
     * @param resolver The new schema resolver.
     */
    function updateResolver(bytes32 schemaUID, ISchemaResolver resolver) external;

    // =============================================================
    //                  UPDATE SCHEMA FIELDS
    // =============================================================

    /**
     * @notice Appends new fields to an existing schema (only callable by the schema owner)
     *
     * @param schemaUID The UID of the schema to append the new fields to.
     * @param fields The new fields to append to the schema.
     */
    function appendFields(bytes32 schemaUID, FieldDefinition[] calldata fields) external;

    /**
     * @notice Appends enum values to an existing ENUM schema field (only callable by the schema owner)
     *
     * @param schemaUID The UID of the schema to update.
     * @param fieldIndex The index of the field to update in the fields array.
     * @param enumValues The new enum values to append to the field.
     */
    function appendEnumValues(bytes32 schemaUID, uint256 fieldIndex, string[] calldata enumValues) external;

    /**
     * @notice Appends new allowable schemaIds to an existing RECORD_ID schema field (only callable by the schema owner)
     *
     * @param schemaUID The UID of the schema to update.
     * @param fieldIndex The index of the field to update in the fields array.
     * @param allowedSchemaIds The new allowable schemaIds to append to the field.
     */
    function appendAllowedSchemaIds(bytes32 schemaUID, uint256 fieldIndex, bytes32[] calldata allowedSchemaIds)
        external;

    // =============================================================
    //                    SCHEMA OWNERSHIP
    // =============================================================

    /**
     * @notice Transfers ownership of a schema to a new owner (only callable by the schema owner)
     *
     * @param schemaUID The UID of the schema to transfer.
     * @param newOwnerId The AccountID of the new owner.
     */
    function transferSchemaOwnership(bytes32 schemaUID, uint256 newOwnerId) external;

    /// @notice Renounces ownership of a schema to make it non-updatable (only callable by the schema owner)
    function renounceSchemaOwnership(bytes32 schemaUID) external;

    // =============================================================
    //                        READ FNS
    // =============================================================

    /// @notice Fetch a schema object by its UID.
    function getSchema(bytes32 schemaUID) external view returns (Schema memory schema);

    /// @notice Fetch multiple schema objects by their UIDs.
    function getSchemas(bytes32[] calldata uids) external view returns (Schema[] memory schemas);
}
