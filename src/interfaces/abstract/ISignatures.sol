// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ISignatures {
    // =============================================================
    //                            ERRORS
    // =============================================================

    /// @dev Revert when the signature provided is invalid.
    error InvalidSignature();

    /// @dev Revert when the block.timestamp is ahead of the signature deadline.
    error SignatureExpired();
}
