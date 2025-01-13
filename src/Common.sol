// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// TODO: Rename this file.

// A representation of an empty/uninitialized UID.
bytes32 constant EMPTY_UID = 0;

// A zero expiration represents an non-expiring attestation.
uint64 constant NO_EXPIRATION_TIME = 0;

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

/// @notice A struct representing a single attestation.
struct Attestation {
    bytes32 uid; // A unique identifier of the attestation.
    bytes32 schema; // The unique identifier of the schema.
    uint64 time; // The time when the attestation was created (Unix timestamp).
    uint64 expirationTime; // The time when the attestation expires (Unix timestamp).
    uint64 revocationTime; // The time when the attestation was revoked (Unix timestamp).
    uint256 originator; // The attester/sender of the attestation.
    uint256 registrar; // The registrar of the attestation.
    bool revocable; // Whether the attestation is revocable.
    bytes data; // Custom attestation data.
}

// Custom types.
type AccountID is uint256;

type ProvenanceClaimID is uint256;

type AttestationID is bytes32;
