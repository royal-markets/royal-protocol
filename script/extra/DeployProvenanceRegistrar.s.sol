// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";

import {ProvenanceToken} from "../../src/extra/ProvenanceToken.sol";
import {ProvenanceRegistrar} from "../../src/extra/ProvenanceRegistrar.sol";

import {LibClone} from "solady/utils/LibClone.sol";
import {LibString} from "solady/utils/LibString.sol";

import {RegistrarRoles} from "../../src/extra/utils/RegistrarRoles.sol";

// NOTE: Must be called by the OWNER address
contract DeployProvenanceRegistrar is Script, RegistrarRoles {
    // Update these as needed:
    // =============================================================
    //                          INPUTS
    // =============================================================

    // NOTE: Fill in the address of the OWNER.
    address public constant OWNER = address(0);

    // NOTE: Fill in the RoyalProtocol information:
    string constant USERNAME = "";
    address constant RECOVERY = address(0);

    // NOTE: NFT attributes for the ProvenanceToken
    string constant NAME = "";
    string constant SYMBOL = "";
    string constant METADATA_URL_BASE = "";
    string constant CONTRACT_URI = "";

    // NOTE: (Optional): Fill in this address, which is the address that will be able to call `recover` on the RecoveryProxy.
    address admin = address(0);

    // NOTE: (Optional): This is the address that will be able to call `registerClaim` on the ProvenanceRegistrar.
    address registerCaller = address(0);

    // NOTE: (Optional): Fill in a secondary wallet/address that can sign ERC1271 signatures for this contract.
    address signer = address(0);

    // =============================================================
    //                          SCRIPT
    // =============================================================

    function run() external {
        if (msg.sender != OWNER) {
            console.log("Must run as OWNER");
            return;
        }

        if (LibString.eq(USERNAME, "")) {
            console.log("Must set USERNAME");
            return;
        }

        if (RECOVERY == address(0)) {
            console.log("Should set RECOVERY");
            return;
        }

        RoleData[] memory roles = new RoleData[](0);
        if (admin != address(0)) {
            roles = new RoleData[](1);
            roles[0] = RoleData({holder: admin, roles: ADMIN});
        }

        if (registerCaller != address(0)) {
            uint256 currentLength = roles.length;
            roles = new RoleData[](currentLength + 1);
            roles[currentLength] = RoleData({holder: registerCaller, roles: REGISTER_CALLER});
        }

        vm.startBroadcast();

        // Deploy ProvenanceToken
        ProvenanceToken provenanceToken =
            new ProvenanceToken(OWNER, NAME, SYMBOL, METADATA_URL_BASE, CONTRACT_URI, roles);
        console.log("ProvenanceToken address: %s", address(provenanceToken));

        // Deploy ProvenanceRegistrar implementation
        address prImplementation = address(new ProvenanceRegistrar());
        console.log("PR Implementation address: %s", prImplementation);

        // Deploy Proxy for ProvenanceRegistrar
        ProvenanceRegistrar provenanceRegistrar =
            ProvenanceRegistrar(payable(LibClone.deployERC1967(address(prImplementation))));
        console.log("ProvenanceRegistrar (proxy) address: %s", address(provenanceRegistrar));

        // Initialize ProvenanceRegistrar
        provenanceRegistrar.initialize(USERNAME, RECOVERY, OWNER, address(provenanceToken), roles);

        // Set up roles that weren't included in the roles[] array.
        provenanceToken.addAirdropper(address(provenanceRegistrar));
        if (signer != address(0)) {
            provenanceRegistrar.setSigner(signer);
        }

        vm.stopBroadcast();
    }
}
