// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";

import {ProvenanceToken} from "../../src/extra/ProvenanceToken.sol";
import {ProvenanceRegistrar} from "../../src/extra/ProvenanceRegistrar.sol";
import {RegistrarFactory} from "../../src/extra/RegistrarFactory.sol";

import {LibClone} from "solady/utils/LibClone.sol";

// NOTE: Must be called by the OWNER address
contract DeployRegistrarFactory is Script {
    // =============================================================
    //                          INPUTS
    // =============================================================

    bytes32 provenanceRegistrarSalt = bytes32(0x52f2fc187f1c4eea8440780c8264c6e689159db2a12b0cfb3a87f367410fb71f);
    bytes32 provenanceTokenSalt = bytes32(0x97e9f4d717171a211939653620eecc9d37d8c74c76293b5a99fcd7bf2be03448);
    bytes32 registrarFactorySalt = bytes32(0x3b7217a7f12ac0fbf3c019d46f168d4e45960023eba9d1482379481725f8381f);
    bytes32 registrarFactoryProxySalt = bytes32(0xd9db29eb88e1c1f5d898cc82c2ec45ee8e3f0291c54456a65aabecf43659012f);

    // NOTE: Fill in the address of the OWNER.
    address public constant OWNER = address(0x9E7F2530512D192D706480C439083BbB5F1028A7);

    // NOTE: (Optional): Fill in this address, which is the address that will be able to call `recover` on the RecoveryProxy.
    address admin = address(0xF338058cF377C421Fe2625f963EDD9e43Cf55b7a);

    // NOTE: (Optional): This is the address that will be able to call `registerClaim` on the ProvenanceRegistrar.
    address deployCaller = address(0x61d1a48a530e76905FB85d643223fa6a4CFed9ee);

    // =============================================================
    //                          SCRIPT
    // =============================================================

    function run() external {
        if (msg.sender != OWNER) {
            console.log("Must run as OWNER");
            return;
        }

        vm.startBroadcast();

        // Deploy ProvenanceRegistrar implementation
        address prImplementation = address(new ProvenanceRegistrar{salt: provenanceRegistrarSalt}());
        console.log("PR Implementation address: %s", prImplementation);

        // Deploy ProvenanceToken implementation
        address ptImplementation = address(new ProvenanceToken{salt: provenanceTokenSalt}());
        console.log("PT Implementation address: %s", ptImplementation);

        // Deploy RegistrarFactory implementation
        address rfImplementation = address(new RegistrarFactory{salt: registrarFactorySalt}());
        console.log("RF Implementation address: %s", rfImplementation);

        // Deploy Proxy for RegistrarFactory
        RegistrarFactory registrarFactory =
            RegistrarFactory(LibClone.deployDeterministicERC1967(rfImplementation, registrarFactoryProxySalt));
        console.log("RegistrarFactory (proxy) address: %s", address(registrarFactory));

        // Initialize RegistrarFactory
        registrarFactory.initialize(OWNER, prImplementation, ptImplementation);

        // Set up roles on contracts
        if (admin != address(0)) {
            registrarFactory.addAdmin(admin);
        }

        if (deployCaller != address(0)) {
            registrarFactory.addDeployCaller(deployCaller);
        }

        vm.stopBroadcast();
    }
}
