// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ISchemaResolver} from "./schema-resolver/ISchemaResolver.sol";

import {EMPTY_UID} from "./Common.sol";
import {ISchemaRegistry, FieldDefinition, FieldType, Schema} from "./interfaces/ISchemaRegistry.sol";
import {IIdRegistry} from "./interfaces/IIdRegistry.sol";

import {Withdrawable} from "./abstract/Withdrawable.sol";
import {Initializable} from "solady/utils/Initializable.sol";
import {UUPSUpgradeable} from "solady/utils/UUPSUpgradeable.sol";

/**
 * @title RoyalProtocol SchemaRegistry
 *
 * @notice A registry to register and manage schemas for the RoyalProtocol.
 */
contract SchemaRegistry is ISchemaRegistry, Withdrawable, Initializable, UUPSUpgradeable {
    // =============================================================
    //                           CONSTANTS
    // =============================================================

    /// @inheritdoc ISchemaRegistry
    string public constant VERSION = "2025-02-04";

    // =============================================================
    //                           STORAGE
    // =============================================================

    /// @inheritdoc ISchemaRegistry
    IIdRegistry public idRegistry;

    /// @dev Mapping to store / lookup schemas by their UID.
    mapping(bytes32 schemaUID => Schema schema) internal _registry;

    /// @dev Mapping to help ensure uniqueness of enum values for a given ENUM schema field.
    ///
    /// Would check like - `if (_isInEnum[schemaUID][fieldIndex][enumValue]) { revert InvalidFieldDefinition(); }`
    mapping(bytes32 schemaUID => mapping(uint256 fieldIndex => mapping(string enumValue => bool isInEnum))) internal
        _isInEnum;

    // =============================================================
    //                    CONSTRUCTOR / INITIALIZATION
    // =============================================================

    constructor() {
        _disableInitializers();
    }

    /// @inheritdoc ISchemaRegistry
    function initialize(IIdRegistry idRegistry_, address initialOwner_) external override initializer {
        idRegistry = idRegistry_;
        _initializeOwner(initialOwner_);
    }

    // =============================================================
    //                          REGISTRATION
    // =============================================================

    /// @inheritdoc ISchemaRegistry
    function register(
        string calldata name,
        FieldDefinition[] calldata fields,
        bool revocable,
        bool updatable,
        ISchemaResolver resolver,
        bytes32 salt
    ) external override returns (bytes32 schemaUID) {
        // Check the caller has a valid protocol account
        uint256 accountId = idRegistry.idOf(msg.sender);
        if (accountId == 0) {
            revert MissingProtocolAccount();
        }

        // Check the schema doesn't already exist
        schemaUID = _getUID(accountId, name, salt);
        if (_registry[schemaUID].uid != EMPTY_UID) {
            revert SchemaAlreadyExists();
        }

        // Check name is non-empty
        if (bytes(name).length == 0) {
            revert InvalidName();
        }

        // Validate the fields
        uint256 fieldsLength = fields.length;
        unchecked {
            for (uint256 fieldIndex = 0; fieldIndex < fieldsLength; fieldIndex++) {
                _validateField(schemaUID, fieldIndex, fields[fieldIndex]);
            }
        }

        // Register the schema
        _registry[schemaUID] = Schema({
            uid: schemaUID,
            ownerId: accountId,
            name: name,
            fields: fields,
            revocable: revocable,
            updatable: updatable,
            resolver: resolver
        });

        emit SchemaRegistered(schemaUID, accountId);
    }

    // =============================================================
    //                      UPDATE SCHEMA
    // =============================================================

    /// @inheritdoc ISchemaRegistry
    function updateName(bytes32 schemaUID, string calldata name) external override {
        // Check if schema exists
        if (_registry[schemaUID].uid == EMPTY_UID) {
            revert SchemaNonexistent();
        }

        // Check permission to update name (only the schema owner can update the name)
        uint256 accountId = idRegistry.idOf(msg.sender);
        if (accountId != _registry[schemaUID].ownerId || accountId == 0) {
            revert Unauthorized();
        }

        // Check name is non-empty
        if (bytes(name).length == 0) {
            revert InvalidName();
        }

        // Update the name
        _registry[schemaUID].name = name;
        emit SchemaNameUpdated(schemaUID, name);
    }

    /// @inheritdoc ISchemaRegistry
    function updateResolver(bytes32 schemaUID, ISchemaResolver resolver) external override {
        // Check if schema exists
        if (_registry[schemaUID].uid == EMPTY_UID) {
            revert SchemaNonexistent();
        }

        // Check permission to update resolver (only the schema owner can update the resolver)
        uint256 accountId = idRegistry.idOf(msg.sender);
        if (accountId != _registry[schemaUID].ownerId || accountId == 0) {
            revert Unauthorized();
        }

        // Update the resolver
        _registry[schemaUID].resolver = resolver;
        emit SchemaResolverUpdated(schemaUID, address(resolver));
    }

    // =============================================================
    //                  UPDATE SCHEMA FIELDS
    // =============================================================

    /// @inheritdoc ISchemaRegistry
    function appendFields(bytes32 schemaUID, FieldDefinition[] calldata fields) external override {
        // Check if schema exists
        if (_registry[schemaUID].uid == EMPTY_UID) {
            revert SchemaNonexistent();
        }

        // Check permission to append fields (only the schema owner can append fields)
        uint256 accountId = idRegistry.idOf(msg.sender);
        if (accountId != _registry[schemaUID].ownerId || accountId == 0) {
            revert Unauthorized();
        }

        // Append the fields
        uint256 fieldsLength = fields.length;
        unchecked {
            for (uint256 fieldIndex = 0; fieldIndex < fieldsLength; fieldIndex++) {
                FieldDefinition memory field = fields[fieldIndex];
                _validateField(schemaUID, fieldIndex, field);
                _registry[schemaUID].fields.push(field);
            }
        }

        emit SchemaFieldsAdded(schemaUID, fieldsLength);
    }

    /// @inheritdoc ISchemaRegistry
    function appendEnumValues(bytes32 schemaUID, uint256 fieldIndex, string[] calldata enumValues) external override {
        // Check if schema exists
        if (_registry[schemaUID].uid == EMPTY_UID) {
            revert SchemaNonexistent();
        }

        // Check permission to append enum values (only the schema owner can append enum values)
        uint256 accountId = idRegistry.idOf(msg.sender);
        if (accountId != _registry[schemaUID].ownerId || accountId == 0) {
            revert Unauthorized();
        }

        // Check FieldType is actually ENUM
        if (_registry[schemaUID].fields[fieldIndex].fieldType != FieldType.ENUM) {
            revert InvalidFieldDefinition();
        }

        // and that the provided array is non-empty
        uint256 enumValuesLength = enumValues.length;
        if (enumValuesLength == 0) {
            revert InvalidFieldDefinition();
        }

        // Append the enum values, while validating the enum values
        unchecked {
            for (uint256 i = 0; i < enumValuesLength; i++) {
                string memory enumValue = enumValues[i];

                // Revert if we tried to put an empty string in the enum
                if (bytes(enumValue).length == 0) {
                    revert InvalidFieldDefinition();
                }

                // Revert if the enum value is already in the enum
                if (_isInEnum[schemaUID][fieldIndex][enumValue]) {
                    revert InvalidFieldDefinition();
                }

                // Append the enum value
                _isInEnum[schemaUID][fieldIndex][enumValue] = true;
                _registry[schemaUID].fields[fieldIndex].enumValues.push(enumValue);
            }
        }

        emit SchemaFieldUpdated(schemaUID, fieldIndex);
    }

    /// @inheritdoc ISchemaRegistry
    function appendAllowedSchemaIds(bytes32 schemaUID, uint256 fieldIndex, bytes32[] calldata allowedSchemaIds)
        external
        override
    {
        // Check if schema exists
        if (_registry[schemaUID].uid == EMPTY_UID) {
            revert SchemaNonexistent();
        }

        // Check permission to append allowedSchemaIds (only the schema owner can append allowedSchemaIds)
        uint256 accountId = idRegistry.idOf(msg.sender);
        if (accountId != _registry[schemaUID].ownerId || accountId == 0) {
            revert Unauthorized();
        }

        // Check FieldType is actually RECORD_ID
        if (_registry[schemaUID].fields[fieldIndex].fieldType != FieldType.RECORD_ID) {
            revert InvalidFieldDefinition();
        }

        // Check the field actually has a nonempty allowedSchemaIds[].
        //
        // This is important, because an empty array would mean that the field can reference ANY schema.
        // If that's the case, pushing an ID into that array would not be backwards-compatible.
        if (_registry[schemaUID].fields[fieldIndex].allowedSchemaIds.length == 0) {
            revert InvalidFieldDefinition();
        }

        // Check we were given a non-empty list of allowedSchemaIds
        uint256 allowedSchemaIdsLength = allowedSchemaIds.length;
        if (allowedSchemaIdsLength == 0) {
            revert InvalidFieldDefinition();
        }

        // Append the allowedSchemaIds to the field
        unchecked {
            for (uint256 i = 0; i < allowedSchemaIdsLength; i++) {
                // Revert if we tried to put an empty schemaId in the allowedSchemaIds
                if (_registry[allowedSchemaIds[i]].uid == EMPTY_UID) {
                    revert InvalidFieldDefinition();
                }

                _registry[schemaUID].fields[fieldIndex].allowedSchemaIds.push(allowedSchemaIds[i]);
            }
        }

        emit SchemaFieldUpdated(schemaUID, fieldIndex);
    }

    // =============================================================
    //                    SCHEMA OWNERSHIP
    // =============================================================

    /// @inheritdoc ISchemaRegistry
    function transferSchemaOwnership(bytes32 schemaUID, uint256 newOwnerId) external override {
        // Check if schema exists
        if (_registry[schemaUID].uid == EMPTY_UID) {
            revert InvalidFieldDefinition();
        }

        // Check permission to transfer schema ownership (only the schema owner can transfer ownership)
        uint256 accountId = idRegistry.idOf(msg.sender);
        if (accountId != _registry[schemaUID].ownerId || accountId == 0) {
            revert Unauthorized();
        }

        // Check the new owner is a valid protocol account
        if (newOwnerId == 0 || idRegistry.custodyOf(newOwnerId) == address(0)) {
            revert MissingProtocolAccount();
        }

        // Transfer the schema ownership
        _registry[schemaUID].ownerId = newOwnerId;
        emit SchemaOwnershipTransferred(schemaUID, newOwnerId);
    }

    function renounceSchemaOwnership(bytes32 schemaUID) external override {
        // Check permission to renounce schema ownership (only the schema owner can renounce ownership)
        uint256 accountId = idRegistry.idOf(msg.sender);
        if (accountId != _registry[schemaUID].ownerId || accountId == 0) {
            revert Unauthorized();
        }

        // Revoke the schema ownership
        _registry[schemaUID].ownerId = 0;
        emit SchemaOwnershipRevoked(schemaUID);
    }

    // =============================================================
    //                        READ FNS
    // =============================================================

    /// @inheritdoc ISchemaRegistry
    function getSchema(bytes32 schemaUID) external view override returns (Schema memory) {
        return _registry[schemaUID];
    }

    /// @inheritdoc ISchemaRegistry
    function getSchemas(bytes32[] calldata uids) external view override returns (Schema[] memory schemas) {
        uint256 length = uids.length;
        schemas = new Schema[](length);

        unchecked {
            for (uint256 i = 0; i < length; i++) {
                schemas[i] = _registry[uids[i]];
            }
        }
    }

    // =============================================================
    //                     UID CALCULATION
    // =============================================================

    /// @dev Calculates a UID for a given schema.
    ///
    /// @param originatorId The originator / original owner protocol ID of the schema.
    /// @param name The original name of the schema.
    /// @param salt A salt to ensure uniqueness. (In case an existing schema by this owner with this name was already registered.)
    ///
    /// @return schemaUID.
    function _getUID(uint256 originatorId, string calldata name, bytes32 salt) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(originatorId, name, salt));
    }

    // =============================================================
    //                     FIELD VALIDATION
    // =============================================================

    /// @dev Validates a field definition.
    /// - Checks for empty fieldName.
    /// - Checks for empty enumValues if FieldType is ENUM.
    /// - Checks for duplicate enumValues if FieldType is ENUM.
    /// - Checks enumValues IS EMPTY if FieldType is NOT ENUM.
    /// - Checks allowedSchemaIds IS EMPTY if FieldType is NOT RECORD_ID.
    function _validateField(bytes32 schemaUID, uint256 fieldIndex, FieldDefinition memory field) internal {
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
                for (uint256 i = 0; i < enumValuesLength; i++) {
                    // Revert if we tried to put an empty string in the enum
                    if (bytes(field.enumValues[i]).length == 0) {
                        revert InvalidFieldDefinition();
                    }

                    // Revert if the enum value is already in the enum
                    if (_isInEnum[schemaUID][fieldIndex][field.enumValues[i]]) {
                        revert InvalidFieldDefinition();
                    }

                    // Add the enum value to the uniqueness check mapping
                    _isInEnum[schemaUID][fieldIndex][field.enumValues[i]] = true;
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

    // =============================================================
    //                          UUPS
    // =============================================================

    // solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
