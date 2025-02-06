// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// TODO: Rename this file.

// A representation of an empty/uninitialized UID.
bytes32 constant EMPTY_UID = 0;

// TODO: Review error messages
error AccessDenied();
error InvalidLength();
error NotFound();

/// @notice A struct representing ECDSA signature data.
struct Signature {
    uint8 v; // The recovery ID.
    bytes32 r; // The x-coordinate of the nonce R.
    bytes32 s; // The signature data.
}

/// @notice A struct representing a single record.
struct Record {
    bytes32 uid; // A unique identifier of the record.
    bytes32 schema; // The unique identifier of the schema.
    uint256 originator; // The attester/sender of the record.
    uint256 registrar; // The registrar of the record.
    uint64 time; // The time when the record was created (Unix timestamp).
    uint64 revocationTime; // The time when the record was revoked (Unix timestamp).
    bool revocable; // Whether the record is revocable.
    bool updatable; // Whether the record data is updatable.
    bytes data; // Custom record data.
}
