// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";

import {IdRegistry} from "../../src/core/IdRegistry.sol";
import {ProvenanceRegistry} from "../../src/core/ProvenanceRegistry.sol";
import {ProvenanceGateway} from "../../src/core/ProvenanceGateway.sol";

import {LibClone} from "solady/utils/LibClone.sol";

contract DeployProvenanceSystem is Script {
    // =============================================================
    //                          INPUTS
    // =============================================================

    // NOTE: Get initcode hashes from CalculateSalts script, and then salts from maldon (or create2crunch/cast).
    bytes32 provenanceRegistrySalt = 0xae6820d88773a3aab8aa8896480ed88ac1b174d01f3955a1ad161e335ef42411;
    bytes32 provenanceGatewaySalt = 0xa041d7c995b5cf119ca344195e34cee5d16f5da9e5850b68eb9f1c8149449576;

    bytes32 provenanceRegistryProxySalt = 0xa443b9112e21b5e3f715b035d541a7b0140aa043fe6be10b908435849fc21f18;
    bytes32 provenanceGatewayProxySalt = 0xb96f58746c0581b1ac7c78c157ded10a92623443db30ff304a810addfc74bc56;

    address public constant OWNER = 0x62Bd6bD77403268E387a8c7e09aF5D3127186be8;
    address public constant MIGRATOR = 0xE5673eD07d596E558D280DACdaE346FAF9c9B1A7;

    IdRegistry public constant ID_REGISTRY = IdRegistry(0x0000009ca17b183710537F72A8A7b079cdC8Abe2);

    // =============================================================
    //                          SCRIPT
    // =============================================================

    function run() external {
        if (msg.sender != OWNER) {
            console.log("Must run as OWNER");
            return;
        }

        vm.startBroadcast();

        // Deploy Provenance contracts
        address provenanceRegistryImplementation = address(new ProvenanceRegistry{salt: provenanceRegistrySalt}());
        ProvenanceRegistry provenanceRegistry = ProvenanceRegistry(
            LibClone.deployDeterministicERC1967(provenanceRegistryImplementation, provenanceRegistryProxySalt)
        );
        provenanceRegistry.initialize(ID_REGISTRY, MIGRATOR, OWNER);
        console.log("ProvenanceRegistry address: %s", address(provenanceRegistry));

        address provenanceGatewayImplementation = address(new ProvenanceGateway{salt: provenanceGatewaySalt}());
        ProvenanceGateway provenanceGateway = ProvenanceGateway(
            LibClone.deployDeterministicERC1967(provenanceGatewayImplementation, provenanceGatewayProxySalt)
        );
        provenanceGateway.initialize(provenanceRegistry, ID_REGISTRY, OWNER);
        console.log("ProvenanceGateway address: %s", address(provenanceGateway));

        // Set the ProvenanceGateway on the ProvenanceRegistry
        provenanceRegistry.setProvenanceGateway(address(provenanceGateway));

        vm.stopBroadcast();
    }
}
