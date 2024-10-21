// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";

import {ProvenanceRegistry} from "../../src/core/ProvenanceRegistry.sol";
import {ProvenanceGateway} from "../../src/core/ProvenanceGateway.sol";

import {LibClone} from "solady/utils/LibClone.sol";
import {UUPSUpgradeable} from "solady/utils/UUPSUpgradeable.sol";

// NOTE: Needs to be called by the RoyalProtocol owner address.
contract UpgradeProvenanceRegistry is Script {
    // =============================================================
    //                          INPUTS
    // =============================================================

    address public constant PROVENANCE_REGISTRY_ADDR = 0x0000009F840EeF8A92E533468A0Ef45a1987Da66;
    address public constant PROVENANCE_GATEWAY_ADDR = 0x000000456Bb9Fd42ADd75F4b5c2247f47D45a0A2;

    // NOTE: Fill this out to deploy an implementation address with leading 0s.
    bytes32 provenanceRegistrySalt = 0x4a99d5dd2cde4fca053af014b37ac864584c03edd64e38fde5cc6306953dcfbf;
    bytes32 provenanceGatewaySalt = 0xbd3bd2122b48ac665243d241d910dccde5f35cfbd57566ec4d920452718366c4;

    // =============================================================
    //                          SCRIPT
    // =============================================================

    function run() external {
        vm.startBroadcast();

        // Deploy new implementation
        address newProvenanceRegistry = address(new ProvenanceRegistry{salt: provenanceRegistrySalt}());
        console.log("New ProvenanceRegistry implementation address: %s", newProvenanceRegistry);
        UUPSUpgradeable proxy = UUPSUpgradeable(PROVENANCE_REGISTRY_ADDR);
        proxy.upgradeToAndCall(address(newProvenanceRegistry), new bytes(0));

        address newProvenanceGateway = address(new ProvenanceGateway{salt: provenanceGatewaySalt}());
        console.log("New ProvenanceGateway implementation address: %s", newProvenanceGateway);
        proxy = UUPSUpgradeable(PROVENANCE_GATEWAY_ADDR);
        proxy.upgradeToAndCall(address(newProvenanceGateway), new bytes(0));

        vm.stopBroadcast();
    }
}
