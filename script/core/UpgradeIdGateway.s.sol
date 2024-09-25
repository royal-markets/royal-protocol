// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";
import {IdGateway} from "../../src/core/IdGateway.sol";
import {LibClone} from "solady/utils/LibClone.sol";
import {UUPSUpgradeable} from "solady/utils/UUPSUpgradeable.sol";

// NOTE: Needs to be called by the RoyalProtocol owner address.
contract UpgradeIdGateway is Script {
    // =============================================================
    //                          INPUTS
    // =============================================================

    address ID_GATEWAY = 0x000000aA0d40b46F0A78d145c321a9DcfD154Ba7;

    // TODO: Fill this out to deploy an implementation address with leading 0s.
    bytes32 idGatewaySalt = 0xccb16697c900cc61bec57df9a948a42abf81d068c857ee77bc81ff23c758783f;

    // =============================================================
    //                          SCRIPT
    // =============================================================

    function run() external {
        vm.startBroadcast();

        // Deploy new implementation
        address newImplementation = address(new IdGateway{salt: idGatewaySalt}());
        console.log("New IdGateway implementation address: %s", newImplementation);

        // Upgrade the proxy
        UUPSUpgradeable proxy = UUPSUpgradeable(ID_GATEWAY);
        proxy.upgradeToAndCall(address(newImplementation), new bytes(0));

        vm.stopBroadcast();
    }
}
