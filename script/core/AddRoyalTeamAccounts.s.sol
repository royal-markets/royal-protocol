// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";

import {IIdRegistry} from "../../src/core/interfaces/IIdRegistry.sol";
import {IdRegistry} from "../../src/core/IdRegistry.sol";
import {LibString} from "solady/utils/LibString.sol";

// NOTE: Must be called by the IdRegistry migrator address
contract AddRoyalTeamAccounts is Script {
    // =============================================================
    //                          INPUTS
    // =============================================================

    // NOTE: Fill in the address of the default recovery address for the Royal team.
    address ROYAL_RECOVERY = 0x06428ebF3D4A6322611792BDf674EE2600e37E29;

    // TODO: Base Sepolia Recovery
    // address ROYAL_RECOVERY = 0x1fC0226cEb49B5777a1847d2A0e6d361C336A437;

    // NOTE: Fill in the address of the IdRegistry.
    IdRegistry ID_REGISTRY = IdRegistry(0x0000002c243D1231dEfA58915324630AB5dBd4f4);

    string constant CSV_FILE = "./script/core/royal_accounts.csv";

    // =============================================================
    //                          SCRIPT
    // =============================================================

    function run() external {
        if (msg.sender != ID_REGISTRY.migrator()) {
            console.log("Must run as IdRegistry migrator");
            return;
        }

        if (ROYAL_RECOVERY == address(0)) {
            console.log("ROYAL_RECOVERY must be set");
            return;
        }

        // 15 Royal team accounts as of 2024-07-29
        // + 1 more for friend of the team
        // + a "royal" account.
        IIdRegistry.BulkRegisterWithDefaultRecoveryData[] memory data =
            new IIdRegistry.BulkRegisterWithDefaultRecoveryData[](17);

        string memory rawData = vm.readFile(CSV_FILE);
        string[] memory lines = LibString.split(rawData, "\r\n");

        // Skip header line of CSV, and skip empty line at end of CSV
        for (uint256 i = 1; i < lines.length; i++) {
            string memory line = lines[i];

            string[] memory parts = LibString.split(line, ",");
            require(parts.length == 5, "Invalid line format");

            // id, person, username, custody
            console.log(string.concat("id: ", parts[0], ", Person: ", parts[1]));
            console.log(string.concat("username: ", parts[2], ", custody: ", parts[3]));

            IIdRegistry.BulkRegisterWithDefaultRecoveryData memory entry = IIdRegistry
                .BulkRegisterWithDefaultRecoveryData({username: parts[2], custody: vm.parseAddress(parts[3])});

            data[i - 1] = entry;
        }

        // Start broadcasting the transactions
        vm.startBroadcast();

        // Start the migration process
        ID_REGISTRY.migrate();

        // Actually run the migration
        ID_REGISTRY.bulkRegisterIdsWithDefaultRecovery(data, ROYAL_RECOVERY);

        // Update the IdRegistry IdCounter.
        ID_REGISTRY.setIdCounter(20);

        // Finish broadcasting the transactions
        vm.stopBroadcast();

        // NOTE: Assuming the migration is successful (after double-checking),
        //       The IdRegistry will still need to be manually unpaused.
    }
}
