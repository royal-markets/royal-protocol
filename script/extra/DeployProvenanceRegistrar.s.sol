// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";

import {ProvenanceToken} from "../../src/extra/ProvenanceToken.sol";
import {ProvenanceRegistrar} from "../../src/extra/ProvenanceRegistrar.sol";

import {LibClone} from "solady/utils/LibClone.sol";
import {LibString} from "solady/utils/LibString.sol";

// NOTE: Must be called by the OWNER address
contract DeployProvenanceRegistrar is Script {
    // Update these as needed:
    // =============================================================
    //                          INPUTS
    // =============================================================

    // NOTE: Fill in the address of the OWNER.
    address public constant OWNER = address(0);

    // NOTE: NFT attributes for the ProvenanceToken
    string constant NAME = "";
    string constant SYMBOL = "";
    string constant METADATA_URL_BASE = "";
    string constant CONTRACT_URI = "";

    // NOTE: Double-check these addresses are up-to-date
    address constant ID_REGISTRY = 0x0000009ca17b183710537F72A8A7b079cdC8Abe2;
    address constant PROVENANCE_GATEWAY = 0x000000080Bb4A34deB4FEa6479F7904CCaB93378;

    // NOTE: (Optional): This is the address that will be able to call `registerClaim` on the ProvenanceRegistrar.
    address registerCaller = address(0);

    // NOTE: (Optional): Fill in this address, which is the address that will be able to call `recover` on the RecoveryProxy.
    address admin = address(0);

    // =============================================================
    //                          SCRIPT
    // =============================================================

    function run() external {
        if (msg.sender != OWNER) {
            console.log("Must run as OWNER");
            return;
        }

        vm.startBroadcast();

        // Deploy ProvenanceToken
        ProvenanceToken provenanceToken = new ProvenanceToken(OWNER, NAME, SYMBOL, METADATA_URL_BASE, CONTRACT_URI);
        console.log("ProvenanceToken address: %s", address(provenanceToken));

        // Deploy ProvenanceRegistrar implementation
        address prImplementation = address(new ProvenanceRegistrar());
        console.log("PR Implementation address: %s", prImplementation);

        // Deploy Proxy for ProvenanceRegistrar
        ProvenanceRegistrar provenanceRegistrar =
            ProvenanceRegistrar(payable(LibClone.deployERC1967(address(prImplementation))));
        console.log("ProvenanceRegistrar (proxy) address: %s", address(provenanceRegistrar));

        // Initialize ProvenanceRegistrar
        provenanceRegistrar.initialize(OWNER, address(provenanceToken), ID_REGISTRY, PROVENANCE_GATEWAY);

        // Set up roles on contracts
        provenanceToken.addAirdropper(address(provenanceRegistrar));

        if (registerCaller != address(0)) {
            provenanceRegistrar.addRegisterCaller(registerCaller);
        }

        if (admin != address(0)) {
            provenanceRegistrar.addAdmin(admin);
            provenanceToken.addAdmin(admin);
        }

        vm.stopBroadcast();
    }
}
