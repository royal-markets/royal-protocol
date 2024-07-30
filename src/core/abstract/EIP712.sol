// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {EIP712 as EIP712Base} from "solady/utils/EIP712.sol";

abstract contract EIP712 is EIP712Base {
    // =============================================================
    //                          EIP712
    // =============================================================

    /// @notice Helper view to read EIP-712 domain separator.
    function domainSeperator() external view returns (bytes32 separator) {
        return _domainSeparator();
    }

    /**
     * @notice Helper view to hash EIP-712 typed data onchain.
     *
     * @param structHash EIP-712 typed data hash.
     *
     * @return digest EIP-712 message digest (bytes32).
     */
    function hashTypedData(bytes32 structHash) external view returns (bytes32 digest) {
        return _hashTypedData(structHash);
    }
}
