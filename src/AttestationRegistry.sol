// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ISchemaResolver} from "./schema-resolver/ISchemaResolver.sol";

import {AccessDenied, NotFound, Signature, EMPTY_UID, InvalidLength, NotFound, NO_EXPIRATION_TIME} from "./Common.sol";

import {Withdrawable} from "./abstract/Withdrawable.sol";
import {Signatures} from "./abstract/Signatures.sol";
import {EIP712} from "./abstract/EIP712.sol";
import {Nonces} from "./abstract/Nonces.sol";
import {Initializable} from "solady/utils/Initializable.sol";
import {UUPSUpgradeable} from "solady/utils/UUPSUpgradeable.sol";

import {
    Attestation,
    AttestationRequest,
    AttestationRequestData,
    DelegatedAttestationRequest,
    DelegatedRevocationRequest,
    IAttestationRegistry,
    MultiAttestationRequest,
    MultiDelegatedAttestationRequest,
    MultiDelegatedRevocationRequest,
    MultiRevocationRequest,
    RevocationRequest,
    RevocationRequestData
} from "./interfaces/IAttestationRegistry.sol";

import {ISchemaRegistry, SchemaRecord} from "./interfaces/ISchemaRegistry.sol";
import {IIdRegistry} from "./interfaces/IIdRegistry.sol";

