// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";

import {SchemaRegistry} from "../src/SchemaRegistry.sol";
import {AttestationRegistry} from "../src/AttestationRegistry.sol";

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
    bytes32 schemaRegistrySalt = bytes32(0);
    bytes32 attestationRegistrySalt = bytes32(0);

    bytes32 schemaRegistryProxySalt = bytes32(0);
    bytes32 attestationRegistryProxySalt = bytes32(0);

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

        vm.startBroadcast();

        // Deploy Schema contracts
        address schemaRegistryImplementation = address(new SchemaRegistry{salt: schemaRegistrySalt}());
        SchemaRegistry schemaRegistry =
            SchemaRegistry(LibClone.deployDeterministicERC1967(schemaRegistryImplementation, schemaRegistryProxySalt));
        schemaRegistry.initialize(OWNER);
        console.log("SchemaRegistry address: %s", address(schemaRegistry));

        address attestationRegistryImplementation = address(new AttestationRegistry{salt: attestationRegistrySalt}());
        AttestationRegistry attestationRegistry = AttestationRegistry(
            LibClone.deployDeterministicERC1967(attestationRegistryImplementation, attestationRegistryProxySalt)
        );
        attestationRegistry.initialize(OWNER, address(schemaRegistry), ID_REGISTRY_ADDR);
        console.log("AttestationRegistry address: %s", address(attestationRegistry));

        vm.stopBroadcast();
    }
}
