// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Record} from "./../Common.sol";

/// @title ISchemaResolver
/// @notice The interface of an optional schema resolver.
interface ISchemaResolver {
    /// @notice Checks if the resolver can be sent ETH.
    /// @return Whether the resolver supports ETH transfers.
    function isPayable() external pure returns (bool);

    /// @notice Processes an record and verifies whether it's valid.
    /// @param record The new record.
    /// @return isValid Whether the record is valid.
    function register(Record calldata record) external payable returns (bool isValid);

    /// @notice Processes multiple records and verifies whether they are valid.
    /// @param records The new records.
    /// @param values Explicit ETH amounts which were sent with each record.
    /// @return isValid Whether all the records are valid.
    function multiRegister(Record[] calldata records, uint256[] calldata values)
        external
        payable
        returns (bool isValid);

    /// @notice Processes an record revocation and verifies if it can be revoked.
    /// @param record The existing record to be revoked.
    /// @return isRevocable Whether the record can be revoked.
    function revoke(Record calldata record) external payable returns (bool isRevocable);

    /// @notice Processes revocation of multiple record and verifies they can be revoked.
    /// @param records The existing records to be revoked.
    /// @param values Explicit ETH amounts which were sent with each revocation.
    /// @return isRevocable Whether the records can be revoked.
    function multiRevoke(Record[] calldata records, uint256[] calldata values)
        external
        payable
        returns (bool isRevocable);
}
