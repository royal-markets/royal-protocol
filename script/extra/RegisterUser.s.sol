// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";

import {IdGateway} from "../../src/core/IdGateway.sol";

// NOTE: Needs to be called by the RoyalProtocol owner address.
contract RegisterUser is Script {
    // =============================================================
    //                          INPUTS
    // =============================================================

    address ID_GATEWAY = 0x000000aA0d40b46F0A78d145c321a9DcfD154Ba7;

    // protocol
    // royalprotocol
    // royal_protocol
    // provenance

    string USERNAME = "provenance";

    // NOTE: Fill in the address of the default recovery address for the Royal team.
    address BASE_MAINNET_ROYAL_RECOVERY = 0x06428ebF3D4A6322611792BDf674EE2600e37E29;
    address BASE_SEPOLIA_ROYAL_RECOVERY = 0x1fC0226cEb49B5777a1847d2A0e6d361C336A437;

    // =============================================================
    //                          SCRIPT
    // =============================================================

    function run() external {
        address recovery = BASE_MAINNET_ROYAL_RECOVERY;
        if (block.chainid == 84532) {
            recovery = BASE_SEPOLIA_ROYAL_RECOVERY;
        }

        console.log("Registering user %s with recovery %s", USERNAME, recovery);

        IdGateway idGateway = IdGateway(ID_GATEWAY);

        vm.startBroadcast();
        uint256 protocolAccountId = idGateway.register(USERNAME, recovery);
        vm.stopBroadcast();

        console.log("Registered user %s with protocol account ID %d", USERNAME, protocolAccountId);
        console.log("and custody address %s", msg.sender);
    }
}
