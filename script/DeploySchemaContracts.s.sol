// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";

import {SchemaRegistry} from "../src/SchemaRegistry.sol";
import {AttestationRegistry} from "../src/AttestationRegistry.sol";

import {FieldDefinition, FieldType, ISchemaResolver} from "../src/interfaces/ISchemaRegistry.sol";
import {AttestationRequest, AttestationRequestData} from "../src/interfaces/IAttestationRegistry.sol";
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
    bytes32 schemaRegistrySalt = bytes32(uint256(1));
    bytes32 attestationRegistrySalt = bytes32(uint256(1));

    bytes32 schemaRegistryProxySalt = bytes32(uint256(1));
    bytes32 attestationRegistryProxySalt = bytes32(uint256(1));

    // NOTE: Double-check addresses?
    address public constant ID_REGISTRY_ADDR = 0x0000002c243D1231dEfA58915324630AB5dBd4f4;

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
        schemaRegistry.initialize(OWNER, ID_REGISTRY_ADDR);
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
            fieldName: "name",
            fieldType: FieldType.STRING,
            isArray: false,
            allowedSchemaIds: new bytes32[](0),
            enumValues: new string[](0)
        });

        // Register Schema#1 - Name
        vm.startBroadcast();
        bytes32 nameSchemaUID = schemaRegistry.register(fields, ISchemaResolver(address(0)), true, false);
        vm.stopBroadcast();

        // Register Schema#2 - Description
        fields[1].fieldName = "description";
        vm.startBroadcast();
        bytes32 descriptionSchemaUID = schemaRegistry.register(fields, ISchemaResolver(address(0)), true, false);
        vm.stopBroadcast();

        // Deploy AttestationRegistry
        vm.startBroadcast();
        address attestationRegistryImplementation = address(new AttestationRegistry{salt: attestationRegistrySalt}());
        AttestationRegistry attestationRegistry = AttestationRegistry(
            LibClone.deployDeterministicERC1967(attestationRegistryImplementation, attestationRegistryProxySalt)
        );
        attestationRegistry.initialize(OWNER, address(schemaRegistry), ID_REGISTRY_ADDR);
        console.log("AttestationRegistry address: %s", address(attestationRegistry));
        vm.stopBroadcast();

        // Setup Attestations for Name/Description for Schema#1 and Schema#2
        AttestationRequest memory nameNameAttestationRequest = AttestationRequest({
            schema: nameSchemaUID,
            data: AttestationRequestData({
                expirationTime: 0,
                revocable: false,
                data: abi.encode(nameSchemaUID, "Schema Name"),
                value: 0
            })
        });

        AttestationRequest memory descriptionNameAttestationRequest = AttestationRequest({
            schema: nameSchemaUID,
            data: AttestationRequestData({
                expirationTime: 0,
                revocable: false,
                data: abi.encode(descriptionSchemaUID, "Schema Description"),
                value: 0
            })
        });

        AttestationRequest memory nameDescriptionAttestationRequest = AttestationRequest({
            schema: descriptionSchemaUID,
            data: AttestationRequestData({
                expirationTime: 0,
                revocable: false,
                data: abi.encode(nameSchemaUID, "A descriptive name of the schema."),
                value: 0
            })
        });

        AttestationRequest memory descriptionDescriptionAttestationRequest = AttestationRequest({
            schema: descriptionSchemaUID,
            data: AttestationRequestData({
                expirationTime: 0,
                revocable: false,
                data: abi.encode(descriptionSchemaUID, "A descriptive description of the schema."),
                value: 0
            })
        });

        // Attest to the names/descriptions of the canonical "Schema Name" and "Schema Description"
        IIdRegistry idRegistry = IIdRegistry(ID_REGISTRY_ADDR);
        uint256 accountId = idRegistry.idOf(OWNER);

        vm.startBroadcast();
        attestationRegistry.attest(accountId, nameNameAttestationRequest);
        attestationRegistry.attest(accountId, descriptionNameAttestationRequest);
        attestationRegistry.attest(accountId, nameDescriptionAttestationRequest);
        attestationRegistry.attest(accountId, descriptionDescriptionAttestationRequest);
        vm.stopBroadcast();
    }
}
