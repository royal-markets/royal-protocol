// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";

import {IdRegistry} from "../../src/IdRegistry.sol";
import {IdGateway} from "../../src/IdGateway.sol";
import {ProvenanceRegistry} from "../../src/ProvenanceRegistry.sol";
import {ProvenanceGateway} from "../../src/ProvenanceGateway.sol";
import {DelegateRegistry} from "../../src/delegation/DelegateRegistry.sol";

import {LibClone} from "solady/utils/LibClone.sol";

/**
 * NOTE: This script won't work unless you go back in Git history to get the contract code at time of initial deploy.
 *
 * If this ends up being an annoying problem - right solve is probably to use CREATE3 moving forward.
 */
contract DeployProtocolContracts is Script {
    // =============================================================
    //                          INPUTS
    // =============================================================

    // NOTE: Get initcode hashes from CalculateSalts script, and then salts from maldon (or create2crunch/cast).
    bytes32 idRegistrySalt = 0x694c5b53b119242271223db1d98d933bceb6d66678b2632597827ced92540255;
    bytes32 idGatewaySalt = 0x5c04a4a41ecb50ba09e6cc0ea8f9fa386da6472f459fa4e8405983201063a5ac;
    bytes32 provenanceRegistrySalt = 0xd808620b9482d421f45fbb665f508d0cb43c6085006816061c22d56430691f33;
    bytes32 provenanceGatewaySalt = 0xa041d7c995b5cf119ca344195e34cee5d16f5da9e5850b68eb9f1c8149449576;
    bytes32 delegateRegistrySalt = 0xf5bf81b6deba33121dd051d98eff71f399925dba9d5010a496ebb30ca1531567;

    bytes32 idRegistryProxySalt = 0x2f12417320790ce587c16f9d13ffbe7fa3b1d31f8e3856728bca4e5a00663052;
    bytes32 idGatewayProxySalt = 0xa4c0f5d2ed58ddd62d2ae7e372e00abb2549ffaa2e3500d5ffc7b543d8717d2c;
    bytes32 provenanceRegistryProxySalt = 0x9cffda279a73972e3960008f3863355e414a28d01b58b04b305a386bc81ce353;
    bytes32 provenanceGatewayProxySalt = 0xb96f58746c0581b1ac7c78c157ded10a92623443db30ff304a810addfc74bc56;
    bytes32 delegateRegistryProxySalt = 0x1156cd4e919ca25dd1aafd4328e68eaf4bd98e0ab0a7e0be373758e5933015a4;

    // NOTE: Double-check addresses?
    address public constant ID_REGISTRY_ADDR = 0x0000002c243D1231dEfA58915324630AB5dBd4f4;
    address public constant ID_GATEWAY_ADDR = 0x000000aA0d40b46F0A78d145c321a9DcfD154Ba7;
    address public constant PROVENANCE_REGISTRY_ADDR = 0x0000009F840EeF8A92E533468A0Ef45a1987Da66;
    address public constant PROVENANCE_GATEWAY_ADDR = 0x000000456Bb9Fd42ADd75F4b5c2247f47D45a0A2;
    address public constant DELEGATE_REGISTRY_ADDR = 0x000000f1CABe81De9e020C9fac95318b14B80F14;

    address public constant OWNER = 0x62Bd6bD77403268E387a8c7e09aF5D3127186be8;
    address public constant MIGRATOR = 0xE5673eD07d596E558D280DACdaE346FAF9c9B1A7;

    // =============================================================
    //                          SCRIPT
    // =============================================================

    function run() external {
        if (msg.sender != OWNER) {
            console.log("Must run as OWNER");
            return;
        }

        vm.startBroadcast();

        // Deploy Account contracts
        address idRegistryImplementation = address(new IdRegistry{salt: idRegistrySalt}());
        IdRegistry idRegistry =
            IdRegistry(LibClone.deployDeterministicERC1967(idRegistryImplementation, idRegistryProxySalt));
        idRegistry.initialize(MIGRATOR, OWNER);
        console.log("IdRegistry address: %s", address(idRegistry));

        address idGatewayImplementation = address(new IdGateway{salt: idGatewaySalt}());
        IdGateway idGateway =
            IdGateway(LibClone.deployDeterministicERC1967(idGatewayImplementation, idGatewayProxySalt));
        idGateway.initialize(idRegistry, OWNER);
        console.log("IdGateway address: %s", address(idGateway));

        // Configure gateways on the IdRegistry
        idRegistry.setIdGateway(address(idGateway));

        // Deploy Provenance contracts
        address provenanceRegistryImplementation = address(new ProvenanceRegistry{salt: provenanceRegistrySalt}());
        ProvenanceRegistry provenanceRegistry = ProvenanceRegistry(
            LibClone.deployDeterministicERC1967(provenanceRegistryImplementation, provenanceRegistryProxySalt)
        );
        provenanceRegistry.initialize(idRegistry, MIGRATOR, OWNER);
        console.log("ProvenanceRegistry address: %s", address(provenanceRegistry));

        address provenanceGatewayImplementation = address(new ProvenanceGateway{salt: provenanceGatewaySalt}());
        ProvenanceGateway provenanceGateway = ProvenanceGateway(
            LibClone.deployDeterministicERC1967(provenanceGatewayImplementation, provenanceGatewayProxySalt)
        );
        provenanceGateway.initialize(provenanceRegistry, idRegistry, OWNER);
        console.log("ProvenanceGateway address: %s", address(provenanceGateway));

        // Set the ProvenanceGateway on the ProvenanceRegistry
        provenanceRegistry.setProvenanceGateway(address(provenanceGateway));

        address delegateRegistryImplementation = address(new DelegateRegistry{salt: delegateRegistrySalt}());
        DelegateRegistry delegateRegistry = DelegateRegistry(
            LibClone.deployDeterministicERC1967(delegateRegistryImplementation, delegateRegistryProxySalt)
        );
        delegateRegistry.initialize(ID_REGISTRY_ADDR, OWNER);
        console.log("DelegateRegistry address: %s", address(delegateRegistry));
        IdRegistry(ID_REGISTRY_ADDR).setDelegateRegistry(address(delegateRegistry));

        vm.stopBroadcast();
    }
}
