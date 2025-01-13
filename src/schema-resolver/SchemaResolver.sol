// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import {Attestation, InvalidLength, AccessDenied} from "./../Common.sol";
import {IAttestationRegistry} from "../interfaces/IAttestationRegistry.sol";
import {ISchemaResolver} from "./ISchemaResolver.sol";

// slither-disable-start locked-ether

/// @title SchemaResolver
/// @notice The base schema resolver contract.
abstract contract SchemaResolver is ISchemaResolver {
    error InsufficientValue();
    error NotPayable();
    error InvalidRegistry();

    // The global AttestationRegistry contract.
    IAttestationRegistry internal immutable _ATTESTATION_REGISTRY;

    /// @notice The version of the schema resolver.
    string public constant VERSION = "2025-01-06";

    /// @dev Ensures that only the AttestationRegistry contract can make this call.
    modifier onlyAttestationRegistry() {
        _onlyAttestationRegistry();

        _;
    }

    /// @dev Creates a new resolver.
    /// @param attestationRegistry The address of the global AttestationRegistry contract.
    constructor(IAttestationRegistry attestationRegistry) {
        if (address(attestationRegistry) == address(0)) {
            revert InvalidRegistry();
        }

        _ATTESTATION_REGISTRY = attestationRegistry;
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
    function attest(Attestation calldata attestation) external payable onlyAttestationRegistry returns (bool isValid) {
        return _onAttest(attestation, msg.value);
    }

    /// @inheritdoc ISchemaResolver
    function multiAttest(Attestation[] calldata attestations, uint256[] calldata values)
        external
        payable
        onlyAttestationRegistry
        returns (bool isValid)
    {
        uint256 length = attestations.length;
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
                // Ensure that the attester/revoker doesn't try to spend more than available.
                uint256 value = values[i];
                if (value > remainingValue) {
                    revert InsufficientValue();
                }

                // Forward the attestation to the underlying resolver and return false in case it isn't approved.
                if (!_onAttest(attestations[i], value)) {
                    return false;
                }

                // Subtract the ETH amount, that was provided to this attestation, from the global remaining ETH amount.
                remainingValue -= value;
            }
        }

        return true;
    }

    /// @inheritdoc ISchemaResolver
    function revoke(Attestation calldata attestation)
        external
        payable
        onlyAttestationRegistry
        returns (bool isRevocable)
    {
        return _onRevoke(attestation, msg.value);
    }

    /// @inheritdoc ISchemaResolver
    function multiRevoke(Attestation[] calldata attestations, uint256[] calldata values)
        external
        payable
        onlyAttestationRegistry
        returns (bool isRevocable)
    {
        uint256 length = attestations.length;
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
                // Ensure that the attester/revoker doesn't try to spend more than available.
                uint256 value = values[i];
                if (value > remainingValue) {
                    revert InsufficientValue();
                }

                // Forward the revocation to the underlying resolver and return false in case it isn't approved.
                if (!_onRevoke(attestations[i], value)) {
                    return false;
                }

                // Subtract the ETH amount, that was provided to this attestation, from the global remaining ETH amount.
                remainingValue -= value;
            }
        }

        return true;
    }

    /// @notice A resolver callback that should be implemented by child contracts.
    /// @param attestation The new attestation.
    /// @param value An explicit ETH amount that was sent to the resolver. Please note that this value is verified in
    ///     both attest() and multiAttest() callbacks AttestationRegistry-only callbacks and that in case of multi attestations, it'll
    ///     usually hold that msg.value != value, since msg.value aggregated the sent ETH amounts for all the
    ///     attestations in the batch.
    /// @return isValid Whether the attestation is valid.
    function _onAttest(Attestation calldata attestation, uint256 value) internal virtual returns (bool isValid);

    /// @notice Processes an attestation revocation and verifies if it can be revoked.
    /// @param attestation The existing attestation to be revoked.
    /// @param value An explicit ETH amount that was sent to the resolver. Please note that this value is verified in
    ///     both revoke() and multiRevoke() callbacks AttestationRegistry-only callbacks and that in case of multi attestations, it'll
    ///     usually hold that msg.value != value, since msg.value aggregated the sent ETH amounts for all the
    ///     attestations in the batch.
    /// @return isRevocable Whether the attestation can be revoked.
    function _onRevoke(Attestation calldata attestation, uint256 value) internal virtual returns (bool isRevocable);

    /// @dev Ensures that only the AttestationRegistry contract can make this call.
    function _onlyAttestationRegistry() private view {
        if (msg.sender != address(_ATTESTATION_REGISTRY)) {
            revert AccessDenied();
        }
    }
}

// slither-disable-end locked-ether
