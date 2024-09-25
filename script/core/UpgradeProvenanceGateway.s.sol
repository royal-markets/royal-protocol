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

    address ID_GATEWAY = 0x000000456Bb9Fd42ADd75F4b5c2247f47D45a0A2;

    // =============================================================
    //                          SCRIPT
    // =============================================================

    function run() external {
        vm.startBroadcast();

        // Deploy new implementation
        address newImplementation = address(new ProvenanceGateway());
        console.log("New ProvenanceGateway implementation address: %s", newImplementation);

        // Upgrade the proxy
        UUPSUpgradeable proxy = UUPSUpgradeable(ID_GATEWAY);
        proxy.upgradeToAndCall(address(newImplementation), new bytes(0));

        vm.stopBroadcast();
    }
}
