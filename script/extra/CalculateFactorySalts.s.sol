// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";

import {ProvenanceRegistrar} from "../../src/extra/ProvenanceRegistrar.sol";
import {RegistrarFactory} from "../../src/extra/RegistrarFactory.sol";

import {LibClone} from "solady/utils/LibClone.sol";

// These initCode hashes can be used to calculate more gas-efficient CREATE2 addresses.
//
// Example: Find addresses with 3 bytes of leading zeros (fairly quick).
// cast create2 --starts-with 0x000000 --init-code-hash ${initCodeHash}

contract CalculateFactorySalts is Script {
    // Data used by constructors to calculate initcode hashes.
    // TODO: Check owner address is in 1Password
    address public constant OWNER = 0x9E7F2530512D192D706480C439083BbB5F1028A7;

    // Salts for sanity checking CREATE2 addresses.
    bytes32 provenanceRegistrarSalt = bytes32(0xd9e15205d6cfcb423b1b59a9c5e44edd869af5300c94901c61a80e97184aaba3);
    bytes32 registrarFactorySalt = bytes32(0xb3891deeba58ffc8a266e1249b877e141f62807db4350a27c916278b91673ed5);

    // Sanity check the calculated addresses.
    address provenanceRegistrar = address(0x0000005F4f59E782Ac7247F9d136552A7FFF07D7);
    address registrarFactory = address(0x00000088b59710494B0539ec09aE7D025bc10EFa);

    // Salts for CREATE2 proxies.
    bytes32 registrarFactoryProxySalt = bytes32(0x10a2bde502514c3a3aa0bc383364db6de1d050d33a1dca23576d06572b56cd5a);

    // Sanity check proxy addresses
    address registrarFactoryProxy = address(0); // 0x000000C0E95b5EB71f6DC4f6ce3DC31635F4794b

    // Calculate initCode hashes.
    function run() external {
        // Calculate ProvenanceRegistrar initCodeHash.
        bytes32 provenanceRegistrarInitCodeHash = keccak256(type(ProvenanceRegistrar).creationCode);

        console.log("Provenance Registrar initCodeHash: ");
        console.logBytes32(provenanceRegistrarInitCodeHash);

        // Calculate RegistrarFactory initCodeHash.
        bytes32 registrarFactoryInitCodeHash = keccak256(type(RegistrarFactory).creationCode);

        console.log("Registrar Factory initCodeHash: ");
        console.logBytes32(registrarFactoryInitCodeHash);
        console.log("\n");

        // Sanity check the calculated addresses.
        sanityCheck(provenanceRegistrarInitCodeHash, provenanceRegistrarSalt, provenanceRegistrar);
        sanityCheck(registrarFactoryInitCodeHash, registrarFactorySalt, registrarFactory);

        // Now we have implementation addresses, calculate proxy addresses.
        //
        // NOTE: The registrarFactory deploys proxies against the ProvenanceRegistrar implementation address,
        // so we don't need to calculate a salt for the ProvenanceRegistrar proxy.
        bytes32 registrarFactoryProxyInitCodeHash = LibClone.initCodeHashERC1967(registrarFactory);
        console.log("Registrar Factory Proxy initCodeHash: ");
        console.logBytes32(registrarFactoryProxyInitCodeHash);

        registrarFactoryProxy = LibClone.deployDeterministicERC1967(registrarFactory, registrarFactoryProxySalt);
        console.log("Registrar Factory Proxy address: ");
        console.logAddress(registrarFactoryProxy);

        // Sanity check the calculated proxy addresses.
        // sanityCheckProxy(idRegistry, idRegistryProxySalt, idRegistryProxy);
        // sanityCheckProxy(idGateway, idGatewayProxySalt, idGatewayProxy);
        // sanityCheckProxy(provenanceRegistry, provenanceRegistryProxySalt, provenanceRegistryProxy);
        // sanityCheckProxy(provenanceGateway, provenanceGatewayProxySalt, provenanceGatewayProxy);
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
