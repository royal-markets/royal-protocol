// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script, console2} from "forge-std/Script.sol";

import {IdRegistry} from "../../src/core/IdRegistry.sol";
import {IdGateway} from "../../src/core/IdGateway.sol";
import {UsernameGateway} from "../../src/core/UsernameGateway.sol";
import {ProvenanceRegistry} from "../../src/core/ProvenanceRegistry.sol";
import {ProvenanceGateway} from "../../src/core/ProvenanceGateway.sol";

// These initCode hashes can be used to calculate more gas-efficient CREATE2 addresses.
//
// Example: Find addresses with 3 bytes of leading zeros (fairly quick).
// cast create2 --starts-with 0x000000 --init-code-hash ${initCodeHash}

contract CalculateSalts is Script {
    // Data used by constructors to calculate initcode hashes.
    address public constant OWNER = 0x62Bd6bD77403268E387a8c7e09aF5D3127186be8;
    address public constant ID_REGISTRY_MIGRATOR = 0xE5673eD07d596E558D280DACdaE346FAF9c9B1A7;

    // NOTE: Needs to be filled in after salt and address calculation.
    address public constant ID_REGISTRY = 0x00000000F74144b0dF049137A0F9416a920F2514;

    // NOTE: Needs to be filled in after salt and address calculation.
    address public constant PROVENANCE_REGISTRY = 0x00000000956fF4AD0c5b076fB77C23a2B0EaD0D9;

    // Salts for sanity checking CREATE2 addresses.
    bytes32 idRegistrySalt = 0x0000000000000000000000000000000000000000fc16b93e000f0000cacf55a5;
    bytes32 idGatewaySalt = 0x000000000000000000000000000000000000000059224fd23c24440000a0154b;
    bytes32 usernameGatewaySalt = 0x000000000000000000000000000000000000000007fe84df4f04000065c41748;
    bytes32 provenanceRegistrySalt = 0xb8a29590b1aa7ed6b776af01fb6d2589fdf0b3dad2f7c534f635c32353625d66;
    bytes32 provenanceGatewaySalt = 0x4da199bca75deebf5eade60beb622777b64ae981713e8d7700b273d5058a2b3f;

    // Sanity check the calculated addresses.
    address idGateway = 0x000000005F8bda585d7D2b1A0b7e29e12a94910a;
    address usernameGateway = 0x00000000A3B81eB162644186b972C0b6a6f5b8E0;
    address provenanceGateway = 0x00000000D224D4E84852C3EBE334aE0E914620d3;

    // Calculate initCode hashes.
    function run() external view {
        // Calculate IdRegistry initCodeHash.
        bytes32 idRegistryInitCodeHash =
            keccak256(abi.encodePacked(type(IdRegistry).creationCode, abi.encode(ID_REGISTRY_MIGRATOR, OWNER)));

        console2.log("ID Registry initCodeHash: ");
        console2.logBytes32(idRegistryInitCodeHash);

        // Calculate IdGateway initCodeHash.
        // NOTE: Relies on the ID_REGISTRY address being calculated first.
        bytes32 idGatewayInitCodeHash =
            keccak256(abi.encodePacked(type(IdGateway).creationCode, abi.encode(ID_REGISTRY, OWNER)));

        console2.log("ID Gateway initCodeHash: ");
        console2.logBytes32(idGatewayInitCodeHash);

        // Calculate UsernameGateway initCodeHash.
        // NOTE: Relies on the ID_REGISTRY address being calculated first.
        bytes32 usernameGatewayInitCodeHash =
            keccak256(abi.encodePacked(type(UsernameGateway).creationCode, abi.encode(ID_REGISTRY, OWNER)));

        console2.log("Username Gateway initCodeHash: ");
        console2.logBytes32(usernameGatewayInitCodeHash);

        // Calculate ProvenanceRegistry initCodeHash.
        bytes32 provenanceRegistryInitCodeHash =
            keccak256(abi.encodePacked(type(ProvenanceRegistry).creationCode, abi.encode(OWNER)));

        console2.log("Provenance Registry initCodeHash: ");
        console2.logBytes32(provenanceRegistryInitCodeHash);

        // Calculate ProvenanceGateway initCodeHash.
        // NOTE: Relies on the PROVENANCE_REGISTRY address being calculated first.
        bytes32 provenanceGatewayInitCodeHash = keccak256(
            abi.encodePacked(type(ProvenanceGateway).creationCode, abi.encode(PROVENANCE_REGISTRY, ID_REGISTRY, OWNER))
        );

        console2.log("Provenance Gateway initCodeHash: ");
        console2.logBytes32(provenanceGatewayInitCodeHash);

        // Sanity check the calculated addresses.
        sanityCheck(idRegistryInitCodeHash, idRegistrySalt, ID_REGISTRY);
        sanityCheck(idGatewayInitCodeHash, idGatewaySalt, idGateway);
        sanityCheck(usernameGatewayInitCodeHash, usernameGatewaySalt, usernameGateway);
        sanityCheck(provenanceRegistryInitCodeHash, provenanceRegistrySalt, PROVENANCE_REGISTRY);
        sanityCheck(provenanceGatewayInitCodeHash, provenanceGatewaySalt, provenanceGateway);
    }

    function sanityCheck(bytes32 initCodeHash, bytes32 salt, address expectedAddress) internal pure {
        // Compute the addresses using the salts,
        // and for a final sanity check, compare them to the addresses provided by create2crunch / cast create2.
        address computedAddress = vm.computeCreate2Address(salt, initCodeHash);
        if (computedAddress != expectedAddress) {
            console2.log("ERROR: Address mismatch!");
            console2.log("Expected address: %s", address(expectedAddress));
            console2.log("Computed address: %s", address(computedAddress));
            return;
        }
    }
}
