// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";

import {IIdRegistry} from "../../src/core/interfaces/IIdRegistry.sol";
import {IProvenanceRegistry} from "../../src/core/interfaces/IProvenanceRegistry.sol";
import {IdRegistry} from "../../src/core/IdRegistry.sol";
import {ProvenanceRegistry} from "../../src/core/ProvenanceRegistry.sol";

import {LibClone} from "solady/utils/LibClone.sol";

interface IOldIdRegistry {
    struct User {
        uint256 id;
        address custody;
        string username;
        address operator; // Optional
        address recovery; // Optional
    }

    function idCounter() external view returns (uint256);
    function custodyOf(uint256 id) external view returns (address);
    function getUserById(uint256 id) external view returns (User memory);
}

contract RunMigration is Script {
    // =============================================================
    //                          INPUTS
    // =============================================================

    address public constant MIGRATOR = 0xE5673eD07d596E558D280DACdaE346FAF9c9B1A7;

    IOldIdRegistry public constant OLD_ID_REGISTRY = IOldIdRegistry(0x00000000F74144b0dF049137A0F9416a920F2514);
    IProvenanceRegistry public constant OLD_PROVENANCE_REGISTRY =
        IProvenanceRegistry(0x00000000F7bc9dC673b207E541eF79ea15547690);

    IdRegistry idRegistry = IdRegistry(0x0000002c243D1231dEfA58915324630AB5dBd4f4);
    ProvenanceRegistry provenanceRegistry = ProvenanceRegistry(0x0000009F840EeF8A92E533468A0Ef45a1987Da66);

    // =============================================================
    //                          SCRIPT
    // =============================================================

    function run() external {
        if (msg.sender != MIGRATOR) {
            console.log("Must run as MIGRATOR");
            return;
        }

        vm.startBroadcast();

        // Start the migration process
        console.log("Migrator", idRegistry.migrator());
        idRegistry.migrate();

        migrateRoyalTeamAccounts();

        uint256 oldIdCounter = OLD_ID_REGISTRY.idCounter();
        uint256 newIdCounter = idRegistry.idCounter();

        while (newIdCounter < oldIdCounter) {
            migrateAccounts(newIdCounter);
            newIdCounter = idRegistry.idCounter();
        }

        // Console log, Check a few entities against old contract for off by one error
        IIdRegistry.User memory user = idRegistry.getUserById(idRegistry.idCounter());
        console.log("Last user: %s", user.username);
        console.log("Last user custody: %s", user.custody);

        IOldIdRegistry.User memory oldUser = OLD_ID_REGISTRY.getUserById(OLD_ID_REGISTRY.idCounter());
        console.log("Last old user: %s", oldUser.username);
        console.log("Last old user custody: %s", oldUser.custody);

        // Migrate the provenance registry
        provenanceRegistry.migrate();

        uint256 oldProvenanceCounter = OLD_PROVENANCE_REGISTRY.idCounter();
        uint256 newProvenanceCounter = provenanceRegistry.idCounter();

        while (newProvenanceCounter < oldProvenanceCounter) {
            migrateProvenanceClaims(newProvenanceCounter);
            newProvenanceCounter = provenanceRegistry.idCounter();
        }

        // Console log, Check a few entities against old contract for off by one error
        // Compare both the provenanceCLaim data AND
        // Compare the originator + register on the old vs new contracts
        IProvenanceRegistry.ProvenanceClaim memory claim =
            provenanceRegistry.provenanceClaim(provenanceRegistry.idCounter());
        console.log("Last claim registrarId: %s", claim.registrarId);
        console.log("Last claim originatorId: %s", claim.originatorId);
        console.log("Last claim contentHash");
        console.logBytes32(claim.contentHash);

        IProvenanceRegistry.ProvenanceClaim memory oldClaim =
            OLD_PROVENANCE_REGISTRY.provenanceClaim(OLD_PROVENANCE_REGISTRY.idCounter());
        console.log("Last old registrarId: %s", oldClaim.registrarId);
        console.log("Last old originatorId: %s", oldClaim.originatorId);
        console.log("Last old contentHash");
        console.logBytes32(oldClaim.contentHash);

        vm.stopBroadcast();
    }

    function migrateRoyalTeamAccounts() internal {
        // 15 Royal team accounts + 1 more for friend of the team
        IIdRegistry.BulkRegisterData[] memory data = new IIdRegistry.BulkRegisterData[](17);

        // 15 Royal team accounts + 1 more for friend of the team
        for (uint256 id = 1; id <= 16; id++) {
            IOldIdRegistry.User memory user = OLD_ID_REGISTRY.getUserById(id);
            address custody = user.operator != address(0) ? user.operator : user.custody;

            IIdRegistry.BulkRegisterData memory entry =
                IIdRegistry.BulkRegisterData({username: user.username, custody: custody, recovery: user.recovery});

            data[id - 1] = entry;
        }

        data[16] = IIdRegistry.BulkRegisterData({
            username: "royal",
            custody: 0xE83Ece32Ab2cD3fDadB0eb4052BBecf516309d7B,
            recovery: 0x06428ebF3D4A6322611792BDf674EE2600e37E29
        });

        // Actually run the migration
        idRegistry.bulkRegisterIds(data);

        // Update the IdRegistry IdCounter.
        idRegistry.setIdCounter(20);
    }

    function migrateAccounts(uint256 newIdCounter) internal {
        IIdRegistry.BulkRegisterData[] memory data = new IIdRegistry.BulkRegisterData[](20);

        uint256 startId = newIdCounter + 1;
        uint256 endId = newIdCounter + 20;
        for (uint256 id = startId; id <= endId; id++) {
            try OLD_ID_REGISTRY.getUserById(id) returns (IOldIdRegistry.User memory user) {
                address custody = user.operator != address(0) ? user.operator : user.custody;

                IIdRegistry.BulkRegisterData memory entry =
                    IIdRegistry.BulkRegisterData({username: user.username, custody: custody, recovery: user.recovery});

                data[id - startId] = entry;
            } catch {
                uint256 arraySize = id - startId;
                IIdRegistry.BulkRegisterData[] memory shrinkedData = new IIdRegistry.BulkRegisterData[](arraySize);
                for (uint256 i = 0; i < arraySize; i++) {
                    shrinkedData[i] = data[i];
                }

                data = shrinkedData;
                break;
            }
        }

        // Actually run the migration
        idRegistry.bulkRegisterIds(data);
    }

    function migrateProvenanceClaims(uint256 newIdCounter) internal {
        IProvenanceRegistry.BulkRegisterData[] memory data = new IProvenanceRegistry.BulkRegisterData[](20);

        uint256 startId = newIdCounter + 1;
        uint256 endId = newIdCounter + 20;
        for (uint256 id = startId; id <= endId; id++) {
            IProvenanceRegistry.ProvenanceClaim memory claim = OLD_PROVENANCE_REGISTRY.provenanceClaim(id);
            if (claim.originatorId != 0) {
                IProvenanceRegistry.BulkRegisterData memory entry = IProvenanceRegistry.BulkRegisterData({
                    originatorId: claim.originatorId,
                    registrarId: claim.registrarId,
                    contentHash: claim.contentHash,
                    nftContract: claim.nftContract,
                    nftTokenId: claim.nftTokenId
                });

                data[id - startId] = entry;
            } else {
                uint256 arraySize = id - startId;
                IProvenanceRegistry.BulkRegisterData[] memory shrinkedData =
                    new IProvenanceRegistry.BulkRegisterData[](arraySize);
                for (uint256 i = 0; i < arraySize; i++) {
                    shrinkedData[i] = data[i];
                }

                data = shrinkedData;
                break;
            }
        }

        provenanceRegistry.bulkRegisterProvenanceClaims(data);
    }
}
