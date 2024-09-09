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

contract CalculateSalts is Script {
    // Data used by constructors to calculate initcode hashes.
    address public constant OWNER = 0x62Bd6bD77403268E387a8c7e09aF5D3127186be8;
    address public constant MIGRATOR = 0xE5673eD07d596E558D280DACdaE346FAF9c9B1A7;

    // Salts for sanity checking CREATE2 addresses.
    bytes32 idRegistrySalt = 0x694c5b53b119242271223db1d98d933bceb6d66678b2632597827ced92540255;
    bytes32 idGatewaySalt = 0x5c04a4a41ecb50ba09e6cc0ea8f9fa386da6472f459fa4e8405983201063a5ac;
    bytes32 provenanceRegistrySalt = 0xae6820d88773a3aab8aa8896480ed88ac1b174d01f3955a1ad161e335ef42411;
    bytes32 provenanceGatewaySalt = 0xa041d7c995b5cf119ca344195e34cee5d16f5da9e5850b68eb9f1c8149449576;

    // Sanity check the calculated addresses.
    address idRegistry = 0x0000009ca17b183710537F72A8A7b079cdC8Abe2;
    address idGateway = 0x000000a8D7e86AF5BbA37f06c9a7A28db16C1E43;
    address provenanceRegistry = 0x0000009241E19DABb95c910762C361C225C55637;
    address provenanceGateway = 0x000000080Bb4A34deB4FEa6479F7904CCaB93378;

    // Salts for CREATE2 proxies.
    bytes32 idRegistryProxySalt = 0x2f12417320790ce587c16f9d13ffbe7fa3b1d31f8e3856728bca4e5a00663052;
    bytes32 idGatewayProxySalt = 0xa4c0f5d2ed58ddd62d2ae7e372e00abb2549ffaa2e3500d5ffc7b543d8717d2c;
    bytes32 provenanceRegistryProxySalt = 0xa443b9112e21b5e3f715b035d541a7b0140aa043fe6be10b908435849fc21f18;
    bytes32 provenanceGatewayProxySalt = 0xb96f58746c0581b1ac7c78c157ded10a92623443db30ff304a810addfc74bc56;

    // Sanity check proxy addresses
    address idRegistryProxy = 0x0000002c243D1231dEfA58915324630AB5dBd4f4;
    address idGatewayProxy = 0x000000aA0d40b46F0A78d145c321a9DcfD154Ba7;
    address provenanceRegistryProxy = 0x00000050a3Ca5e18300CcCc0104218BAB2a3a941;
    address provenanceGatewayProxy = 0x000000456Bb9Fd42ADd75F4b5c2247f47D45a0A2;

    // Calculate initCode hashes.
    function run() external {
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

        // Now we have implementation addresses, calculate proxy addresses.
        bytes32 idRegistryProxyInitCodeHash = LibClone.initCodeHashERC1967(idRegistry);
        console.log("ID Registry Proxy initCodeHash: ");
        console.logBytes32(idRegistryProxyInitCodeHash);

        idRegistryProxy = LibClone.deployDeterministicERC1967(idRegistry, idRegistryProxySalt);
        console.log("ID Registry Proxy address: ");
        console.logAddress(idRegistryProxy);
        console.log("");

        bytes32 idGatewayProxyInitCodeHash = LibClone.initCodeHashERC1967(idGateway);
        console.log("ID Gateway Proxy initCodeHash: ");
        console.logBytes32(idGatewayProxyInitCodeHash);

        idGatewayProxy = LibClone.deployDeterministicERC1967(idGateway, idGatewayProxySalt);
        console.log("ID Gateway Proxy address: ");
        console.logAddress(idGatewayProxy);
        console.log("");

        bytes32 provenanceRegistryProxyInitCodeHash = LibClone.initCodeHashERC1967(provenanceRegistry);
        console.log("Provenance Registry Proxy initCodeHash: ");
        console.logBytes32(provenanceRegistryProxyInitCodeHash);

        provenanceRegistryProxy = LibClone.deployDeterministicERC1967(provenanceRegistry, provenanceRegistryProxySalt);
        console.log("Provenance Registry Proxy address: ");
        console.logAddress(provenanceRegistryProxy);
        console.log("");

        bytes32 provenanceGatewayProxyInitCodeHash = LibClone.initCodeHashERC1967(provenanceGateway);
        console.log("Provenance Gateway Proxy initCodeHash: ");
        console.logBytes32(provenanceGatewayProxyInitCodeHash);

        provenanceGatewayProxy = LibClone.deployDeterministicERC1967(provenanceGateway, provenanceGatewayProxySalt);
        console.log("Provenance Gateway Proxy address: ");
        console.logAddress(provenanceGatewayProxy);

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

    // function sanityCheckProxy(address implementation, bytes32 salt, address expectedAddress) internal pure {
    //     // Compute the addresses using the salts.
    //     address predictedAddress = LibClone.predictDeterministicAddressERC1967(implementation, salt, OWNER);
    //     if (predictedAddress != expectedAddress) {
    //         console.log("");

    //         console.log("ERROR: Address mismatch!");
    //         console.log("Expected address: %s", address(expectedAddress));
    //         console.log("Computed address: %s", address(predictedAddress));
    //         return;
    //     }
    // }
}
