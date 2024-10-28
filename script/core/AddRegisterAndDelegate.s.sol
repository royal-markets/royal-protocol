// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";

import {IdGateway} from "../../src/core/IdGateway.sol";
import {DelegateRegistry} from "../../src/core/delegation/DelegateRegistry.sol";

import {LibClone} from "solady/utils/LibClone.sol";
import {UUPSUpgradeable} from "solady/utils/UUPSUpgradeable.sol";

// NOTE: Needs to be called by the RoyalProtocol owner address.
contract AddRegisterAndDelegate is Script {
    // =============================================================
    //                          INPUTS
    // =============================================================

    address public constant ID_GATEWAY_ADDR = 0x000000aA0d40b46F0A78d145c321a9DcfD154Ba7;
    address public constant DELEGATE_REGISTRY_ADDR = 0x000000f1CABe81De9e020C9fac95318b14B80F14;

    // NOTE: Fill this out to deploy an implementation address with leading 0s.
    bytes32 idGatewaySalt = 0x7e1652bb6a2c7a44763608d0b755f496e8a209774ac6fa4bbe6bd8738ad931b6;
    bytes32 delegateRegistrySalt = 0xf428a3586c821605649232d9cac64cb85d816683667985e7c60bed4ce6507da0;

    // =============================================================
    //                          SCRIPT
    // =============================================================

    function run() external {
        vm.startBroadcast();

        // Deploy new implementation
        address newIdGateway = address(new IdGateway{salt: idGatewaySalt}());
        console.log("New IdGateway implementation address: %s", newIdGateway);
        UUPSUpgradeable proxy = UUPSUpgradeable(ID_GATEWAY_ADDR);
        proxy.upgradeToAndCall(address(newIdGateway), new bytes(0));
        IdGateway(address(proxy)).setDelegateRegistry(DELEGATE_REGISTRY_ADDR);

        // Deploy new DelegateRegistry implementation
        address newDelegateRegistry = address(new DelegateRegistry{salt: delegateRegistrySalt}());
        console.log("New DelegateRegistry implementation address: %s", newDelegateRegistry);
        proxy = UUPSUpgradeable(DELEGATE_REGISTRY_ADDR);
        proxy.upgradeToAndCall(address(newDelegateRegistry), new bytes(0));
        DelegateRegistry(address(proxy)).setIdGateway(ID_GATEWAY_ADDR);

        vm.stopBroadcast();
    }
}
