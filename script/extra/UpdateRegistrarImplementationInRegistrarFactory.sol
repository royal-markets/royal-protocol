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

    bytes32 provenanceRegistrarSalt = bytes32(0xd9e15205d6cfcb423b1b59a9c5e44edd869af5300c94901c61a80e97184aaba3);

    // NOTE: This should be the _proxy_ address of the factory contract.
    RegistrarFactory registrarFactory = RegistrarFactory(0x000000C0E95b5EB71f6DC4f6ce3DC31635F4794b);

    // NOTE: Fill in the address of the OWNER.
    address public constant OWNER = address(0x9E7F2530512D192D706480C439083BbB5F1028A7);

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
