// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";

import {IdRegistry} from "../../src/core/IdRegistry.sol";
import {ProvenanceRegistry} from "../../src/core/ProvenanceRegistry.sol";
import {ProvenanceGateway} from "../../src/core/ProvenanceGateway.sol";

contract DeployProvenanceSystem is Script {
    // =============================================================
    //                          INPUTS
    // =============================================================

    // NOTE: Get initcode hashes from CalculateSalts script, and then salts from maldon (or create2crunch/cast).
    bytes32 provenanceRegistrySalt = 0x00000000000000000000000000000000000000006294e7302ec4000020d23464;
    bytes32 provenanceGatewaySalt = 0x00000000000000000000000000000000000000007cecb2788cc4000014f0b433;

    address public constant OWNER = 0x62Bd6bD77403268E387a8c7e09aF5D3127186be8;

    IdRegistry public constant ID_REGISTRY = IdRegistry(0x00000000F74144b0dF049137A0F9416a920F2514);

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
        ProvenanceRegistry provenanceRegistry = new ProvenanceRegistry{salt: provenanceRegistrySalt}(OWNER);
        console.log("ProvenanceRegistry address: %s", address(provenanceRegistry));

        ProvenanceGateway provenanceGateway =
            new ProvenanceGateway{salt: provenanceGatewaySalt}(provenanceRegistry, ID_REGISTRY, OWNER);
        console.log("ProvenanceGateway address: %s", address(provenanceGateway));

        // Set the ProvenanceGateway on the ProvenanceRegistry
        provenanceRegistry.setProvenanceGateway(address(provenanceGateway));

        vm.stopBroadcast();
    }
}
