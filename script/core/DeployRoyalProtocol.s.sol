// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";

import {IdRegistry} from "../../src/core/IdRegistry.sol";
import {IdGateway} from "../../src/core/IdGateway.sol";
import {UsernameGateway} from "../../src/core/UsernameGateway.sol";
import {ProvenanceRegistry} from "../../src/core/ProvenanceRegistry.sol";
import {ProvenanceGateway} from "../../src/core/ProvenanceGateway.sol";

contract DeployRoyalProtocol is Script {
    // =============================================================
    //                          INPUTS
    // =============================================================

    // NOTE: Get initcode hashes from CalculateSalts script, and then salts from maldon (or create2crunch/cast).
    bytes32 idRegistrySalt = 0x0000000000000000000000000000000000000000fc16b93e000f0000cacf55a5;
    bytes32 idGatewaySalt = 0x000000000000000000000000000000000000000059224fd23c24440000a0154b;
    bytes32 usernameGatewaySalt = 0x000000000000000000000000000000000000000007fe84df4f04000065c41748;
    bytes32 provenanceRegistrySalt = 0x00000000000000000000000000000000000000006294e7302ec4000020d23464;
    bytes32 provenanceGatewaySalt = 0x00000000000000000000000000000000000000007cecb2788cc4000014f0b433;

    address public constant OWNER = 0x62Bd6bD77403268E387a8c7e09aF5D3127186be8;
    address public constant ID_REGISTRY_MIGRATOR = 0xE5673eD07d596E558D280DACdaE346FAF9c9B1A7;

    // =============================================================
    //                          SCRIPT
    // =============================================================

    function run() external {
        if (msg.sender != OWNER) {
            console.log("Must run as OWNER");
            return;
        }

        vm.startBroadcast();

        // Deploy Account contracts
        IdRegistry idRegistry = new IdRegistry{salt: idRegistrySalt}(ID_REGISTRY_MIGRATOR, OWNER);
        console.log("IdRegistry address: %s", address(idRegistry));

        IdGateway idGateway = new IdGateway{salt: idGatewaySalt}(idRegistry, OWNER);
        console.log("IdGateway address: %s", address(idGateway));

        UsernameGateway usernameGateway = new UsernameGateway{salt: usernameGatewaySalt}(idRegistry, OWNER);
        console.log("UsernameGateway address: %s", address(usernameGateway));

        // Configure gateways on the IdRegistry
        idRegistry.setIdGateway(address(idGateway));
        idRegistry.setUsernameGateway(address(usernameGateway));

        // Deploy Provenance contracts
        ProvenanceRegistry provenanceRegistry =
            new ProvenanceRegistry{salt: provenanceRegistrySalt}(ID_REGISTRY_MIGRATOR, OWNER);
        console.log("ProvenanceRegistry address: %s", address(provenanceRegistry));

        ProvenanceGateway provenanceGateway =
            new ProvenanceGateway{salt: provenanceGatewaySalt}(provenanceRegistry, idRegistry, OWNER);
        console.log("ProvenanceGateway address: %s", address(provenanceGateway));

        // Set the ProvenanceGateway on the ProvenanceRegistry
        provenanceRegistry.setProvenanceGateway(address(provenanceGateway));

        vm.stopBroadcast();
    }
}
