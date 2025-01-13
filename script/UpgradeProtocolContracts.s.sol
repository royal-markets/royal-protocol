// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";

import {IdRegistry} from "../src/IdRegistry.sol";
import {IdGateway} from "../src/IdGateway.sol";
import {ProvenanceRegistry} from "../src/ProvenanceRegistry.sol";
import {ProvenanceGateway} from "../src/ProvenanceGateway.sol";
import {DelegateRegistry} from "../src/delegation/DelegateRegistry.sol";

import {UUPSUpgradeable} from "solady/utils/UUPSUpgradeable.sol";

// NOTE: Needs to be called by the RoyalProtocol owner address.
contract UpgradeProtocolContracts is Script {
    // =============================================================
    //                          INPUTS
    // =============================================================

    bytes32 internal constant _ERC1967_IMPLEMENTATION_SLOT =
        0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    // Royal Protocol owner address.
    address public constant OWNER = 0x62Bd6bD77403268E387a8c7e09aF5D3127186be8;

    // The proxy addresses that need to be (potentially) be upgraded.
    address public constant ID_REGISTRY_ADDR = 0x0000002c243D1231dEfA58915324630AB5dBd4f4;
    address public constant ID_GATEWAY_ADDR = 0x000000aA0d40b46F0A78d145c321a9DcfD154Ba7;
    address public constant PROVENANCE_REGISTRY_ADDR = 0x0000009F840EeF8A92E533468A0Ef45a1987Da66;
    address public constant PROVENANCE_GATEWAY_ADDR = 0x000000456Bb9Fd42ADd75F4b5c2247f47D45a0A2;
    address public constant DELEGATE_REGISTRY_ADDR = 0x000000f1CABe81De9e020C9fac95318b14B80F14;

    // Current Salts.
    // NOTE: If something doesn't line up, recalculate using the `CalculateUpgradeSalts` script.
    bytes32 idRegistrySalt = 0xb1c1eda1c181d0072138465ca4129c055c07b14af6c4756b084056bbc646aaf2;
    bytes32 idGatewaySalt = 0x7e1652bb6a2c7a44763608d0b755f496e8a209774ac6fa4bbe6bd8738ad931b6;
    bytes32 provenanceRegistrySalt = 0x4a99d5dd2cde4fca053af014b37ac864584c03edd64e38fde5cc6306953dcfbf;
    bytes32 provenanceGatewaySalt = 0xbd3bd2122b48ac665243d241d910dccde5f35cfbd57566ec4d920452718366c4;
    bytes32 delegateRegistrySalt = 0xb11c6b5de8270722df5b957b4b46fdd39edbaf2251e6b13225d09ffbdb1b2f7d;

    // =============================================================
    //                          SCRIPT
    // =============================================================

    function run() external {
        if (msg.sender != OWNER) {
            console.log("ERROR: Must run as OWNER");
            return;
        }

        // Just declare some variables that we'll re-use a bunch.
        address newImplementation;
        address implementation;
        UUPSUpgradeable proxy;

        // Check IdRegistry Implementation
        newImplementation = vm.computeCreate2Address(idRegistrySalt, keccak256(type(IdRegistry).creationCode));
        if (leadingZeroBytesOfAddress(newImplementation) < 3) {
            console.log("ERROR: New IdRegistry implementation address would have less than 3 leading zero bytes");
            return;
        }

        implementation = address(uint160(uint256(vm.load(ID_REGISTRY_ADDR, _ERC1967_IMPLEMENTATION_SLOT))));
        if (implementation != newImplementation) {
            vm.broadcast();
            address newIdRegistry = address(new IdRegistry{salt: idRegistrySalt}());

            console.log("New IdRegistry implementation address: %s", newIdRegistry);
            proxy = UUPSUpgradeable(ID_REGISTRY_ADDR);

            vm.broadcast();
            proxy.upgradeToAndCall(address(newIdRegistry), new bytes(0));
        } else {
            console.log("IdRegistry implementation is already up to date");
        }

        // Check IdGateway Implementation
        newImplementation = vm.computeCreate2Address(idGatewaySalt, keccak256(type(IdGateway).creationCode));
        if (leadingZeroBytesOfAddress(newImplementation) < 3) {
            console.log("ERROR: New IdGateway implementation address would have less than 3 leading zero bytes");
            return;
        }

        implementation = address(uint160(uint256((vm.load(ID_GATEWAY_ADDR, _ERC1967_IMPLEMENTATION_SLOT)))));
        if (implementation != newImplementation) {
            vm.broadcast();
            address newIdGateway = address(new IdGateway{salt: idGatewaySalt}());

            console.log("New IdGateway implementation address: %s", newIdGateway);
            proxy = UUPSUpgradeable(ID_GATEWAY_ADDR);

            vm.broadcast();
            proxy.upgradeToAndCall(address(newIdGateway), new bytes(0));
        } else {
            console.log("IdGateway implementation is already up to date");
        }

        // Check ProvenanceRegistry Implementation
        newImplementation =
            vm.computeCreate2Address(provenanceRegistrySalt, keccak256(type(ProvenanceRegistry).creationCode));
        if (leadingZeroBytesOfAddress(newImplementation) < 3) {
            console.log(
                "ERROR: New ProvenanceRegistry implementation address would have less than 3 leading zero bytes"
            );
            return;
        }

        implementation = address(uint160(uint256(vm.load(PROVENANCE_REGISTRY_ADDR, _ERC1967_IMPLEMENTATION_SLOT))));
        if (implementation != newImplementation) {
            vm.broadcast();
            address newProvenanceRegistry = address(new ProvenanceRegistry{salt: provenanceRegistrySalt}());

            console.log("New ProvenanceRegistry implementation address: %s", newProvenanceRegistry);
            proxy = UUPSUpgradeable(PROVENANCE_REGISTRY_ADDR);

            vm.broadcast();
            proxy.upgradeToAndCall(address(newProvenanceRegistry), new bytes(0));
        } else {
            console.log("ProvenanceRegistry implementation is already up to date");
        }

        // Check ProvenanceGateway Implementation
        newImplementation =
            vm.computeCreate2Address(provenanceGatewaySalt, keccak256(type(ProvenanceGateway).creationCode));
        if (leadingZeroBytesOfAddress(newImplementation) < 3) {
            console.log("ERROR: New ProvenanceGateway implementation address would have less than 3 leading zero bytes");
            return;
        }

        implementation = address(uint160(uint256(vm.load(PROVENANCE_GATEWAY_ADDR, _ERC1967_IMPLEMENTATION_SLOT))));
        if (implementation != newImplementation) {
            vm.broadcast();
            address newProvenanceGateway = address(new ProvenanceGateway{salt: provenanceGatewaySalt}());

            console.log("New ProvenanceGateway implementation address: %s", newProvenanceGateway);
            proxy = UUPSUpgradeable(PROVENANCE_GATEWAY_ADDR);

            vm.broadcast();
            proxy.upgradeToAndCall(address(newProvenanceGateway), new bytes(0));
        } else {
            console.log("ProvenanceGateway implementation is already up to date");
        }

        // Check DelegateRegistry Implementation
        newImplementation =
            vm.computeCreate2Address(delegateRegistrySalt, keccak256(type(DelegateRegistry).creationCode));
        if (leadingZeroBytesOfAddress(newImplementation) < 3) {
            console.log("ERROR: New DelegateRegistry implementation address would have less than 3 leading zero bytes");
            return;
        }

        implementation = address(uint160(uint256(vm.load(DELEGATE_REGISTRY_ADDR, _ERC1967_IMPLEMENTATION_SLOT))));
        if (implementation != newImplementation) {
            vm.broadcast();
            address newDelegateRegistry = address(new DelegateRegistry{salt: delegateRegistrySalt}());

            console.log("New DelegateRegistry implementation address: %s", newDelegateRegistry);
            proxy = UUPSUpgradeable(DELEGATE_REGISTRY_ADDR);

            vm.broadcast();
            proxy.upgradeToAndCall(address(newDelegateRegistry), new bytes(0));
        } else {
            console.log("DelegateRegistry implementation is already up to date");
        }
    }

    function leadingZeroBytesOfAddress(address addr) internal pure returns (uint8 leadingZeroes) {
        // Convert address to uint256 to make bit manipulation easier
        uint256 addressAsInt = uint256(uint160(addr));

        // If the address is zero, return 20 (all bytes are zero)
        if (addressAsInt == 0) return 20;

        // Counter for leading zero bytes
        uint8 zeroCount = 0;

        // Iterate through bytes from most significant to least significant
        for (uint8 i = 0; i < 20; i++) {
            // Extract the current byte
            uint8 currentByte = uint8(addressAsInt >> (8 * (19 - i)) & 0xFF);

            // If byte is zero, increment counter,
            // otherwise stop counting as soon as a non-zero byte is found
            if (currentByte == 0) {
                zeroCount++;
            } else {
                break;
            }
        }

        return zeroCount;
    }
}
