// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ISchemaResolver} from "./schema-resolver/ISchemaResolver.sol";

import {AccessDenied, NotFound, Signature, EMPTY_UID, InvalidLength, NotFound} from "./Common.sol";

import {Withdrawable} from "./abstract/Withdrawable.sol";
import {Signatures} from "./abstract/Signatures.sol";
import {EIP712} from "./abstract/EIP712.sol";
import {Nonces} from "./abstract/Nonces.sol";
import {Initializable} from "solady/utils/Initializable.sol";
import {UUPSUpgradeable} from "solady/utils/UUPSUpgradeable.sol";

import {
    Record,
    RecordRequest,
    RecordRequestData,
    DelegatedRecordRequest,
    DelegatedRevocationRequest,
    IRecordRegistry,
    MultiRecordRequest,
    MultiDelegatedRecordRequest,
    MultiDelegatedRevocationRequest,
    MultiRevocationRequest,
    RevocationRequest,
    RevocationRequestData
} from "./interfaces/IRecordRegistry.sol";

import {ISchemaRegistry, Schema} from "./interfaces/ISchemaRegistry.sol";
import {IIdRegistry} from "./interfaces/IIdRegistry.sol";

// TODO: Add a way to reverse a revocation
/// @title RecordRegistry
/// @notice The RecordRegistry for protocol SchemaData.
contract RecordRegistry is IRecordRegistry, Withdrawable, Signatures, EIP712, Nonces, Initializable, UUPSUpgradeable {
    error AlreadyRevoked();
    error AlreadyRevokedOffchain();
    error AlreadyTimestamped();
    error AlreadyRegistered();
    error InsufficientValue();
    error InvalidAccount();
    error InvalidRecord();
    error InvalidRecords();
    error InvalidRegistry();
    error InvalidRevocation();
    error InvalidRevocations();
    error InvalidSchema();
    error Irrevocable();
    error Nonupdatable();
    error NotPayable();
    error RefundFailed();

    /// @notice A struct representing an internal record result.
    struct RecordsResult {
        uint256 usedValue; // Total ETH amount that was sent to resolvers.
        bytes32[] uids; // UIDs of the new records.
    }

    // =============================================================
    //                           CONSTANTS
    // =============================================================

    /* solhint-disable gas-small-strings */

    /// @inheritdoc IRecordRegistry
    string public constant VERSION = "2025-02-04";

    /// @inheritdoc IRecordRegistry
    bytes32 public constant REGISTER_TYPEHASH = keccak256(
        "Register(uint256 originator,bytes32 schema,bool revocable,bool updatable,bytes data,uint256 value,uint256 nonce,uint256 deadline)"
    );

    /// @inheritdoc IRecordRegistry
    bytes32 public constant REVOKE_TYPEHASH =
        keccak256("Revoke(uint256 revoker,bytes32 schema,bytes32 uid,uint256 value,uint256 nonce,uint256 deadline)");

    /* solhint-enable gas-small-strings */

    // The global schema registry.
    ISchemaRegistry public schemaRegistry;

    // The global IdRegistry.
    IIdRegistry public idRegistry;

    // The global mapping between records and their UIDs.
    mapping(bytes32 uid => Record record) internal _db;

    // The global mapping between data and their timestamps.
    mapping(bytes32 data => uint64 timestamp) internal _timestamps;

    // The global mapping between data and their revocation timestamps.
    mapping(uint256 revoker => mapping(bytes32 data => uint64 timestamp) timestamps) internal _revocationsOffchain;

    // =============================================================
    //                    CONSTRUCTOR / INITIALIZATION
    // =============================================================

    constructor() {
        _disableInitializers();
    }

    /// @inheritdoc IRecordRegistry
    function initialize(ISchemaRegistry schemaRegistry_, IIdRegistry idRegistry_, address initialOwner_)
        external
        override
        initializer
    {
        schemaRegistry = schemaRegistry_;
        idRegistry = idRegistry_;
        _initializeOwner(initialOwner_);
    }

    // =============================================================
    //                          EIP712
    // =============================================================

    /// @dev Configure the EIP712 name and version for the domain separator.
    function _domainNameAndVersion() internal pure override returns (string memory name, string memory version) {
        // solhint-disable-next-line gas-small-strings
        name = "RoyalProtocol_RecordRegistry";
        version = "1";
    }

    /// @inheritdoc IRecordRegistry
    function register(uint256 originator, RecordRequest calldata request)
        external
        payable
        override
        returns (bytes32 uid)
    {
        uint256 registrar = canRegister(originator);

        RecordRequestData[] memory data = new RecordRequestData[](1);
        data[0] = request.data;

        return _register({
            schemaUID: request.schema,
            data: data,
            originator: originator,
            registrar: registrar,
            availableValue: msg.value
        }).uids[0];
    }

    /// @inheritdoc IRecordRegistry
    function registerByDelegation(DelegatedRecordRequest calldata delegatedRequest)
        external
        payable
        override
        returns (bytes32 uid)
    {
        _verifyRegisterSig(delegatedRequest);
        uint256 registrar = idRegistry.idOf(msg.sender);

        RecordRequestData[] memory data = new RecordRequestData[](1);
        data[0] = delegatedRequest.data;

        return _register({
            schemaUID: delegatedRequest.schema,
            data: data,
            originator: delegatedRequest.originator,
            registrar: registrar,
            availableValue: msg.value
        }).uids[0];
    }

    /// @inheritdoc IRecordRegistry
    function multiRegister(uint256 originator, MultiRecordRequest[] calldata multiRequests)
        external
        payable
        override
        returns (bytes32[] memory)
    {
        // Since a multi-register call is going to make multiple records for multiple schemas, we'd need to collect
        // all the returned UIDs into a single list.
        uint256 length = multiRequests.length;
        bytes32[][] memory totalUIDs = new bytes32[][](length);
        uint256 totalUIDCount = 0;

        // We are keeping track of the total available ETH amount that can be sent to resolvers and will keep deducting
        // from it to verify that there isn't any attempt to send too much ETH to resolvers. Please note that unless
        // some ETH was stuck in the contract by accident (which shouldn't happen in normal conditions), it won't be
        // possible to send too much ETH anyway.
        uint256 availableValue = msg.value;
        uint256 registrar = canRegister(originator);

        unchecked {
            for (uint256 i = 0; i < length; i++) {
                // Process the current batch of records.
                MultiRecordRequest calldata multiRequest = multiRequests[i];

                // Ensure that data isn't empty.
                if (multiRequest.data.length == 0) {
                    revert InvalidLength();
                }

                RecordsResult memory res = _register({
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

    /// @inheritdoc IRecordRegistry
    function multiRegisterByDelegation(MultiDelegatedRecordRequest[] calldata multiDelegatedRequests)
        external
        payable
        override
        returns (bytes32[] memory)
    {
        // Since a multi-register call is going to make multiple records for multiple schemas, we'd need to collect
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
                MultiDelegatedRecordRequest calldata multiDelegatedRequest = multiDelegatedRequests[i];
                RecordRequestData[] calldata data = multiDelegatedRequest.data;

                // Ensure that no inputs are missing.
                uint256 dataLength = data.length;
                if (dataLength == 0 || dataLength != multiDelegatedRequest.signatures.length) {
                    revert InvalidLength();
                }

                // Verify signatures. Please note that the signatures are assumed to be signed with increasing nonces.
                for (uint256 j = 0; j < dataLength; j++) {
                    _verifyRegisterSig(
                        DelegatedRecordRequest({
                            schema: multiDelegatedRequest.schema,
                            data: data[j],
                            signature: multiDelegatedRequest.signatures[j],
                            originator: multiDelegatedRequest.originator,
                            deadline: multiDelegatedRequest.deadline
                        })
                    );
                }

                // Process the current batch of records.
                uint256 registrar = idRegistry.idOf(msg.sender);
                RecordsResult memory res = _register({
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

    //  TODO:
    // update()?
    // updateByDelegation()?
    // multiUpdate()?
    // multiUpdateByDelegation()?

    // TODO: unrevoke()?
    // unrevokeByDelegation()?
    // multiUnrevoke()?
    // multiUnrevokeByDelegation()?
    /// @inheritdoc IRecordRegistry
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

    /// @inheritdoc IRecordRegistry
    function revokeByDelegation(DelegatedRevocationRequest calldata delegatedRequest) external payable override {
        _verifyRevokeSig(delegatedRequest);

        RevocationRequestData[] memory data = new RevocationRequestData[](1);
        data[0] = delegatedRequest.data;

        uint256 registrar = idRegistry.idOf(msg.sender);
        _revoke({
            schemaUID: delegatedRequest.schema,
            data: data,
            revoker: delegatedRequest.revoker,
            registrar: registrar,
            availableValue: msg.value
        });
    }

    /// @inheritdoc IRecordRegistry
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

    /// @inheritdoc IRecordRegistry
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
        uint256 registrar = idRegistry.idOf(msg.sender);
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

    /// @inheritdoc IRecordRegistry
    function timestamp(bytes32 data) external override returns (uint64 time) {
        time = uint64(block.timestamp);
        _timestamp(data, time);
    }

    /// @inheritdoc IRecordRegistry
    function revokeOffchain(uint256 revoker, bytes32 data) external override returns (uint64) {
        uint64 time = uint64(block.timestamp);
        uint256 registrar = canRevoke(revoker);

        _revokeOffchain(revoker, registrar, data, time);

        return time;
    }

    /// @inheritdoc IRecordRegistry
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

    /// @inheritdoc IRecordRegistry
    function canRegister(uint256 originator) public view override returns (uint256 registrar) {
        registrar = idRegistry.idOf(msg.sender);
        bool canAct = idRegistry.canAct(originator, registrar, address(this), "register");

        if (!canAct) {
            revert AccessDenied();
        }
    }

    /// @inheritdoc IRecordRegistry
    function canRevoke(uint256 revoker) public view override returns (uint256 registrar) {
        registrar = idRegistry.idOf(msg.sender);
        bool canAct = idRegistry.canAct(revoker, registrar, address(this), "revoke");

        if (!canAct) {
            revert AccessDenied();
        }
    }

    /// @inheritdoc IRecordRegistry
    function multiTimestamp(bytes32[] calldata data) external override returns (uint64 time) {
        time = uint64(block.timestamp);

        uint256 length = data.length;
        unchecked {
            for (uint256 i = 0; i < length; i++) {
                _timestamp(data[i], time);
            }
        }
    }

    /// @inheritdoc IRecordRegistry
    function getRecord(bytes32 uid) external view override returns (Record memory) {
        return _db[uid];
    }

    /// @inheritdoc IRecordRegistry
    function getRecords(bytes32[] calldata uid) external view override returns (Record[] memory records) {
        uint256 length = uid.length;
        records = new Record[](length);

        unchecked {
            for (uint256 i = 0; i < length; i++) {
                records[i] = _db[uid[i]];
            }
        }
    }

    /// @inheritdoc IRecordRegistry
    function isRecordValid(bytes32 uid) public view override returns (bool) {
        return _db[uid].uid != EMPTY_UID;
    }

    /// @inheritdoc IRecordRegistry
    function getTimestamp(bytes32 data) external view override returns (uint64 time) {
        return _timestamps[data];
    }

    /// @inheritdoc IRecordRegistry
    function getRevokeOffchain(uint256 revoker, bytes32 data)
        external
        view
        override
        returns (uint64 revocationTimestamp)
    {
        return _revocationsOffchain[revoker][data];
    }

    /// @dev Registers a new record utilizing a specific schema.
    /// @param schemaUID The unique identifier of the schema used.
    /// @param data The arguments of the record requests.
    /// @param originator The authoring account.
    /// @param registrar The registrar account.
    /// @param availableValue The total available ETH amount that can be sent to the resolver.
    /// @return The UID of the new records and the total sent ETH amount.
    function _register(
        bytes32 schemaUID,
        RecordRequestData[] memory data,
        uint256 originator,
        uint256 registrar,
        uint256 availableValue
    ) internal returns (RecordsResult memory) {
        uint256 length = data.length;

        RecordsResult memory res;
        res.uids = new bytes32[](length);

        // Ensure that we aren't attempting to register a record utilizing a non-existing schema.
        Schema memory schema = schemaRegistry.getSchema(schemaUID);
        if (schema.uid == EMPTY_UID) {
            revert InvalidSchema();
        }

        // Ensure originator and registrar are non-zero
        if (originator == 0 || registrar == 0) {
            revert InvalidAccount();
        }

        Record[] memory records = new Record[](length);
        uint256[] memory values = new uint256[](length);

        unchecked {
            for (uint256 i = 0; i < length; i++) {
                RecordRequestData memory request = data[i];

                // Ensure that we aren't trying to make a revocable record for a non-revocable schema.
                if (!schema.revocable && request.revocable) {
                    revert Irrevocable();
                }

                // Ensure we aren't trying to make an updatable record for a non-updatable schema.
                if (!schema.updatable && request.updatable) {
                    revert Nonupdatable();
                }

                Record memory record = Record({
                    uid: EMPTY_UID,
                    schema: schemaUID,
                    time: uint64(block.timestamp),
                    revocationTime: 0,
                    originator: originator,
                    registrar: registrar,
                    revocable: request.revocable,
                    updatable: request.updatable,
                    data: request.data
                });

                bytes32 uid = _getUID(record, request.salt);
                if (_db[uid].uid != EMPTY_UID) {
                    revert AlreadyRegistered();
                }

                record.uid = uid;
                _db[uid] = record;

                records[i] = record;
                values[i] = request.value;

                res.uids[i] = uid;

                emit RecordRegistered(schemaUID, originator, registrar, uid);
            }
        }

        res.usedValue = _resolveRecords({
            schema: schema,
            records: records,
            values: values,
            isRevocation: false,
            availableValue: availableValue
        });

        return res;
    }

    /// @dev Revokes an existing record(s) utilizing a specific schema.
    /// @param schemaUID The unique identifier of the schema utilized.
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
    ) internal returns (uint256 usedValue) {
        // Ensure that a non-existing schema ID wasn't passed by accident.
        Schema memory schema = schemaRegistry.getSchema(schemaUID);
        if (schema.uid == EMPTY_UID) {
            revert InvalidSchema();
        }

        // Ensure revoker and registrar are non-zero
        if (revoker == 0 || registrar == 0) {
            revert InvalidAccount();
        }

        uint256 length = data.length;
        Record[] memory records = new Record[](length);
        uint256[] memory values = new uint256[](length);

        unchecked {
            for (uint256 i = 0; i < length; i++) {
                RevocationRequestData memory request = data[i];
                Record storage record = _db[request.uid];

                // Ensure that we aren't attempting to revoke a non-existing record.
                if (record.uid == EMPTY_UID) {
                    revert NotFound();
                }

                // Ensure that a wrong schema ID wasn't passed by accident.
                if (record.schema != schemaUID) {
                    revert InvalidSchema();
                }

                // Allow only the author/originator to revoke their records.
                if (record.originator != revoker) {
                    revert AccessDenied();
                }

                // Please note that also checking of the schema itself is revocable is unnecessary, since it's not possible to
                // make revocable records to an irrevocable schema.
                if (!record.revocable) {
                    revert Irrevocable();
                }

                // Ensure that we aren't trying to revoke the same record twice.
                if (record.revocationTime != 0) {
                    revert AlreadyRevoked();
                }

                // Actually revoke the record
                record.revocationTime = uint64(block.timestamp);
                records[i] = record;
                values[i] = request.value;
                emit RecordRevoked(schemaUID, revoker, registrar, request.uid);
            }
        }

        return _resolveRecords({
            schema: schema,
            records: records,
            values: values,
            isRevocation: true,
            availableValue: availableValue
        });
    }

    /// @dev Resolves a new record or a revocation of an existing record.
    /// @param schema The schema of the record.
    /// @param record The data of the record to make/revoke.
    /// @param value An explicit ETH amount to send to the resolver.
    /// @param isRevocation Whether to resolve an record or its revocation.
    /// @param availableValue The total available ETH amount that can be sent to the resolver.
    /// @return Returns the total sent ETH amount.
    function _resolveRecord(
        Schema memory schema,
        Record memory record,
        uint256 value,
        bool isRevocation,
        uint256 availableValue
    ) internal returns (uint256) {
        ISchemaResolver resolver = schema.resolver;
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

            // Ensure that the originator/revoker doesn't try to spend more than available.
            if (value > availableValue) {
                revert InsufficientValue();
            }

            // Ensure to deduct the sent value explicitly.
            unchecked {
                availableValue -= value;
            }
        }

        if (isRevocation) {
            if (!resolver.revoke{value: value}(record)) {
                revert InvalidRevocation();
            }
        } else if (!resolver.register{value: value}(record)) {
            revert InvalidRecord();
        }

        return value;
    }

    /// @dev Resolves multiple records or revocations of existing records.
    /// @param schema The schema of the record.
    /// @param records The data of the records to make/revoke.
    /// @param values Explicit ETH amounts to send to the resolver.
    /// @param isRevocation Whether to resolve an record or its revocation.
    /// @param availableValue The total available ETH amount that can be sent to the resolver.
    /// @return usedValue Returns the total sent ETH amount.
    function _resolveRecords(
        Schema memory schema,
        Record[] memory records,
        uint256[] memory values,
        bool isRevocation,
        uint256 availableValue
    ) internal returns (uint256 usedValue) {
        // NOTE: No need to compare values.length, because the caller guarantees they are the same length.
        uint256 length = records.length;
        if (length == 1) {
            return _resolveRecord({
                schema: schema,
                record: records[0],
                value: values[0],
                isRevocation: isRevocation,
                availableValue: availableValue
            });
        }

        ISchemaResolver resolver = schema.resolver;
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

                // Ensure that the originator/revoker doesn't try to spend more than available.
                if (value > availableValue) {
                    revert InsufficientValue();
                }

                // Ensure to deduct the sent value explicitly and add it to the total used value by the batch.
                availableValue -= value;
                totalUsedValue += value;
            }
        }

        if (isRevocation) {
            if (!resolver.multiRevoke{value: totalUsedValue}(records, values)) {
                revert InvalidRevocations();
            }
        } else if (!resolver.multiRegister{value: totalUsedValue}(records, values)) {
            revert InvalidRecords();
        }

        return totalUsedValue;
    }

    /// @dev Calculates a UID for a given record.
    /// @param record The input record.
    /// @return uid Record UID.
    function _getUID(Record memory record, bytes32 salt) internal pure returns (bytes32 uid) {
        return keccak256(abi.encodePacked(record.originator, record.registrar, record.schema, record.data, salt));
    }

    /// @dev Refunds remaining ETH amount to the caller.
    /// @param remainingValue The remaining ETH amount that was not sent to the resolver.
    function _refund(uint256 remainingValue) internal {
        if (remainingValue > 0) {
            // Using a regular transfer here might revert, for some non-EOA callers, due to exceeding of the 2300
            // gas limit which is why we're using call instead (via sendValue), which the 2300 gas limit does not
            // apply for.
            (bool sent,) = payable(msg.sender).call{value: remainingValue}("");
            if (!sent) revert RefundFailed();
        }
    }

    /// @dev Timestamps the specified bytes32 data.
    /// @param data The data to timestamp.
    /// @param time The timestamp.
    function _timestamp(bytes32 data, uint64 time) internal {
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
    function _revokeOffchain(uint256 revoker, uint256 registrar, bytes32 data, uint64 time) internal {
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
    function _mergeUIDs(bytes32[][] memory uidLists, uint256 uidCount) internal pure returns (bytes32[] memory uids) {
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

    /// @dev Verify the EIP712 signature for a Register transaction.
    function _verifyRegisterSig(DelegatedRecordRequest memory request) internal {
        uint256 originator = request.originator;
        address custody = idRegistry.custodyOf(originator);

        RecordRequestData memory data = request.data;

        bytes32 digest = _hashTypedData(
            keccak256(
                abi.encode(
                    REGISTER_TYPEHASH,
                    originator,
                    request.schema,
                    data.revocable,
                    data.updatable,
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
        address custody = idRegistry.custodyOf(revoker);

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
