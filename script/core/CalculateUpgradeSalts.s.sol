// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";

import {IdRegistry} from "../../src/core/IdRegistry.sol";
import {IdGateway} from "../../src/core/IdGateway.sol";
import {ProvenanceRegistry} from "../../src/core/ProvenanceRegistry.sol";
import {ProvenanceGateway} from "../../src/core/ProvenanceGateway.sol";

import {LibClone} from "solady/utils/LibClone.sol";

// These initCode hashes can be used to calculate more gas-efficient CREATE2 addresses.
//
// Example: Find addresses with 3 bytes of leading zeros (fairly quick).
// cast create2 --starts-with 0x000000 --init-code-hash ${initCodeHash}

contract CalculateUpgradeSalts is Script {
    // Salts for sanity checking CREATE2 addresses.
    bytes32 idRegistrySalt = 0xb1c1eda1c181d0072138465ca4129c055c07b14af6c4756b084056bbc646aaf2;
    bytes32 idGatewaySalt = 0xceec5a3df7ba142b1c05d69412670499d652b4d07075a79c85ca4e30601d0fc7;
    bytes32 provenanceRegistrySalt = 0x4a99d5dd2cde4fca053af014b37ac864584c03edd64e38fde5cc6306953dcfbf;
    bytes32 provenanceGatewaySalt = 0xbd3bd2122b48ac665243d241d910dccde5f35cfbd57566ec4d920452718366c4;

    // Sanity check the calculated addresses.
    address idRegistry = address(0x00000083D46c4449a0f599eD2982EC8FfaA5D88F);
    address idGateway = address(0x000000d2DB54c3d878E98F03F4a1e5b4BD2c0020);
    address provenanceRegistry = address(0x000000edD8565fDe8Bb8c91B74d13128eBDCDD2C);
    address provenanceGateway = address(0x0000001A503698b40571AfAbaD131D7e6C2442f9);

    // Calculate initCode hashes.
    function run() external view {
        // Calculate IdRegistry initCodeHash.
        bytes32 idRegistryInitCodeHash = keccak256(type(IdRegistry).creationCode);

        console.log("ID Registry initCodeHash: ");
        console.logBytes32(idRegistryInitCodeHash);

        // Calculate IdGateway initCodeHash.
        // NOTE: Relies on the idRegistry address being calculated first.
        bytes32 idGatewayInitCodeHash = keccak256(type(IdGateway).creationCode);

        console.log("ID Gateway initCodeHash: ");
        console.logBytes32(idGatewayInitCodeHash);

        // Calculate ProvenanceRegistry initCodeHash.
        bytes32 provenanceRegistryInitCodeHash = keccak256(type(ProvenanceRegistry).creationCode);

        console.log("Provenance Registry initCodeHash: ");
        console.logBytes32(provenanceRegistryInitCodeHash);

        // Calculate ProvenanceGateway initCodeHash.
        // NOTE: Relies on the provenanceRegistry address being calculated first.
        bytes32 provenanceGatewayInitCodeHash = keccak256(type(ProvenanceGateway).creationCode);

        console.log("Provenance Gateway initCodeHash: ");
        console.logBytes32(provenanceGatewayInitCodeHash);

        console.log("\n\n");

        // Sanity check the calculated addresses.
        sanityCheck(idRegistryInitCodeHash, idRegistrySalt, idRegistry);
        sanityCheck(idGatewayInitCodeHash, idGatewaySalt, idGateway);
        sanityCheck(provenanceRegistryInitCodeHash, provenanceRegistrySalt, provenanceRegistry);
        sanityCheck(provenanceGatewayInitCodeHash, provenanceGatewaySalt, provenanceGateway);
    }

    function sanityCheck(bytes32 initCodeHash, bytes32 salt, address expectedAddress) internal pure {
        // Compute the addresses using the salts,
        // and for a final sanity check, compare them to the addresses provided by create2crunch / cast create2.
        address computedAddress = vm.computeCreate2Address(salt, initCodeHash);
        if (computedAddress != expectedAddress) {
            console.log("");

            console.log("ERROR: Address mismatch!");
            console.log("Expected address: %s", address(expectedAddress));
            console.log("Computed address: %s", address(computedAddress));
            return;
        }
    }
}
