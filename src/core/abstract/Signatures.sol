// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SignatureCheckerLib} from "solady/utils/SignatureCheckerLib.sol";
import {ISignatures} from "../interfaces/abstract/ISignatures.sol";

/**
 * @dev Helper contract to handle signatures.
 *
 * Adds logic around expiring signatures based on the associated deadline.
 */
abstract contract Signatures is ISignatures {
    // =============================================================
    //                       SIGNATURE HELPERS
    // =============================================================

    /**
     * @notice Verify a signature against a digest.
     *
     * Requirements:
     * - The signature must not be expired (block.timestamp <= deadline).
     * - The signature must be valid.
     *
     * Throws errors on invalid signatures, rather than returning a boolean.
     *
     * @param digest The digest to verify.
     * @param signer The expected signer of the digest.
     * @param deadline The deadline for the signature to be valid.
     * @param sig The signature to verify.
     */
    function _verifySig(bytes32 digest, address signer, uint256 deadline, bytes calldata sig) internal {
        if (block.timestamp > deadline) revert SignatureExpired();

        if (SignatureCheckerLib.isValidSignatureNowCalldata(signer, digest, sig)) return;
        if (SignatureCheckerLib.isValidERC6492SignatureNow(signer, digest, sig)) return;

        revert InvalidSignature();
    }
}
