// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ISchemaResolver} from "./schema-resolver/ISchemaResolver.sol";

import {EMPTY_UID} from "./Common.sol";
import {ISchemaRegistry, SchemaRecord} from "./interfaces/ISchemaRegistry.sol";

import {Withdrawable} from "./abstract/Withdrawable.sol";
import {Initializable} from "solady/utils/Initializable.sol";
import {UUPSUpgradeable} from "solady/utils/UUPSUpgradeable.sol";

/// @title SchemaRegistry
/// @notice The global schema registry.
contract SchemaRegistry is ISchemaRegistry, Withdrawable, Initializable, UUPSUpgradeable {
    error AlreadyExists();

    // The global mapping between schema records and their IDs.
    mapping(bytes32 uid => SchemaRecord schemaRecord) private _registry;

    // TODO: How to register custom types?
    // New custom mapping?

    /// @notice The version of the schema registry.
    string public constant VERSION = "2025-01-06";

    // =============================================================
    //                    CONSTRUCTOR / INITIALIZATION
    // =============================================================

    constructor() {
        _disableInitializers();
    }

    /// @inheritdoc ISchemaRegistry
    function initialize(address initialOwner_) external override initializer {
        _initializeOwner(initialOwner_);
    }

    /// @inheritdoc ISchemaRegistry
    function register(string calldata schema, ISchemaResolver resolver, bool revocable)
        external
        override
        returns (bytes32)
    {
        SchemaRecord memory schemaRecord =
            SchemaRecord({uid: EMPTY_UID, schema: schema, resolver: resolver, revocable: revocable});

        bytes32 uid = _getUID(schemaRecord);
        if (_registry[uid].uid != EMPTY_UID) {
            revert AlreadyExists();
        }

        schemaRecord.uid = uid;
        _registry[uid] = schemaRecord;

        emit Registered(uid, msg.sender, schemaRecord);

        return uid;
    }

    /// @inheritdoc ISchemaRegistry
    function getSchema(bytes32 uid) external view override returns (SchemaRecord memory) {
        return _registry[uid];
    }

    /// @dev Calculates a UID for a given schema.
    /// @param schemaRecord The input schema.
    /// @return schemaUID.
    function _getUID(SchemaRecord memory schemaRecord) private pure returns (bytes32) {
        return keccak256(abi.encodePacked(schemaRecord.schema, schemaRecord.resolver, schemaRecord.revocable));
    }

    // =============================================================
    //                          UUPS
    // =============================================================

    // solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}