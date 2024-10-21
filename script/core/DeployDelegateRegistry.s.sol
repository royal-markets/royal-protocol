// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";
import {DelegateRegistry} from "../../src/core/delegation/DelegateRegistry.sol";
import {IdRegistry} from "../../src/core/IdRegistry.sol";
import {IdGateway} from "../../src/core/IdGateway.sol";
import {ProvenanceRegistry} from "../../src/core/ProvenanceRegistry.sol";
import {ProvenanceGateway} from "../../src/core/ProvenanceGateway.sol";

import {LibClone} from "solady/utils/LibClone.sol";
import {UUPSUpgradeable} from "solady/utils/UUPSUpgradeable.sol";

// NOTE: Needs to be called by the RoyalProtocol owner address.
contract DeployDelegateRegistry is Script {
    // =============================================================
    //                          INPUTS
    // =============================================================

    // NOTE: Fill this out to deploy an implementation address with leading 0s.
    bytes32 idRegistrySalt = 0xb1c1eda1c181d0072138465ca4129c055c07b14af6c4756b084056bbc646aaf2;
    bytes32 idGatewaySalt = 0xceec5a3df7ba142b1c05d69412670499d652b4d07075a79c85ca4e30601d0fc7;
    bytes32 provenanceRegistrySalt = 0x4a99d5dd2cde4fca053af014b37ac864584c03edd64e38fde5cc6306953dcfbf;
    bytes32 provenanceGatewaySalt = 0xbd3bd2122b48ac665243d241d910dccde5f35cfbd57566ec4d920452718366c4;

    bytes32 delegateRegistrySalt = 0xf5bf81b6deba33121dd051d98eff71f399925dba9d5010a496ebb30ca1531567;
    bytes32 delegateRegistryProxySalt = 0x1156cd4e919ca25dd1aafd4328e68eaf4bd98e0ab0a7e0be373758e5933015a4;

    address public constant OWNER = 0x62Bd6bD77403268E387a8c7e09aF5D3127186be8;

    address public constant ID_REGISTRY_ADDR = 0x0000002c243D1231dEfA58915324630AB5dBd4f4;
    address public constant ID_GATEWAY_ADDR = 0x000000aA0d40b46F0A78d145c321a9DcfD154Ba7;
    address public constant PROVENANCE_REGISTRY_ADDR = 0x0000009F840EeF8A92E533468A0Ef45a1987Da66;
    address public constant PROVENANCE_GATEWAY_ADDR = 0x000000456Bb9Fd42ADd75F4b5c2247f47D45a0A2;
    address public constant DELEGATE_REGISTRY_ADDR = 0x000000f1CABe81De9e020C9fac95318b14B80F14;

    // =============================================================
    //                          SCRIPT
    // =============================================================

    function run() external {
        if (msg.sender != OWNER) {
            console.log("Must run as OWNER");
            return;
        }

        vm.startBroadcast();

        // Deploy protocol's DelegateRegistry
        address delegateRegistryImplementation = address(new DelegateRegistry{salt: delegateRegistrySalt}());
        DelegateRegistry delegateRegistry = DelegateRegistry(
            LibClone.deployDeterministicERC1967(delegateRegistryImplementation, delegateRegistryProxySalt)
        );
        delegateRegistry.initialize(ID_REGISTRY_ADDR, OWNER);
        console.log("DelegateRegistry address: %s", address(delegateRegistry));

        // Deploy new IdRegistry implementation
        address newIdRegistry = address(new IdRegistry{salt: idRegistrySalt}());
        console.log("New IdRegistry implementation address: %s", newIdRegistry);
        UUPSUpgradeable proxy = UUPSUpgradeable(ID_REGISTRY_ADDR);
        proxy.upgradeToAndCall(newIdRegistry, new bytes(0));
        // Set the new RoyalProtocol DelegateRegistry on the IdRegistry
        IdRegistry(ID_REGISTRY_ADDR).setDelegateRegistry(address(delegateRegistry));

        // Deploy new IdGateway implementation
        address newIdGateway = address(new IdGateway{salt: idGatewaySalt}());
        console.log("New IdGateway implementation address: %s", newIdGateway);
        proxy = UUPSUpgradeable(ID_GATEWAY_ADDR);
        proxy.upgradeToAndCall(newIdGateway, new bytes(0));

        // Deploy new ProvenanceRegistry implementation
        address newProvenanceRegistry = address(new ProvenanceRegistry{salt: provenanceRegistrySalt}());
        console.log("New ProvenanceRegistry implementation address: %s", newProvenanceRegistry);
        proxy = UUPSUpgradeable(PROVENANCE_REGISTRY_ADDR);
        proxy.upgradeToAndCall(newProvenanceRegistry, new bytes(0));

        // Deploy new ProvenanceGateway implementation
        address newProvenanceGateway = address(new ProvenanceGateway{salt: provenanceGatewaySalt}());
        console.log("New ProvenanceGateway implementation address: %s", newProvenanceGateway);
        proxy = UUPSUpgradeable(PROVENANCE_GATEWAY_ADDR);
        proxy.upgradeToAndCall(newProvenanceGateway, new bytes(0));

        vm.stopBroadcast();
    }
}
