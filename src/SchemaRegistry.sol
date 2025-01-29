// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ISchemaResolver} from "./schema-resolver/ISchemaResolver.sol";

import {EMPTY_UID} from "./Common.sol";
import {ISchemaRegistry, FieldDefinition, FieldType, SchemaRecord} from "./interfaces/ISchemaRegistry.sol";
import {IIdRegistry} from "./interfaces/IIdRegistry.sol";

import {Withdrawable} from "./abstract/Withdrawable.sol";
import {Initializable} from "solady/utils/Initializable.sol";
import {UUPSUpgradeable} from "solady/utils/UUPSUpgradeable.sol";

/// @title SchemaRegistry
/// @notice The global schema registry.
contract SchemaRegistry is ISchemaRegistry, Withdrawable, Initializable, UUPSUpgradeable {
    error AlreadyExists();
    error InvalidRegistry();
    error InvalidFieldDefinition();

    // The global IdRegistry.
    IIdRegistry public idRegistry;

    // The global mapping between schema records and their IDs.
    mapping(bytes32 uid => SchemaRecord schemaRecord) internal _registry;

    /// @notice The version of the schema registry.
    string public constant VERSION = "2025-01-06";

    // =============================================================
    //                    CONSTRUCTOR / INITIALIZATION
    // =============================================================

    constructor() {
        _disableInitializers();
    }

    /// @inheritdoc ISchemaRegistry
    function initialize(address initialOwner_, address idRegistry_) external override initializer {
        _initializeOwner(initialOwner_);

        if (address(idRegistry_) == address(0)) {
            revert InvalidRegistry();
        }

        idRegistry = IIdRegistry(idRegistry_);
    }

    /// @inheritdoc ISchemaRegistry
    function register(FieldDefinition[] calldata fields, ISchemaResolver resolver, bool revocable, bool appendable)
        external
        override
        returns (bytes32 uid)
    {
        uint256 accountId = idRegistry.idOf(msg.sender);
        SchemaRecord memory schemaRecord = SchemaRecord({
            uid: EMPTY_UID,
            ownerId: accountId,
            fields: fields,
            resolver: resolver,
            revocable: revocable,
            appendable: appendable
        });

        uid = _getUID(schemaRecord);
        if (_registry[uid].uid != EMPTY_UID) {
            revert AlreadyExists();
        }

        // TODO: Validate enumValues?
        // Validate the fields
        uint256 fieldsLength = fields.length;
        unchecked {
            for (uint256 i = 0; i < fieldsLength; i++) {
                _validateField(fields[i]);
            }
        }

        schemaRecord.uid = uid;
        _registry[uid] = schemaRecord;

        emit SchemaRegistered(uid, accountId);
    }

    function appendFields(bytes32 uid, FieldDefinition[] calldata fields) external {
        // Check if schema exists and is appendable
        if (!_registry[uid].appendable) {
            revert Unauthorized();
        }

        // Check permission to append fields (only the schema creator can append fields)
        uint256 accountId = idRegistry.idOf(msg.sender);
        if (accountId != _registry[uid].ownerId) {
            revert Unauthorized();
        }

        // Append the fields
        uint256 fieldsLength = fields.length;
        unchecked {
            for (uint256 i = 0; i < fieldsLength; i++) {
                FieldDefinition memory field = fields[i];
                _validateField(field);
                _registry[uid].fields.push(field);
            }
        }

        // TODO: Naming (FieldsAppended?)
        // TODO: Do we _need_ accountId here - since onlly the schema creator can append fields anyways?
        emit SchemaUpdated(uid, fieldsLength);
    }

    function appendEnumValues(bytes32 uid, uint256 fieldIndex, string[] calldata enumValues) external {
        // Check if schema exists and is appendable
        if (!_registry[uid].appendable) {
            revert Unauthorized();
        }

        // Check permission to append enum values (only the schema creator can append enum values)
        uint256 accountId = idRegistry.idOf(msg.sender);
        if (accountId != _registry[uid].ownerId) {
            revert Unauthorized();
        }

        // Check FieldType is actually ENUM
        if (_registry[uid].fields[fieldIndex].fieldType != FieldType.ENUM) {
            revert InvalidFieldDefinition();
        }

        uint256 enumValuesLength = enumValues.length;
        if (enumValuesLength == 0) {
            revert InvalidFieldDefinition();
        }

        // Append the enum values, while validating the enum values
        unchecked {
            for (uint256 i = 0; i < enumValuesLength; i++) {
                // Revert if we tried to put an empty string in the enum
                if (bytes(enumValues[i]).length == 0) {
                    revert InvalidFieldDefinition();
                }

                _registry[uid].fields[fieldIndex].enumValues.push(enumValues[i]);
            }
        }

        // TODO: Naming?
        emit SchemaFieldUpdated(uid, fieldIndex);
    }

    function appendAllowedSchemaIds(bytes32 uid, uint256 fieldIndex, bytes32[] calldata allowedSchemaIds) external {
        // Check if schema exists and is appendable
        if (!_registry[uid].appendable) {
            revert Unauthorized();
        }

        // Check permission to append allowed schema ids (only the schema creator can append allowed schema ids)
        uint256 accountId = idRegistry.idOf(msg.sender);
        if (accountId != _registry[uid].ownerId) {
            revert Unauthorized();
        }

        // Check FieldType is actually RECORD_ID
        if (_registry[uid].fields[fieldIndex].fieldType != FieldType.RECORD_ID) {
            revert InvalidFieldDefinition();
        }

        // Check the field actually has allowed schema ids.
        // This is important, because an empty array - allowedSchemaIds = [],
        // would mean that the field can reference ANY schema.
        // If that's the case, pushing an ID into that array would be non-backwards-compatible.
        if (_registry[uid].fields[fieldIndex].allowedSchemaIds.length == 0) {
            revert InvalidFieldDefinition();
        }

        // Check we were given a non-empty list of allowed schema ids
        uint256 allowedSchemaIdsLength = allowedSchemaIds.length;
        if (allowedSchemaIdsLength == 0) {
            revert InvalidFieldDefinition();
        }

        // Append the allowed schema ids, while validating the schema ids
        unchecked {
            for (uint256 i = 0; i < allowedSchemaIdsLength; i++) {
                // Revert if we tried to put an empty schema id in the allowed schema ids
                if (_registry[allowedSchemaIds[i]].uid == EMPTY_UID) {
                    revert InvalidFieldDefinition();
                }

                _registry[uid].fields[fieldIndex].allowedSchemaIds.push(allowedSchemaIds[i]);
            }
        }

        emit SchemaFieldUpdated(uid, fieldIndex);
    }

    // TODO: Implement this somehow
    //       Maybe have this style and twoStep?
    // function transferSchemaOwnership(bytes32 uid, uint256 newOwnerId) external {
    //     // Check if schema exists
    //     if (_registry[uid].uid == EMPTY_UID) {
    //         revert InvalidFieldDefinition();
    //     }

    //     // Check permission to transfer schema ownership (only the schema creator can transfer ownership)
    //     uint256 accountId = idRegistry.idOf(msg.sender);
    //     if (accountId != _registry[uid].ownerId) {
    //         revert Unauthorized();
    //     }

    //     // Transfer the schema ownership
    //     _registry[uid].ownerId = newOwnerId;
    // }

    // =============================================================
    //                        READ FNS
    // =============================================================

    /// @inheritdoc ISchemaRegistry
    function getSchema(bytes32 uid) external view override returns (SchemaRecord memory) {
        return _registry[uid];
    }

    // =============================================================
    //                          UUPS
    // =============================================================

    // solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    // =============================================================
    //                        HELPERS
    // =============================================================

    /// @dev Calculates a UID for a given schema.
    /// @param schemaRecord The input schema.
    /// @return schemaUID.
    function _getUID(SchemaRecord memory schemaRecord) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                schemaRecord.ownerId,
                schemaRecord.fields,
                schemaRecord.resolver,
                schemaRecord.revocable,
                schemaRecord.appendable
            )
        );
    }

    /// @dev Validates a field definition.
    /// @param field The field definition to validate.
    function _validateField(FieldDefinition memory field) internal view {
        // Validate fieldName
        if (bytes(field.fieldName).length == 0) {
            revert InvalidFieldDefinition();
        }

        uint256 enumValuesLength = field.enumValues.length;
        uint256 allowedSchemaIdsLength = field.allowedSchemaIds.length;

        // Validate ENUM types
        if (field.fieldType == FieldType.ENUM) {
            if (enumValuesLength == 0) revert InvalidFieldDefinition();
            unchecked {
                // TODO: How to check for any dupes in the enumValues?
                for (uint256 i = 0; i < enumValuesLength; i++) {
                    if (bytes(field.enumValues[i]).length == 0) {
                        revert InvalidFieldDefinition();
                    }
                }
            }

            return;
        }

        // If not an ENUM, then there should be no enumValues
        if (enumValuesLength > 0) revert InvalidFieldDefinition();

        // Validate RECORD_ID types
        if (field.fieldType == FieldType.RECORD_ID) {
            // NOTE: If allowedSchemaIds = [], then the field can reference ANY schema.
            // So no empty array check here, since that's allowable behavior.

            unchecked {
                for (uint256 i = 0; i < allowedSchemaIdsLength; i++) {
                    if (_registry[field.allowedSchemaIds[i]].uid == EMPTY_UID) {
                        revert InvalidFieldDefinition();
                    }
                }
            }

            return;
        }

        // If not a RECORD_ID, then there should be no allowedSchemaIds
        if (allowedSchemaIdsLength > 0) revert InvalidFieldDefinition();
    }
}
