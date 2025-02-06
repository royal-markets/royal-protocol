// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";

import {SchemaRegistry} from "../src/SchemaRegistry.sol";
import {RecordRegistry} from "../src/RecordRegistry.sol";

import {FieldDefinition, FieldType, ISchemaResolver} from "../src/interfaces/ISchemaRegistry.sol";
import {RecordRequest, RecordRequestData} from "../src/interfaces/IRecordRegistry.sol";
import {IIdRegistry} from "../src/interfaces/IIdRegistry.sol";

import {LibClone} from "solady/utils/LibClone.sol";

/**
 * NOTE: This script won't work unless you go back in Git history to get the contract code at time of initial deploy.
 *
 * If this ends up being an annoying problem - right solve is probably to use CREATE3 moving forward.
 */
contract DeployProtocolContracts is Script {
    // =============================================================
    //                          INPUTS
    // =============================================================

    // NOTE: Get initcode hashes from CalculateSalts script, and then salts from maldon (or create2crunch/cast).
    bytes32 schemaRegistrySalt = bytes32(uint256(2));
    bytes32 recordRegistrySalt = bytes32(uint256(2));

    bytes32 schemaRegistryProxySalt = bytes32(uint256(2));
    bytes32 recordRegistryProxySalt = bytes32(uint256(2));

    // NOTE: Double-check addresses?
    IIdRegistry public constant ID_REGISTRY = IIdRegistry(0x0000002c243D1231dEfA58915324630AB5dBd4f4);

    address public constant OWNER = 0x62Bd6bD77403268E387a8c7e09aF5D3127186be8;

    // =============================================================
    //                          SCRIPT
    // =============================================================

    function run() external {
        if (msg.sender != OWNER) {
            console.log("Must run as OWNER");
            return;
        }

        // Deploy SchemaRegistry
        vm.startBroadcast();
        address schemaRegistryImplementation = address(new SchemaRegistry{salt: schemaRegistrySalt}());
        SchemaRegistry schemaRegistry =
            SchemaRegistry(LibClone.deployDeterministicERC1967(schemaRegistryImplementation, schemaRegistryProxySalt));
        schemaRegistry.initialize(ID_REGISTRY, OWNER);
        console.log("SchemaRegistry address: %s", address(schemaRegistry));
        vm.stopBroadcast();

        // Register canonical schemas for schema metadata
        FieldDefinition[] memory fields = new FieldDefinition[](2);
        fields[0] = FieldDefinition({
            fieldName: "schemaId",
            fieldType: FieldType.SCHEMA_ID,
            isArray: false,
            allowedSchemaIds: new bytes32[](0),
            enumValues: new string[](0)
        });

        fields[1] = FieldDefinition({
            fieldName: "description",
            fieldType: FieldType.STRING,
            isArray: false,
            allowedSchemaIds: new bytes32[](0),
            enumValues: new string[](0)
        });

        // Register Schema#1 - Description
        vm.startBroadcast();
        bytes32 descriptionSchemaUID = schemaRegistry.register({
            name: "Schema Description",
            fields: fields,
            revocable: false,
            updatable: true,
            resolver: ISchemaResolver(address(0)),
            salt: bytes32(0)
        });
        vm.stopBroadcast();

        // Deploy RecordRegistry
        vm.startBroadcast();
        address recordRegistryImplementation = address(new RecordRegistry{salt: recordRegistrySalt}());
        RecordRegistry recordRegistry =
            RecordRegistry(LibClone.deployDeterministicERC1967(recordRegistryImplementation, recordRegistryProxySalt));
        recordRegistry.initialize(schemaRegistry, ID_REGISTRY, OWNER);
        console.log("RecordRegistry address: %s", address(recordRegistry));
        vm.stopBroadcast();

        // Setup Record for a Description for Schema#1
        RecordRequest memory descriptionDescriptionRecordRequest = RecordRequest({
            schema: descriptionSchemaUID,
            data: RecordRequestData({
                revocable: false,
                updatable: true,
                data: abi.encode(descriptionSchemaUID, "A descriptive description of the schema."),
                salt: bytes32(0),
                value: 0
            })
        });

        // Attest to the description of the canonical "Schema Description"
        uint256 accountId = ID_REGISTRY.idOf(OWNER);

        vm.startBroadcast();
        recordRegistry.register(accountId, descriptionDescriptionRecordRequest);
        vm.stopBroadcast();
    }
}
