// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";
import {DelegateRegistry} from "../../src/core/delegation/DelegateRegistry.sol";
import {UUPSUpgradeable} from "solady/utils/UUPSUpgradeable.sol";

// NOTE: Needs to be called by the RoyalProtocol owner address.
contract UpgradeDelegateRegistry is Script {
    // =============================================================
    //                          INPUTS
    // =============================================================

    address DELEGATE_REGISTRY = 0x000000f1CABe81De9e020C9fac95318b14B80F14;

    // NOTE: Fill this out to deploy an implementation address with leading 0s.
    bytes32 delegateRegistrySalt = 0xb11c6b5de8270722df5b957b4b46fdd39edbaf2251e6b13225d09ffbdb1b2f7d;

    // =============================================================
    //                          SCRIPT
    // =============================================================

    function run() external {
        vm.startBroadcast();

        // Deploy new implementation
        address newImplementation = address(new DelegateRegistry{salt: delegateRegistrySalt}());
        console.log("New DelegateRegistry implementation address: %s", newImplementation);

        // Upgrade the proxy
        UUPSUpgradeable proxy = UUPSUpgradeable(DELEGATE_REGISTRY);
        proxy.upgradeToAndCall(address(newImplementation), new bytes(0));

        vm.stopBroadcast();
    }
}
