// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Nonces as NoncesBase} from "@openzeppelin/contracts/utils/Nonces.sol";
import {INonces} from "../interfaces/abstract/INonces.sol";

/**
 * @notice wrapper around nonces.
 *
 * Exposes a method to increment a nonce, invalidating previous signatures.
 */
abstract contract Nonces is INonces, NoncesBase {
    // =============================================================
    //                          NONCES
    // =============================================================

    /// @inheritdoc INonces
    function useNonce() external returns (uint256) {
        return _useNonce(msg.sender);
    }
}
