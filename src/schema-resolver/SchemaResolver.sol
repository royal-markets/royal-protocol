// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import {Record, InvalidLength, AccessDenied} from "./../Common.sol";
import {IRecordRegistry} from "../interfaces/IRecordRegistry.sol";
import {ISchemaResolver} from "./ISchemaResolver.sol";

// slither-disable-start locked-ether

/// @title SchemaResolver
/// @notice The base schema resolver contract.
///
/// @dev NOTE: This contract is fairly minimal, and so does not provide an opinion on how to withdraw funds or tokens.
///            We strongly recommend you implement this or inhherit `Withdrawable.sol` or `solady/Lifebuoy.sol` to add this functionality.
abstract contract SchemaResolver is ISchemaResolver {
    error InsufficientValue();
    error NotPayable();
    error InvalidRegistry();

    // The global RecordRegistry contract.
    IRecordRegistry internal immutable _RECORD_REGISTRY;

    /// @notice The version of the schema resolver.
    string public constant VERSION = "2025-02-04";

    /// @dev Ensures that only the RecordRegistry contract can make this call.
    modifier onlyRecordRegistry() {
        _onlyRecordRegistry();

        _;
    }

    /// @dev Creates a new resolver.
    /// @param recordRegistry The address of the global RecordRegistry contract.
    constructor(IRecordRegistry recordRegistry) {
        if (address(recordRegistry) == address(0)) {
            revert InvalidRegistry();
        }

        _RECORD_REGISTRY = recordRegistry;
    }

    /// @inheritdoc ISchemaResolver
    function isPayable() public pure virtual returns (bool) {
        return false;
    }

    /// @dev ETH callback.
    receive() external payable virtual {
        if (!isPayable()) revert NotPayable();
    }

    /// @inheritdoc ISchemaResolver
    function register(Record calldata record) external payable onlyRecordRegistry returns (bool isValid) {
        return _onRegister(record, msg.value);
    }

    /// @inheritdoc ISchemaResolver
    function multiRegister(Record[] calldata records, uint256[] calldata values)
        external
        payable
        onlyRecordRegistry
        returns (bool isValid)
    {
        uint256 length = records.length;
        if (length != values.length) {
            revert InvalidLength();
        }

        // We are keeping track of the remaining ETH amount that can be sent to resolvers and will keep deducting
        // from it to verify that there isn't any attempt to send too much ETH to resolvers. Please note that unless
        // some ETH was stuck in the contract by accident (which shouldn't happen in normal conditions), it won't be
        // possible to send too much ETH anyway.
        uint256 remainingValue = msg.value;

        unchecked {
            for (uint256 i = 0; i < length; i++) {
                // Ensure that the originator/revoker doesn't try to spend more than available.
                uint256 value = values[i];
                if (value > remainingValue) {
                    revert InsufficientValue();
                }

                // Forward the record to the underlying resolver and return false in case it isn't approved.
                if (!_onRegister(records[i], value)) {
                    return false;
                }

                // Subtract the ETH amount, that was provided to this record, from the global remaining ETH amount.
                remainingValue -= value;
            }
        }

        return true;
    }

    /// @inheritdoc ISchemaResolver
    function revoke(Record calldata record) external payable onlyRecordRegistry returns (bool isRevocable) {
        return _onRevoke(record, msg.value);
    }

    /// @inheritdoc ISchemaResolver
    function multiRevoke(Record[] calldata records, uint256[] calldata values)
        external
        payable
        onlyRecordRegistry
        returns (bool isRevocable)
    {
        uint256 length = records.length;
        if (length != values.length) {
            revert InvalidLength();
        }

        // We are keeping track of the remaining ETH amount that can be sent to resolvers and will keep deducting
        // from it to verify that there isn't any attempt to send too much ETH to resolvers. Please note that unless
        // some ETH was stuck in the contract by accident (which shouldn't happen in normal conditions), it won't be
        // possible to send too much ETH anyway.
        uint256 remainingValue = msg.value;

        unchecked {
            for (uint256 i = 0; i < length; i++) {
                // Ensure that the originator/revoker doesn't try to spend more than available.
                uint256 value = values[i];
                if (value > remainingValue) {
                    revert InsufficientValue();
                }

                // Forward the revocation to the underlying resolver and return false in case it isn't approved.
                if (!_onRevoke(records[i], value)) {
                    return false;
                }

                // Subtract the ETH amount, that was provided to this record, from the global remaining ETH amount.
                remainingValue -= value;
            }
        }

        return true;
    }

    /// @notice A resolver callback that should be implemented by child contracts.
    /// @param record The new record.
    /// @param value An explicit ETH amount that was sent to the resolver. Please note that this value is verified in
    ///     both register() and multiRegister() callbacks RecordRegistry-only callbacks and that in case of multi records, it'll
    ///     usually hold that msg.value != value, since msg.value aggregated the sent ETH amounts for all the
    ///     records in the batch.
    /// @return isValid Whether the record is valid.
    function _onRegister(Record calldata record, uint256 value) internal virtual returns (bool isValid);

    /// @notice Processes an record revocation and verifies if it can be revoked.
    /// @param record The existing record to be revoked.
    /// @param value An explicit ETH amount that was sent to the resolver. Please note that this value is verified in
    ///     both revoke() and multiRevoke() callbacks RecordRegistry-only callbacks and that in case of multi records, it'll
    ///     usually hold that msg.value != value, since msg.value aggregated the sent ETH amounts for all the
    ///     records in the batch.
    /// @return isRevocable Whether the record can be revoked.
    function _onRevoke(Record calldata record, uint256 value) internal virtual returns (bool isRevocable);

    /// @dev Ensures that only the RecordRegistry contract can make this call.
    function _onlyRecordRegistry() private view {
        if (msg.sender != address(_RECORD_REGISTRY)) {
            revert AccessDenied();
        }
    }
}

// slither-disable-end locked-ether
