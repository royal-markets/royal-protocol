// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";
import {ProvenanceGateway} from "../../src/core/ProvenanceGateway.sol";
import {LibClone} from "solady/utils/LibClone.sol";
import {UUPSUpgradeable} from "solady/utils/UUPSUpgradeable.sol";

// NOTE: Needs to be called by the RoyalProtocol owner address.
contract UpgradeProvenanceGateway is Script {
    // =============================================================
    //                          INPUTS
    // =============================================================

    address PROVENANCE_GATEWAY = 0x000000456Bb9Fd42ADd75F4b5c2247f47D45a0A2;

    // NOTE: Fill this out to deploy an implementation address with leading 0s.
    bytes32 provenanceGatewaySalt = 0xf0831a0056424dedfc91ad623849217e0e30e3059ae83b0db33323774f6820a6;

    // =============================================================
    //                          SCRIPT
    // =============================================================

    function run() external {
        vm.startBroadcast();

        // Deploy new implementation
        address newImplementation = address(new ProvenanceGateway{salt: provenanceGatewaySalt}());
        console.log("New ProvenanceGateway implementation address: %s", newImplementation);

        // Upgrade the proxy
        UUPSUpgradeable proxy = UUPSUpgradeable(PROVENANCE_GATEWAY);
        proxy.upgradeToAndCall(address(newImplementation), new bytes(0));

        vm.stopBroadcast();
    }
}
