// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";

import {RegistrarFactory} from "../../src/extra/RegistrarFactory.sol";

import {LibClone} from "solady/utils/LibClone.sol";
import {LibString} from "solady/utils/LibString.sol";

import {RegistrarRoles} from "../../src/extra/utils/RegistrarRoles.sol";

// NOTE: Must be called by the OWNER address
contract DeployProvenanceRegistrarViaFactory is Script, RegistrarRoles {
    // Update these as needed:
    // =============================================================
    //                          INPUTS
    // =============================================================

    // NOTE: Fill in the address of the REGISTRAR_FACTORY.
    RegistrarFactory public constant REGISTRAR_FACTORY = RegistrarFactory(0x0000009925081F2732a654eF4259171452d24F76);

    // NOTE: Fill in the address of the OWNER.
    address public constant OWNER = address(0x1978124A2a81095ab5363Cfed3Fa9eC1600bb37f);

    // NOTE: Fill in the RoyalProtocol information:
    string constant USERNAME = "HAL9000";
    address constant RECOVERY = address(0x1fC0226cEb49B5777a1847d2A0e6d361C336A437);

    // NOTE: NFT attributes for the ProvenanceToken
    string constant NAME = "HAL 9000";
    string constant SYMBOL = "HAL";
    string constant METADATA_URL_BASE = "";
    string constant CONTRACT_URI = "";

    // NOTE: (Optional): This is the address that will be able to call `registerClaim` on the ProvenanceRegistrar.
    address registerCaller = address(0x3dEC8eCD4Aae74e6775d1e9725e3C1B79f1b6845);

    // =============================================================
    //                          SCRIPT
    // =============================================================

    function run() external {
        if (OWNER == address(0)) {
            console.log("Must include an OWNER");
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
        if (registerCaller != address(0)) {
            uint256 currentLength = roles.length;
            roles = new RoleData[](currentLength + 1);
            roles[currentLength] = RoleData({holder: registerCaller, roles: REGISTER_CALLER});
        }

        vm.startBroadcast();

        (uint256 protocolId, address payable provenanceRegistrar, address provenanceToken) = REGISTRAR_FACTORY
            .deployRegistrarAndTokenContracts(
            OWNER, USERNAME, RECOVERY, NAME, SYMBOL, METADATA_URL_BASE, CONTRACT_URI, roles
        );

        vm.stopBroadcast();

        console.log("Protocol ID: %d", protocolId);
        console.log("ProvenanceRegistrar address: %s", provenanceRegistrar);
        console.log("ProvenanceToken address: %s", provenanceToken);
    }
}
