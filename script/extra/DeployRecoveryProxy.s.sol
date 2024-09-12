// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";
import {RecoveryProxy} from "../../src/extra/RecoveryProxy.sol";
import {LibClone} from "solady/utils/LibClone.sol";

contract DeployRecoveryProxy is Script {
    // Update these as needed:
    // =============================================================
    //                          INPUTS
    // =============================================================

    // NOTE: Fill in the address of the OWNER.
    address public constant OWNER = address(0);

    // NOTE: Fill in the address of the IdRegistry.
    address public constant ID_GATEWAY = 0x000000aA0d40b46F0A78d145c321a9DcfD154Ba7;

    // NOTE: (Optional): Fill in this address, which is the address that will be able to call `recover` on the RecoveryProxy.
    address public constant RECOVER_CALLER = address(0);

    // =============================================================
    //                          SCRIPT
    // =============================================================

    function run() external {
        if (msg.sender != OWNER) {
            console.log("Must run as OWNER");
            return;
        }

        if (ID_GATEWAY == address(0)) {
            console.log("ID_GATEWAY must be set");
            return;
        }

        vm.startBroadcast();

        // Deploy implementation
        RecoveryProxy rpImplementation = new RecoveryProxy();
        console.log("RecoveryProxy implementation address: %s", address(rpImplementation));

        // Deploy and initialize proxy
        RecoveryProxy proxy = RecoveryProxy(LibClone.deployERC1967(address(rpImplementation)));
        proxy.initialize(ID_GATEWAY, OWNER);
        console.log("RecoveryProxy (proxy) address: %s", address(proxy));

        // Optionally add a nonOwner address that can call the recover function
        if (RECOVER_CALLER != address(0)) {
            proxy.addRecoverCaller(RECOVER_CALLER);
        }

        vm.stopBroadcast();
    }
}
