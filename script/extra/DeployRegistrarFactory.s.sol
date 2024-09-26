// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";

import {ProvenanceRegistrar} from "../../src/extra/ProvenanceRegistrar.sol";
import {RegistrarFactory} from "../../src/extra/RegistrarFactory.sol";

import {LibClone} from "solady/utils/LibClone.sol";

// NOTE: Must be called by the OWNER address
contract DeployRegistrarFactory is Script {
    // =============================================================
    //                          INPUTS
    // =============================================================

    bytes32 provenanceRegistrarSalt = bytes32(0x86c6a8afaef078040493cbdf20192d3e6085100df2e0597cd47c1576291c93fe);
    bytes32 registrarFactorySalt = bytes32(0xb3891deeba58ffc8a266e1249b877e141f62807db4350a27c916278b91673ed5);
    bytes32 registrarFactoryProxySalt = bytes32(0x10a2bde502514c3a3aa0bc383364db6de1d050d33a1dca23576d06572b56cd5a);

    // TODO: Double check these addresses!
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

        // Deploy RegistrarFactory implementation
        address rfImplementation = address(new RegistrarFactory{salt: registrarFactorySalt}());
        console.log("RF Implementation address: %s", rfImplementation);

        // Deploy Proxy for RegistrarFactory
        RegistrarFactory registrarFactory =
            RegistrarFactory(LibClone.deployDeterministicERC1967(rfImplementation, registrarFactoryProxySalt));
        console.log("RegistrarFactory (proxy) address: %s", address(registrarFactory));

        // Initialize RegistrarFactory
        registrarFactory.initialize(OWNER, prImplementation);

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
