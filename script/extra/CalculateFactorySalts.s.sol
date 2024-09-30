// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";

import {ProvenanceRegistrar} from "../../src/extra/ProvenanceRegistrar.sol";
import {ProvenanceToken} from "../../src/extra/ProvenanceToken.sol";
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
    bytes32 provenanceRegistrarSalt = bytes32(0x52f2fc187f1c4eea8440780c8264c6e689159db2a12b0cfb3a87f367410fb71f);
    bytes32 provenanceTokenSalt = bytes32(0x97e9f4d717171a211939653620eecc9d37d8c74c76293b5a99fcd7bf2be03448);
    bytes32 registrarFactorySalt = bytes32(0x3b7217a7f12ac0fbf3c019d46f168d4e45960023eba9d1482379481725f8381f);

    // Sanity check the calculated addresses.
    address provenanceRegistrar = address(0x000000E2997fC3A5058cd2934dBFd3b35BF2457B);
    address provenanceToken = address(0x000000161351E81D82277457CA88BB5AaFD40c70);
    address registrarFactory = address(0x000000f87161cA6d2DFAe4244ea7A8AAb2B96350);

    // Salts for CREATE2 proxies.
    bytes32 registrarFactoryProxySalt = bytes32(0xd9db29eb88e1c1f5d898cc82c2ec45ee8e3f0291c54456a65aabecf43659012f);

    // Sanity check proxy addresses
    address registrarFactoryProxy = address(0); // 0x0000009925081F2732a654eF4259171452d24F76

    // Calculate initCode hashes.
    function run() external {
        // Calculate ProvenanceRegistrar initCodeHash.
        bytes32 provenanceRegistrarInitCodeHash = keccak256(type(ProvenanceRegistrar).creationCode);
        console.log("Provenance Registrar initCodeHash: ");
        console.logBytes32(provenanceRegistrarInitCodeHash);
        console.log();

        // Calculate ProvenanceToken initCodeHash.
        bytes32 provenanceTokenInitCodeHash = keccak256(type(ProvenanceToken).creationCode);
        console.log("Provenance Token initCodeHash: ");
        console.logBytes32(provenanceTokenInitCodeHash);
        console.log();

        // Calculate RegistrarFactory initCodeHash.
        bytes32 registrarFactoryInitCodeHash = keccak256(type(RegistrarFactory).creationCode);
        console.log("Registrar Factory initCodeHash: ");
        console.logBytes32(registrarFactoryInitCodeHash);
        console.log();

        // Sanity check the calculated addresses.
        sanityCheck(provenanceRegistrarInitCodeHash, provenanceRegistrarSalt, provenanceRegistrar);
        sanityCheck(provenanceTokenInitCodeHash, provenanceTokenSalt, provenanceToken);
        sanityCheck(registrarFactoryInitCodeHash, registrarFactorySalt, registrarFactory);

        console.log("\n\n");

        // Now we have implementation addresses, calculate proxy addresses.
        //
        // NOTE: The registrarFactory deploys proxies against the ProvenanceRegistrar implementation address,
        // so we don't need to calculate a salt for the ProvenanceRegistrar proxy.
        bytes32 registrarFactoryProxyInitCodeHash = LibClone.initCodeHashERC1967(registrarFactory);
        console.log("Registrar Factory Proxy initCodeHash: ");
        console.logBytes32(registrarFactoryProxyInitCodeHash);
        console.log();

        registrarFactoryProxy = LibClone.deployDeterministicERC1967(registrarFactory, registrarFactoryProxySalt);
        console.log("Registrar Factory Proxy address: ");
        console.logAddress(registrarFactoryProxy);
        console.log();

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
            console.log("ERROR: Address mismatch!");
            console.log("Expected address: %s", address(expectedAddress));
            console.log("Computed address: %s", address(computedAddress));
            console.log();
            return;
        }
    }
}
