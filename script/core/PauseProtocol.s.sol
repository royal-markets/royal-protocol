// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";

interface Pausable {
    function pause() external;

    function unpause() external;

    function paused() external returns (bool);
}

contract PauseProtocol is Script {
    // =============================================================
    //                          INPUTS
    // =============================================================

    address public constant OWNER = 0x62Bd6bD77403268E387a8c7e09aF5D3127186be8;

    Pausable idRegistry = Pausable(0x0000002c243D1231dEfA58915324630AB5dBd4f4);
    Pausable idGateway = Pausable(0x000000aA0d40b46F0A78d145c321a9DcfD154Ba7);
    Pausable provenanceRegistry = Pausable(0x0000009F840EeF8A92E533468A0Ef45a1987Da66);
    Pausable provenanceGateway = Pausable(0x000000456Bb9Fd42ADd75F4b5c2247f47D45a0A2);

    // =============================================================
    //                          SCRIPT
    // =============================================================

    function run() external {
        if (msg.sender != OWNER) {
            console.log("Must run as OWNER");
            return;
        }

        vm.startBroadcast();

        // Pause the protocol
        if (!idRegistry.paused()) {
            idRegistry.pause();
            console.log("Paused IdRegistry");
        }

        if (!idGateway.paused()) {
            idGateway.pause();
            console.log("Paused IdGateway");
        }

        if (!provenanceRegistry.paused()) {
            provenanceRegistry.pause();
            console.log("Paused ProvenanceRegistry");
        }

        if (!provenanceGateway.paused()) {
            provenanceGateway.pause();
            console.log("Paused ProvenanceGateway");
        }

        vm.stopBroadcast();
    }
}
