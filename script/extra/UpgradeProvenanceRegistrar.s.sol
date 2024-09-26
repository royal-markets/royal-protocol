// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";
import {ProvenanceRegistrar} from "../../src/extra/ProvenanceRegistrar.sol";
import {LibClone} from "solady/utils/LibClone.sol";
import {UUPSUpgradeable} from "solady/utils/UUPSUpgradeable.sol";

// NOTE: Needs to be called by the owner or an ADMIN of the given ProvenanceRegistrar contract.
contract UpgradeProvenanceRegistrar is Script {
    // =============================================================
    //                          INPUTS
    // =============================================================

    // NOTE: Fill in the proxy address of the ProvenanceRegistrar you want to upgrade
    address payable PROXY_ADDRESS = payable(address(0));

    // NOTE: If you want to switch the NFT contract, fill in the new address here
    address NFT_CONTRACT = address(0);

    // =============================================================
    //                          SCRIPT
    // =============================================================

    function run() external {
        vm.startBroadcast();

        // Deploy new implementation
        address newImplementation = address(new ProvenanceRegistrar());
        console.log("PR Implementation address: %s", newImplementation);

        // Upgrade the proxy
        UUPSUpgradeable proxy = UUPSUpgradeable(PROXY_ADDRESS);
        proxy.upgradeToAndCall(address(newImplementation), "");

        ProvenanceRegistrar pr = ProvenanceRegistrar(PROXY_ADDRESS);

        // Set the NFT contract
        if (NFT_CONTRACT != address(0)) {
            pr.setNftContract(NFT_CONTRACT);
        }

        vm.stopBroadcast();
    }
}
