// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IEIP712 {
    // =============================================================
    //                        EIP712 HELPERS
    // =============================================================

    /**
     * @notice Helper view to read EIP-712 domain separator.
     *
     * @return separator EIP-712 domain separator (bytes32).
     */
    function domainSeparator() external view returns (bytes32 separator);

    /**
     * @notice Helper view to hash EIP-712 typed data onchain.
     *
     * @param structHash EIP-712 typed data hash.
     *
     * @return digest EIP-712 message digest (bytes32).
     */
    function hashTypedData(bytes32 structHash) external view returns (bytes32 digest);
}
