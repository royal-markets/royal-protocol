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
    bytes32 idRegistrySalt = 0x694c5b53b119242271223db1d98d933bceb6d66678b2632597827ced92540255;
    bytes32 idGatewaySalt = 0xccb16697c900cc61bec57df9a948a42abf81d068c857ee77bc81ff23c758783f;
    bytes32 provenanceRegistrySalt = 0xd808620b9482d421f45fbb665f508d0cb43c6085006816061c22d56430691f33;
    bytes32 provenanceGatewaySalt = 0xf0831a0056424dedfc91ad623849217e0e30e3059ae83b0db33323774f6820a6;

    // Sanity check the calculated addresses.
    address idRegistry = address(0x0000009ca17b183710537F72A8A7b079cdC8Abe2);
    address idGateway = address(0x00000030648c5313cAAaA533b9d95EDC7ED9efAe);
    address provenanceRegistry = address(0x00000097f9ea21c1A35e525103D41BBD0A887456);
    address provenanceGateway = address(0x00000018fA808b43f862F9e706fB10C5072c4f29);

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
