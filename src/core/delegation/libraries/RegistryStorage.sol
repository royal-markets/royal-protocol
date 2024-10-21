// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.0;

library RegistryStorage {
    /// @dev Standardizes `fromId` storage flags to prevent double-writes in the delegation in/outbox if the same delegation is revoked and rewritten
    ///
    /// We can't use `1` as a flag, because that is a valid `fromId` value.
    uint256 internal constant DELEGATION_EMPTY = 0;
    uint256 internal constant DELEGATION_REVOKED = 2 ** 256 - 1;

    /// @dev Standardizes storage positions of delegation data
    uint256 internal constant POSITIONS_FROM = 0;
    uint256 internal constant POSITIONS_TO = 1;
    uint256 internal constant POSITIONS_CONTRACT = 2;
    uint256 internal constant POSITIONS_RIGHTS = 3;
    uint256 internal constant POSITIONS_TOKEN_ID = 4;
    uint256 internal constant POSITIONS_AMOUNT = 5;
}
