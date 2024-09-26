// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IRoleData {
    // =============================================================
    //                          STRUCTS
    // =============================================================

    struct RoleData {
        address holder; // address that holds the roles
        uint256 roles; // bitmask of roles
    }
}
