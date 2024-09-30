// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";

import {ProvenanceRegistrar} from "../../src/extra/ProvenanceRegistrar.sol";
import {RegistrarFactory} from "../../src/extra/RegistrarFactory.sol";

import {LibClone} from "solady/utils/LibClone.sol";

// NOTE: Must be called by the OWNER address
contract UpdateRegistrarImplementationInRegistrarFactory is Script {
    // =============================================================
    //                          INPUTS
    // =============================================================

    bytes32 provenanceRegistrarSalt = bytes32(0);

    // NOTE: This should be the _proxy_ address of the factory contract.
    RegistrarFactory registrarFactory = RegistrarFactory(address(0));

    // NOTE: Fill in the address of the OWNER.
    address public constant OWNER = address(0);

    // =============================================================
    //                          SCRIPT
    // =============================================================

    function run() external {
        if (msg.sender != OWNER) {
            console.log("Must run as OWNER");
            return;
        }

        vm.startBroadcast();

        // Deploy ProvenanceRegistrar implementation
        address prImplementation = address(new ProvenanceRegistrar{salt: provenanceRegistrarSalt}());
        console.log("PR Implementation address: %s", prImplementation);

        // Update the ProvenanceRegistrar implementation in the RegistrarFactory
        registrarFactory.setProvenanceRegistrarImplementation(prImplementation);

        vm.stopBroadcast();
    }
}