/// @title AttestationRegistry
/// @notice The AttestationRegistry for protocol SchemaData.
contract AttestationRegistry is
    IAttestationRegistry,
    Withdrawable,
    Signatures,
    EIP712,
    Nonces,
    Initializable,
    UUPSUpgradeable
{
    error AlreadyRevoked();
    error AlreadyRevokedOffchain();
    error AlreadyTimestamped();
    error AlreadyAttested();
    error InsufficientValue();
    error InvalidAttestation();
    error InvalidAttestations();
    error InvalidExpirationTime();
    error InvalidRegistry();
    error InvalidRevocation();
    error InvalidRevocations();
    error InvalidSchema();
    error Irrevocable();
    error NotPayable();
    error RefundFailed();

    /// @notice A struct representing an internal attestation result.
    struct AttestationsResult {
        uint256 usedValue; // Total ETH amount that was sent to resolvers.
        bytes32[] uids; // UIDs of the new attestations.
    }

    // =============================================================
    //                           CONSTANTS
    // =============================================================

    /* solhint-disable gas-small-strings */

    /// @inheritdoc IAttestationRegistry
    string public constant VERSION = "2025-01-06";

    /// @inheritdoc IAttestationRegistry
    bytes32 public constant ATTEST_TYPEHASH = keccak256(
        "Attest(uint256 originator,bytes32 schema,uint64 expirationTime,bool revocable,bytes data,uint256 value,uint256 nonce,uint256 deadline)"
    );

    /// @inheritdoc IAttestationRegistry
    bytes32 public constant REVOKE_TYPEHASH =
        keccak256("Revoke(uint256 revoker,bytes32 schema,bytes32 uid,uint256 value,uint256 nonce,uint256 deadline)");

    /* solhint-enable gas-small-strings */

    // The global schema registry.
    ISchemaRegistry public immutable SCHEMA_REGISTRY;

    // The global IdRegistry.
    IIdRegistry public immutable ID_REGISTRY;

    // The global mapping between attestations and their UIDs.
    mapping(bytes32 uid => Attestation attestation) private _db;

    // The global mapping between data and their timestamps.
    mapping(bytes32 data => uint64 timestamp) private _timestamps;

    // The global mapping between data and their revocation timestamps.
    mapping(uint256 revoker => mapping(bytes32 data => uint64 timestamp) timestamps) private _revocationsOffchain;

    /// @dev Creates a new AttestationRegistry instance.
    /// @param schemaRegistry_ The address of the global schema registry.
    /// @param idRegistry_ The address of the global IdRegistry.
    constructor(ISchemaRegistry schemaRegistry_, IIdRegistry idRegistry_) {
        if (address(schemaRegistry_) == address(0) || address(idRegistry_) == address(0)) {
            revert InvalidRegistry();
        }

        SCHEMA_REGISTRY = schemaRegistry_;
        ID_REGISTRY = idRegistry_;
    }

    // =============================================================
    //                          EIP712
    // =============================================================

    /// @dev Configure the EIP712 name and version for the domain separator.
    function _domainNameAndVersion() internal pure override returns (string memory name, string memory version) {
        // solhint-disable-next-line gas-small-strings
        name = "RoyalProtocol_AttestationRegistry";
        version = "1";
    }

    /// @inheritdoc IAttestationRegistry
    function attest(uint256 originator, AttestationRequest calldata request)
        external
        payable
        override
        returns (bytes32 uid)
    {
        uint256 registrar = canAttest(originator);

        AttestationRequestData[] memory data = new AttestationRequestData[](1);
        data[0] = request.data;

        return _attest({
            schemaUID: request.schema,
            data: data,
            originator: originator,
            registrar: registrar,
            availableValue: msg.value
        }).uids[0];
    }

    /// @inheritdoc IAttestationRegistry
    function attestByDelegation(DelegatedAttestationRequest calldata delegatedRequest)
        external
        payable
        override
        returns (bytes32 uid)
    {
        _verifyAttestSig(delegatedRequest);
        uint256 registrar = ID_REGISTRY.idOf(msg.sender);

        AttestationRequestData[] memory data = new AttestationRequestData[](1);
        data[0] = delegatedRequest.data;

        return _attest({
            schemaUID: delegatedRequest.schema,
            data: data,
            originator: delegatedRequest.originator,
            registrar: registrar,
            availableValue: msg.value
        }).uids[0];
    }

    /// @inheritdoc IAttestationRegistry
    function multiAttest(uint256 originator, MultiAttestationRequest[] calldata multiRequests)
        external
        payable
        override
        returns (bytes32[] memory)
    {
        // Since a multi-attest call is going to make multiple attestations for multiple schemas, we'd need to collect
        // all the returned UIDs into a single list.
        uint256 length = multiRequests.length;
        bytes32[][] memory totalUIDs = new bytes32[][](length);
        uint256 totalUIDCount = 0;

        // We are keeping track of the total available ETH amount that can be sent to resolvers and will keep deducting
        // from it to verify that there isn't any attempt to send too much ETH to resolvers. Please note that unless
        // some ETH was stuck in the contract by accident (which shouldn't happen in normal conditions), it won't be
        // possible to send too much ETH anyway.
        uint256 availableValue = msg.value;
        uint256 registrar = canAttest(originator);

        unchecked {
            for (uint256 i = 0; i < length; i++) {
                // Process the current batch of attestations.
                MultiAttestationRequest calldata multiRequest = multiRequests[i];

                // Ensure that data isn't empty.
                if (multiRequest.data.length == 0) {
                    revert InvalidLength();
                }

                AttestationsResult memory res = _attest({
                    schemaUID: multiRequest.schema,
                    data: multiRequest.data,
                    originator: originator,
                    registrar: registrar,
                    availableValue: availableValue
                });

                // Ensure to deduct the ETH that was forwarded to the resolver during the processing of this batch.
                availableValue -= res.usedValue;

                // Collect UIDs (and merge them later).
                totalUIDs[i] = res.uids;
                totalUIDCount += res.uids.length;
            }
        }

        if (availableValue != 0) {
            _refund(availableValue);
        }

        // Merge all the collected UIDs and return them as a flatten array.
        return _mergeUIDs(totalUIDs, totalUIDCount);
    }

    /// @inheritdoc IAttestationRegistry
    function multiAttestByDelegation(MultiDelegatedAttestationRequest[] calldata multiDelegatedRequests)
        external
        payable
        override
        returns (bytes32[] memory)
    {
        // Since a multi-attest call is going to make multiple attestations for multiple schemas, we'd need to collect
        // all the returned UIDs into a single list.
        uint256 length = multiDelegatedRequests.length;
        bytes32[][] memory totalUIDs = new bytes32[][](length);
        uint256 totalUIDCount = 0;

        // We are keeping track of the total available ETH amount that can be sent to resolvers and will keep deducting
        // from it to verify that there isn't any attempt to send too much ETH to resolvers. Please note that unless
        // some ETH was stuck in the contract by accident (which shouldn't happen in normal conditions), it won't be
        // possible to send too much ETH anyway.
        uint256 availableValue = msg.value;

        unchecked {
            for (uint256 i = 0; i < length; i++) {
                MultiDelegatedAttestationRequest calldata multiDelegatedRequest = multiDelegatedRequests[i];
                AttestationRequestData[] calldata data = multiDelegatedRequest.data;

                // Ensure that no inputs are missing.
                uint256 dataLength = data.length;
                if (dataLength == 0 || dataLength != multiDelegatedRequest.signatures.length) {
                    revert InvalidLength();
                }

                // Verify signatures. Please note that the signatures are assumed to be signed with increasing nonces.
                for (uint256 j = 0; j < dataLength; j++) {
                    _verifyAttestSig(
                        DelegatedAttestationRequest({
                            schema: multiDelegatedRequest.schema,
                            data: data[j],
                            signature: multiDelegatedRequest.signatures[j],
                            originator: multiDelegatedRequest.originator,
                            deadline: multiDelegatedRequest.deadline
                        })
                    );
                }

                // Process the current batch of attestations.
                uint256 registrar = ID_REGISTRY.idOf(msg.sender);
                AttestationsResult memory res = _attest({
                    schemaUID: multiDelegatedRequest.schema,
                    data: data,
                    originator: multiDelegatedRequest.originator,
                    registrar: registrar,
                    availableValue: availableValue
                });

                // Ensure to deduct the ETH that was forwarded to the resolver during the processing of this batch.
                availableValue -= res.usedValue;

                // Collect UIDs (and merge them later).
                totalUIDs[i] = res.uids;
                totalUIDCount += res.uids.length;
            }
        }

        if (availableValue != 0) {
            _refund(availableValue);
        }

        // Merge all the collected UIDs and return them as a flatten array.
        return _mergeUIDs(totalUIDs, totalUIDCount);
    }

    /// @inheritdoc IAttestationRegistry
    function revoke(uint256 revoker, RevocationRequest calldata request) external payable override {
        RevocationRequestData[] memory data = new RevocationRequestData[](1);
        data[0] = request.data;
        uint256 registrar = canRevoke(revoker);

        _revoke({
            schemaUID: request.schema,
            data: data,
            revoker: revoker,
            registrar: registrar,
            availableValue: msg.value
        });
    }

    /// @inheritdoc IAttestationRegistry
    function revokeByDelegation(DelegatedRevocationRequest calldata delegatedRequest) external payable override {
        _verifyRevokeSig(delegatedRequest);

        RevocationRequestData[] memory data = new RevocationRequestData[](1);
        data[0] = delegatedRequest.data;

        uint256 registrar = ID_REGISTRY.idOf(msg.sender);
        _revoke({
            schemaUID: delegatedRequest.schema,
            data: data,
            revoker: delegatedRequest.revoker,
            registrar: registrar,
            availableValue: msg.value
        });
    }

    /// @inheritdoc IAttestationRegistry
    function multiRevoke(uint256 revoker, MultiRevocationRequest[] calldata multiRequests) external payable override {
        // We are keeping track of the total available ETH amount that can be sent to resolvers and will keep deducting
        // from it to verify that there isn't any attempt to send too much ETH to resolvers. Please note that unless
        // some ETH was stuck in the contract by accident (which shouldn't happen in normal conditions), it won't be
        // possible to send too much ETH anyway.
        uint256 availableValue = msg.value;
        uint256 registrar = canRevoke(revoker);

        uint256 length = multiRequests.length;
        unchecked {
            for (uint256 i = 0; i < length; i++) {
                MultiRevocationRequest calldata multiRequest = multiRequests[i];

                // Ensure to deduct the ETH that was forwarded to the resolver during the processing of this batch.
                availableValue -= _revoke({
                    schemaUID: multiRequest.schema,
                    data: multiRequest.data,
                    revoker: revoker,
                    registrar: registrar,
                    availableValue: availableValue
                });
            }
        }

        if (availableValue != 0) {
            _refund(availableValue);
        }
    }

    /// @inheritdoc IAttestationRegistry
    function multiRevokeByDelegation(MultiDelegatedRevocationRequest[] calldata multiDelegatedRequests)
        external
        payable
        override
    {
        // We are keeping track of the total available ETH amount that can be sent to resolvers and will keep deducting
        // from it to verify that there isn't any attempt to send too much ETH to resolvers. Please note that unless
        // some ETH was stuck in the contract by accident (which shouldn't happen in normal conditions), it won't be
        // possible to send too much ETH anyway.
        uint256 availableValue = msg.value;

        uint256 length = multiDelegatedRequests.length;
        uint256 registrar = ID_REGISTRY.idOf(msg.sender);
        unchecked {
            for (uint256 i = 0; i < length; i++) {
                MultiDelegatedRevocationRequest memory multiDelegatedRequest = multiDelegatedRequests[i];
                RevocationRequestData[] memory data = multiDelegatedRequest.data;

                // Ensure that no inputs are missing.
                uint256 dataLength = data.length;
                if (dataLength == 0 || dataLength != multiDelegatedRequest.signatures.length) {
                    revert InvalidLength();
                }

                // Verify signatures. Please note that the signatures are assumed to be signed with increasing nonces.
                for (uint256 j = 0; j < dataLength; j++) {
                    _verifyRevokeSig(
                        DelegatedRevocationRequest({
                            schema: multiDelegatedRequest.schema,
                            data: data[j],
                            signature: multiDelegatedRequest.signatures[j],
                            revoker: multiDelegatedRequest.revoker,
                            deadline: multiDelegatedRequest.deadline
                        })
                    );
                }

                // Ensure to deduct the ETH that was forwarded to the resolver during the processing of this batch.
                availableValue -= _revoke({
                    schemaUID: multiDelegatedRequest.schema,
                    data: data,
                    revoker: multiDelegatedRequest.revoker,
                    registrar: registrar,
                    availableValue: availableValue
                });
            }
        }

        if (availableValue != 0) {
            _refund(availableValue);
        }
    }

    /// @inheritdoc IAttestationRegistry
    function timestamp(bytes32 data) external override returns (uint64 time) {
        time = uint64(block.timestamp);
        _timestamp(data, time);
    }

    /// @inheritdoc IAttestationRegistry
    function revokeOffchain(uint256 revoker, bytes32 data) external override returns (uint64) {
        uint64 time = uint64(block.timestamp);
        uint256 registrar = canRevoke(revoker);

        _revokeOffchain(revoker, registrar, data, time);

        return time;
    }

    /// @inheritdoc IAttestationRegistry
    function multiRevokeOffchain(uint256 revoker, bytes32[] calldata data) external override returns (uint64) {
        uint64 time = uint64(block.timestamp);
        uint256 registrar = canRevoke(revoker);

        uint256 length = data.length;
        unchecked {
            for (uint256 i = 0; i < length; i++) {
                _revokeOffchain(revoker, registrar, data[i], time);
            }
        }

        return time;
    }

    /// @inheritdoc IAttestationRegistry
    function canAttest(uint256 originator) public view override returns (uint256 registrar) {
        registrar = ID_REGISTRY.idOf(msg.sender);
        bool canAct = ID_REGISTRY.canAct(originator, registrar, address(this), "attest");

        if (!canAct) {
            revert AccessDenied();
        }
    }

    /// @inheritdoc IAttestationRegistry
    function canRevoke(uint256 revoker) public view override returns (uint256 registrar) {
        registrar = ID_REGISTRY.idOf(msg.sender);
        bool canAct = ID_REGISTRY.canAct(revoker, registrar, address(this), "revoke");

        if (!canAct) {
            revert AccessDenied();
        }
    }

    /// @inheritdoc IAttestationRegistry
    function multiTimestamp(bytes32[] calldata data) external override returns (uint64 time) {
        time = uint64(block.timestamp);

        uint256 length = data.length;
        unchecked {
            for (uint256 i = 0; i < length; i++) {
                _timestamp(data[i], time);
            }
        }
    }

    /// @inheritdoc IAttestationRegistry
    function getAttestation(bytes32 uid) external view override returns (Attestation memory) {
        return _db[uid];
    }

    /// @inheritdoc IAttestationRegistry
    function isAttestationValid(bytes32 uid) public view override returns (bool) {
        return _db[uid].uid != EMPTY_UID;
    }

    /// @inheritdoc IAttestationRegistry
    function getTimestamp(bytes32 data) external view override returns (uint64 time) {
        return _timestamps[data];
    }

    /// @inheritdoc IAttestationRegistry
    function getRevokeOffchain(uint256 revoker, bytes32 data)
        external
        view
        override
        returns (uint64 revocationTimestamp)
    {
        return _revocationsOffchain[revoker][data];
    }

    /// @dev Attests to a specific schema.
    /// @param schemaUID The unique identifier of the schema to attest to.
    /// @param data The arguments of the attestation requests.
    /// @param originator The attesting account.
    /// @param registrar The registrar account.
    /// @param availableValue The total available ETH amount that can be sent to the resolver.
    /// @return The UID of the new attestations and the total sent ETH amount.
    function _attest(
        bytes32 schemaUID,
        AttestationRequestData[] memory data,
        uint256 originator,
        uint256 registrar,
        uint256 availableValue
    ) private returns (AttestationsResult memory) {
        uint256 length = data.length;

        AttestationsResult memory res;
        res.uids = new bytes32[](length);

        // Ensure that we aren't attempting to attest to a non-existing schema.
        SchemaRecord memory schemaRecord = SCHEMA_REGISTRY.getSchema(schemaUID);
        if (schemaRecord.uid == EMPTY_UID) {
            revert InvalidSchema();
        }

        Attestation[] memory attestations = new Attestation[](length);
        uint256[] memory values = new uint256[](length);

        unchecked {
            for (uint256 i = 0; i < length; i++) {
                AttestationRequestData memory request = data[i];

                // Ensure that either no expiration time was set or that it was set in the future.
                uint64 time = uint64(block.timestamp);
                if (request.expirationTime != NO_EXPIRATION_TIME && request.expirationTime <= time) {
                    revert InvalidExpirationTime();
                }

                // Ensure that we aren't trying to make a revocable attestation for a non-revocable schema.
                if (!schemaRecord.revocable && request.revocable) {
                    revert Irrevocable();
                }

                Attestation memory attestation = Attestation({
                    uid: EMPTY_UID,
                    schema: schemaUID,
                    time: uint64(block.timestamp),
                    expirationTime: request.expirationTime,
                    revocationTime: 0,
                    originator: originator,
                    registrar: registrar,
                    revocable: request.revocable,
                    data: request.data
                });

                bytes32 uid = _getUID(attestation);
                if (_db[uid].uid != EMPTY_UID) {
                    revert AlreadyAttested();
                }

                attestation.uid = uid;
                _db[uid] = attestation;

                attestations[i] = attestation;
                values[i] = request.value;

                res.uids[i] = uid;

                emit Attested(originator, registrar, uid, schemaUID);
            }
        }

        res.usedValue = _resolveAttestations({
            schemaRecord: schemaRecord,
            attestations: attestations,
            values: values,
            isRevocation: false,
            availableValue: availableValue
        });

        return res;
    }

    /// @dev Revokes an existing attestation to a specific schema.
    /// @param schemaUID The unique identifier of the schema to attest to.
    /// @param data The arguments of the revocation requests.
    /// @param revoker The revoking account.
    /// @param availableValue The total available ETH amount that can be sent to the resolver.
    /// @return usedValue Returns the total sent ETH amount.
    function _revoke(
        bytes32 schemaUID,
        RevocationRequestData[] memory data,
        uint256 revoker,
        uint256 registrar,
        uint256 availableValue
    ) private returns (uint256 usedValue) {
        // Ensure that a non-existing schema ID wasn't passed by accident.
        SchemaRecord memory schemaRecord = SCHEMA_REGISTRY.getSchema(schemaUID);
        if (schemaRecord.uid == EMPTY_UID) {
            revert InvalidSchema();
        }

        uint256 length = data.length;
        Attestation[] memory attestations = new Attestation[](length);
        uint256[] memory values = new uint256[](length);

        unchecked {
            for (uint256 i = 0; i < length; i++) {
                RevocationRequestData memory request = data[i];
                Attestation storage attestation = _db[request.uid];

                // Ensure that we aren't attempting to revoke a non-existing attestation.
                if (attestation.uid == EMPTY_UID) {
                    revert NotFound();
                }

                // Ensure that a wrong schema ID wasn't passed by accident.
                if (attestation.schema != schemaUID) {
                    revert InvalidSchema();
                }

                // Allow only original attesters to revoke their attestations.
                if (attestation.originator != revoker) {
                    revert AccessDenied();
                }

                // Please note that also checking of the schema itself is revocable is unnecessary, since it's not possible to
                // make revocable attestations to an irrevocable schema.
                if (!attestation.revocable) {
                    revert Irrevocable();
                }

                // Ensure that we aren't trying to revoke the same attestation twice.
                if (attestation.revocationTime != 0) {
                    revert AlreadyRevoked();
                }

                // Actually revoke the attestation
                attestation.revocationTime = uint64(block.timestamp);
                attestations[i] = attestation;
                values[i] = request.value;
                emit Revoked(revoker, registrar, request.uid, schemaUID);
            }
        }

        return _resolveAttestations({
            schemaRecord: schemaRecord,
            attestations: attestations,
            values: values,
            isRevocation: true,
            availableValue: availableValue
        });
    }

    /// @dev Resolves a new attestation or a revocation of an existing attestation.
    /// @param schemaRecord The schema of the attestation.
    /// @param attestation The data of the attestation to make/revoke.
    /// @param value An explicit ETH amount to send to the resolver.
    /// @param isRevocation Whether to resolve an attestation or its revocation.
    /// @param availableValue The total available ETH amount that can be sent to the resolver.
    /// @return Returns the total sent ETH amount.
    function _resolveAttestation(
        SchemaRecord memory schemaRecord,
        Attestation memory attestation,
        uint256 value,
        bool isRevocation,
        uint256 availableValue
    ) private returns (uint256) {
        ISchemaResolver resolver = schemaRecord.resolver;
        if (address(resolver) == address(0)) {
            // Ensure that we don't accept payments if there is no resolver.
            if (value != 0) {
                revert NotPayable();
            }

            return 0;
        }

        // Ensure that we don't accept payments which can't be forwarded to the resolver.
        if (value != 0) {
            if (!resolver.isPayable()) {
                revert NotPayable();
            }

            // Ensure that the attester/revoker doesn't try to spend more than available.
            if (value > availableValue) {
                revert InsufficientValue();
            }

            // Ensure to deduct the sent value explicitly.
            unchecked {
                availableValue -= value;
            }
        }

        if (isRevocation) {
            if (!resolver.revoke{value: value}(attestation)) {
                revert InvalidRevocation();
            }
        } else if (!resolver.attest{value: value}(attestation)) {
            revert InvalidAttestation();
        }

        return value;
    }

    /// @dev Resolves multiple attestations or revocations of existing attestations.
    /// @param schemaRecord The schema of the attestation.
    /// @param attestations The data of the attestations to make/revoke.
    /// @param values Explicit ETH amounts to send to the resolver.
    /// @param isRevocation Whether to resolve an attestation or its revocation.
    /// @param availableValue The total available ETH amount that can be sent to the resolver.
    /// @return usedValue Returns the total sent ETH amount.
    function _resolveAttestations(
        SchemaRecord memory schemaRecord,
        Attestation[] memory attestations,
        uint256[] memory values,
        bool isRevocation,
        uint256 availableValue
    ) private returns (uint256 usedValue) {
        // NOTE: No need to compare values.length, because the caller guarantees they are the same length.
        uint256 length = attestations.length;
        if (length == 1) {
            return _resolveAttestation({
                schemaRecord: schemaRecord,
                attestation: attestations[0],
                value: values[0],
                isRevocation: isRevocation,
                availableValue: availableValue
            });
        }

        ISchemaResolver resolver = schemaRecord.resolver;
        if (address(resolver) == address(0)) {
            // Ensure that we don't accept payments if there is no resolver.
            unchecked {
                for (uint256 i = 0; i < length; i++) {
                    if (values[i] != 0) {
                        revert NotPayable();
                    }
                }
            }

            return 0;
        }

        uint256 totalUsedValue = 0;
        bool isResolverPayable = resolver.isPayable();

        unchecked {
            for (uint256 i = 0; i < length; i++) {
                uint256 value = values[i];

                // Ensure that we don't accept payments which can't be forwarded to the resolver.
                if (value == 0) {
                    continue;
                }

                if (!isResolverPayable) {
                    revert NotPayable();
                }

                // Ensure that the attester/revoker doesn't try to spend more than available.
                if (value > availableValue) {
                    revert InsufficientValue();
                }

                // Ensure to deduct the sent value explicitly and add it to the total used value by the batch.
                availableValue -= value;
                totalUsedValue += value;
            }
        }

        if (isRevocation) {
            if (!resolver.multiRevoke{value: totalUsedValue}(attestations, values)) {
                revert InvalidRevocations();
            }
        } else if (!resolver.multiAttest{value: totalUsedValue}(attestations, values)) {
            revert InvalidAttestations();
        }

        return totalUsedValue;
    }

    /// @dev Calculates a UID for a given attestation.
    /// @param attestation The input attestation.
    /// @return uid Attestation UID.
    function _getUID(Attestation memory attestation) private pure returns (bytes32 uid) {
        return keccak256(
            abi.encodePacked(
                attestation.schema,
                attestation.time,
                attestation.expirationTime,
                attestation.originator,
                attestation.registrar,
                attestation.revocable,
                attestation.data
            )
        );
    }

    /// @dev Refunds remaining ETH amount to the attester.
    /// @param remainingValue The remaining ETH amount that was not sent to the resolver.
    function _refund(uint256 remainingValue) private {
        if (remainingValue > 0) {
            // Using a regular transfer here might revert, for some non-EOA attesters, due to exceeding of the 2300
            // gas limit which is why we're using call instead (via sendValue), which the 2300 gas limit does not
            // apply for.
            (bool sent,) = payable(msg.sender).call{value: remainingValue}("");
            if (!sent) revert RefundFailed();
        }
    }

    /// @dev Timestamps the specified bytes32 data.
    /// @param data The data to timestamp.
    /// @param time The timestamp.
    function _timestamp(bytes32 data, uint64 time) private {
        if (_timestamps[data] != 0) {
            revert AlreadyTimestamped();
        }

        emit Timestamped(data, time);
        _timestamps[data] = time;
    }

    /// @dev Revokes the specified bytes32 data.
    /// @param revoker The revoking account.
    /// @param data The data to revoke.
    /// @param time The timestamp the data was revoked with.
    function _revokeOffchain(uint256 revoker, uint256 registrar, bytes32 data, uint64 time) private {
        if (_revocationsOffchain[revoker][data] != 0) {
            revert AlreadyRevokedOffchain();
        }

        emit RevokedOffchain(revoker, registrar, data, time);
        _revocationsOffchain[revoker][data] = time;
    }

    /// @dev Merges lists of UIDs.
    /// @param uidLists The provided lists of UIDs.
    /// @param uidCount Total UID count.
    /// @return uids A merged and flatten list of all the UIDs.
    function _mergeUIDs(bytes32[][] memory uidLists, uint256 uidCount) private pure returns (bytes32[] memory uids) {
        uids = new bytes32[](uidCount);
        uint256 currentIndex = 0;
        uint256 uidListLength = uidLists.length;

        unchecked {
            for (uint256 i = 0; i < uidListLength; i++) {
                bytes32[] memory currentUIDs = uidLists[i];
                uint256 currentUIDsLength = currentUIDs.length;

                for (uint256 j = 0; j < currentUIDsLength; j++) {
                    uids[currentIndex] = currentUIDs[j];
                    ++currentIndex;
                }
            }
        }
    }

    // =============================================================
    //                       SIGNATURE HELPERS
    // =============================================================

    /// @dev Verify the EIP712 signature for a Attest transaction.
    function _verifyAttestSig(DelegatedAttestationRequest memory request) internal {
        uint256 originator = request.originator;
        address custody = ID_REGISTRY.custodyOf(originator);

        AttestationRequestData memory data = request.data;

        bytes32 digest = _hashTypedData(
            keccak256(
                abi.encode(
                    ATTEST_TYPEHASH,
                    originator,
                    request.schema,
                    data.expirationTime,
                    data.revocable,
                    keccak256(data.data),
                    data.value,
                    _useNonce(custody),
                    request.deadline
                )
            )
        );

        Signature memory signature = request.signature;
        _verifySigMemory(digest, custody, request.deadline, abi.encodePacked(signature.r, signature.s, signature.v));
    }

    function _verifyRevokeSig(DelegatedRevocationRequest memory request) internal {
        uint256 revoker = request.revoker;
        address custody = ID_REGISTRY.custodyOf(revoker);

        RevocationRequestData memory data = request.data;

        bytes32 digest = _hashTypedData(
            keccak256(
                abi.encode(
                    REVOKE_TYPEHASH, revoker, request.schema, data.uid, data.value, _useNonce(custody), request.deadline
                )
            )
        );

        Signature memory signature = request.signature;
        _verifySigMemory(digest, custody, request.deadline, abi.encodePacked(signature.r, signature.s, signature.v));
    }

    // =============================================================
    //                          UUPS
    // =============================================================

    // solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
