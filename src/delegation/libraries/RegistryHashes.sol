// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.0;

import {IDelegateRegistry} from "../IDelegateRegistry.sol";

/**
 * @title Library for calculating the hashes and storage locations used in the delegate registry
 *
 * The encoding for the 5 types of delegate registry hashes should be as follows:
 *
 * ALL:         keccak256(abi.encodePacked(rights, fromId, toId))
 * CONTRACT:    keccak256(abi.encodePacked(rights, fromId, toId, contract_))
 * ERC721:      keccak256(abi.encodePacked(rights, fromId, toId, contract_, tokenId))
 * ERC20:       keccak256(abi.encodePacked(rights, fromId, toId, contract_))
 * ERC1155:     keccak256(abi.encodePacked(rights, fromId, toId, contract_, tokenId))
 *
 * To avoid collisions between the hashes with respect to type, the hash is shifted left by one byte
 * and the last byte is then encoded with a unique number for the delegation type
 *
 */
library RegistryHashes {
    /// @dev Used to delete everything but the last byte of a 32 byte word with and(word, EXTRACT_LAST_BYTE)
    uint256 internal constant EXTRACT_LAST_BYTE = 0xff;
    /// @dev Constants for the delegate registry delegation type enumeration
    uint256 internal constant ALL_TYPE = 1;
    uint256 internal constant CONTRACT_TYPE = 2;
    uint256 internal constant ERC721_TYPE = 3;
    uint256 internal constant ERC20_TYPE = 4;
    uint256 internal constant ERC1155_TYPE = 5;
    /// @dev Constant for the location of the delegations array in the delegate registry, defined to be zero
    uint256 internal constant DELEGATION_SLOT = 0;

    /**
     * @notice Helper function to decode last byte of a delegation hash into its delegation type enum
     * @param inputHash The bytehash to decode the type from
     * @return decodedType The delegation type
     */
    function decodeType(bytes32 inputHash) internal pure returns (IDelegateRegistry.DelegationType decodedType) {
        assembly {
            decodedType := and(inputHash, EXTRACT_LAST_BYTE)
        }
    }

    /**
     * @notice Helper function that computes the storage location of a particular delegation array
     * @dev Storage keys further down the array can be obtained by adding computedLocation with the element position
     * @dev Follows the solidity storage location encoding for a mapping(bytes32 => fixedArray) at the position of the delegationSlot
     * @param inputHash The bytehash to decode the type from
     * @return computedLocation is the storage key of the delegation array at position 0
     */
    function location(bytes32 inputHash) internal pure returns (bytes32 computedLocation) {
        assembly ("memory-safe") {
            // This block only allocates memory in the scratch space
            mstore(0, inputHash)
            mstore(32, DELEGATION_SLOT)
            computedLocation := keccak256(0, 64) // Run keccak256 over bytes in scratch space to obtain the storage key
        }
    }

    /**
     * @notice Helper function to compute delegation hash for `DelegationType.ALL`
     * @dev Equivalent to `keccak256(abi.encodePacked(rights, fromId, toId))` then left-shift by 1 byte and write the delegation type to the cleaned last byte
     * @param fromId The account ID making the delegation
     * @param rights The rights specified by the delegation
     * @param toId The account ID receiving the delegation
     * @return hash The delegation parameters encoded with ALL_TYPE
     */
    function allHash(uint256 fromId, bytes32 rights, uint256 toId) internal pure returns (bytes32 hash) {
        assembly ("memory-safe") {
            // This block only allocates memory after the free memory pointer
            let ptr := mload(64) // Load the free memory pointer

            // Lay out the variables from last to first, agnostic to upper 96 bits of address words.
            mstore(add(ptr, 64), toId)
            mstore(add(ptr, 32), fromId)
            mstore(ptr, rights)
            hash := or(shl(8, keccak256(ptr, 96)), ALL_TYPE) // Keccak-hashes the packed encoding, left-shifts by one byte, then writes type to the lowest-order byte
        }
    }

    /**
     * @notice Helper function to compute delegation location for `DelegationType.ALL`
     * @dev Equivalent to `location(allHash(rights, fromId, toId))`
     * @param fromId The account ID making the delegation
     * @param rights The rights specified by the delegation
     * @param toId The account ID receiving the delegation
     * @return computedLocation The storage location of the all delegation with those parameters in the delegations mapping
     */
    function allLocation(uint256 fromId, bytes32 rights, uint256 toId)
        internal
        pure
        returns (bytes32 computedLocation)
    {
        assembly ("memory-safe") {
            // This block only allocates memory after the free memory pointer and in the scratch space
            let ptr := mload(64) // Load the free memory pointer

            // Lay out the variables from last to first, agnostic to upper 96 bits of address words.
            mstore(add(ptr, 64), toId)
            mstore(add(ptr, 32), fromId)
            mstore(ptr, rights)
            mstore(0, or(shl(8, keccak256(ptr, 96)), ALL_TYPE)) // Computes `allHash`, then stores the result in scratch space
            mstore(32, DELEGATION_SLOT)
            computedLocation := keccak256(0, 64) // Runs keccak over the scratch space to obtain the storage key
        }
    }

    /**
     * @notice Helper function to compute delegation hash for `DelegationType.CONTRACT`
     * @dev Equivalent to keccak256(abi.encodePacked(rights, fromId, toId, contract_)) left-shifted by 1 then last byte overwritten with CONTRACT_TYPE
     * @param fromId The account ID making the delegation
     * @param rights The rights specified by the delegation
     * @param toId The account ID receiving the delegation
     * @param contract_ The address of the contract specified by the delegation
     * @return hash The delegation parameters encoded with CONTRACT_TYPE
     */
    function contractHash(uint256 fromId, bytes32 rights, uint256 toId, address contract_)
        internal
        pure
        returns (bytes32 hash)
    {
        assembly ("memory-safe") {
            // This block only allocates memory after the free memory pointer
            let ptr := mload(64) // Load the free memory pointer
            // Lay out the variables from last to first, agnostic to upper 96 bits of address words.
            mstore(add(ptr, 84), contract_)
            mstore(add(ptr, 64), toId)
            mstore(add(ptr, 32), fromId)
            mstore(ptr, rights)
            hash := or(shl(8, keccak256(ptr, 116)), CONTRACT_TYPE) // Keccak-hashes the packed encoding, left-shifts by one byte, then writes type to the lowest-order byte
        }
    }

    /**
     * @notice Helper function to compute delegation location for `DelegationType.CONTRACT`
     * @dev Equivalent to `location(contractHash(rights, fromId, toId, contract_))`
     * @param fromId The account ID making the delegation
     * @param rights The rights specified by the delegation
     * @param toId The account ID receiving the delegation
     * @param contract_ The address of the contract specified by the delegation
     * @return computedLocation The storage location of the contract delegation with those parameters in the delegations mapping
     */
    function contractLocation(uint256 fromId, bytes32 rights, uint256 toId, address contract_)
        internal
        pure
        returns (bytes32 computedLocation)
    {
        assembly ("memory-safe") {
            // This block only allocates memory after the free memory pointer and in the scratch space
            let ptr := mload(64) // Load free memory pointer

            // Lay out the variables from last to first, agnostic to upper 96 bits of address words.
            mstore(add(ptr, 84), contract_)
            mstore(add(ptr, 64), toId)
            mstore(add(ptr, 32), fromId)
            mstore(ptr, rights)
            mstore(0, or(shl(8, keccak256(ptr, 116)), CONTRACT_TYPE)) // Computes `contractHash`, then stores the result in scratch space
            mstore(32, DELEGATION_SLOT)
            computedLocation := keccak256(0, 64) // Runs keccak over the scratch space to obtain the storage key
        }
    }

    /**
     * @notice Helper function to compute delegation hash for `DelegationType.ERC721`
     * @dev Equivalent to `keccak256(abi.encodePacked(rights, fromId, toId, contract_, tokenId)) left-shifted by 1 then last byte overwritten with ERC721_TYPE
     * @dev Will not revert if `contract_` is > uint160, this input will be cleaned to its lower 20 bytes
     * @param fromId The account ID making the delegation
     * @param rights The rights specified by the delegation
     * @param toId The account ID receiving the delegation
     * @param tokenId The id of the token specified by the delegation
     * @param contract_ The address of the contract specified by the delegation
     * @return hash The delegation parameters encoded with ERC721_TYPE
     */
    function erc721Hash(uint256 fromId, bytes32 rights, uint256 toId, uint256 tokenId, address contract_)
        internal
        pure
        returns (bytes32 hash)
    {
        assembly ("memory-safe") {
            // This block only allocates memory after the free memory pointer
            let ptr := mload(64) // Cache the free memory pointer.

            // Lay out the variables from last to first, agnostic to upper 96 bits of address words.
            mstore(add(ptr, 116), tokenId)
            mstore(add(ptr, 84), contract_)
            mstore(add(ptr, 64), toId)
            mstore(add(ptr, 32), fromId)
            mstore(ptr, rights)
            hash := or(shl(8, keccak256(ptr, 148)), ERC721_TYPE) // Keccak-hashes the packed encoding, left-shifts by one byte, then writes type to the lowest-order byte
        }
    }

    /**
     * @notice Helper function to compute delegation location for `DelegationType.ERC721`
     * @dev Equivalent to `location(ERC721Hash(rights, fromId, toId, contract_, tokenId))`
     * @dev Will not revert if `contract_` is > uint160, this input will be cleaned to its lower 20 bytes
     * @param fromId The account ID making the delegation
     * @param rights The rights specified by the delegation
     * @param toId The account ID receiving the delegation
     * @param tokenId The id of the ERC721 token
     * @param contract_ The address of the ERC721 token contract
     * @return computedLocation The storage location of the ERC721 delegation with those parameters in the delegations mapping
     */
    function erc721Location(uint256 fromId, bytes32 rights, uint256 toId, uint256 tokenId, address contract_)
        internal
        pure
        returns (bytes32 computedLocation)
    {
        assembly ("memory-safe") {
            // This block only allocates memory after the free memory pointer and in the scratch space
            let ptr := mload(64) // Cache the free memory pointer.
            // Lay out the variables from last to first, agnostic to upper 96 bits of address words.
            mstore(add(ptr, 116), tokenId)
            mstore(add(ptr, 84), contract_)
            mstore(add(ptr, 64), toId)
            mstore(add(ptr, 32), fromId)
            mstore(ptr, rights)
            mstore(0, or(shl(8, keccak256(ptr, 148)), ERC721_TYPE)) // Computes erc721Hash, then stores the result in scratch space
            mstore(32, DELEGATION_SLOT)
            computedLocation := keccak256(0, 64) // Runs keccak256 over the scratch space to obtain the storage key
        }
    }

    /**
     * @notice Helper function to compute delegation hash for `DelegationType.ERC20`
     * @dev Equivalent to `keccak256(abi.encodePacked(rights, fromId, toId, contract_))` with the last byte overwritten with ERC20_TYPE
     * @param fromId The account ID making the delegation
     * @param rights The rights specified by the delegation
     * @param toId The account ID receiving the delegation
     * @param contract_ The address of the ERC20 token contract
     * @return hash The parameters encoded with ERC20_TYPE
     */
    function erc20Hash(uint256 fromId, bytes32 rights, uint256 toId, address contract_)
        internal
        pure
        returns (bytes32 hash)
    {
        assembly ("memory-safe") {
            // This block only allocates memory after the free memory pointer
            let ptr := mload(64) // Load free memory pointer

            // Lay out the variables from last to first, agnostic to upper 96 bits of address words.
            mstore(add(ptr, 84), contract_)
            mstore(add(ptr, 64), toId)
            mstore(add(ptr, 32), fromId)
            mstore(ptr, rights)
            hash := or(shl(8, keccak256(ptr, 116)), ERC20_TYPE) // Keccak-hashes the packed encoding, left-shifts by one byte, then writes type to the lowest-order byte
        }
    }

    /**
     * @notice Helper function to compute delegation location for `DelegationType.ERC20`
     * @dev Equivalent to `location(ERC20Hash(rights, fromId, toId, contract_))`
     * @param fromId The account ID making the delegation
     * @param rights The rights specified by the delegation
     * @param toId The account ID receiving the delegation
     * @param contract_ The address of the ERC20 token contract
     * @return computedLocation The storage location of the ERC20 delegation with those parameters in the delegations mapping
     */
    function erc20Location(uint256 fromId, bytes32 rights, uint256 toId, address contract_)
        internal
        pure
        returns (bytes32 computedLocation)
    {
        assembly ("memory-safe") {
            // This block only allocates memory after the free memory pointer and in the scratch space
            let ptr := mload(64) // Loads the free memory pointer
            // Lay out the variables from last to first, agnostic to upper 96 bits of address words.
            mstore(add(ptr, 84), contract_)
            mstore(add(ptr, 64), toId)
            mstore(add(ptr, 32), fromId)
            mstore(ptr, rights)
            mstore(0, or(shl(8, keccak256(ptr, 116)), ERC20_TYPE)) // Computes erc20Hash, then stores the result in scratch space
            mstore(32, DELEGATION_SLOT)
            computedLocation := keccak256(0, 64) // Runs keccak over the scratch space to obtain the storage key
        }
    }

    /**
     * @notice Helper function to compute delegation hash for `DelegationType.ERC1155`
     * @dev Equivalent to keccak256(abi.encodePacked(rights, fromId, toId, contract_, tokenId)) left-shifted with the last byte overwritten with ERC1155_TYPE
     * @param fromId The account ID making the delegation
     * @param rights The rights specified by the delegation
     * @param toId The account ID receiving the delegation
     * @param tokenId The id of the ERC1155 token
     * @param contract_ The address of the ERC1155 token contract
     * @return hash The parameters encoded with ERC1155_TYPE
     */
    function erc1155Hash(uint256 fromId, bytes32 rights, uint256 toId, uint256 tokenId, address contract_)
        internal
        pure
        returns (bytes32 hash)
    {
        assembly ("memory-safe") {
            // This block only allocates memory after the free memory pointer
            let ptr := mload(64) // Load the free memory pointer.
            // Lay out the variables from last to first, agnostic to upper 96 bits of address words.
            mstore(add(ptr, 116), tokenId)
            mstore(add(ptr, 84), contract_)
            mstore(add(ptr, 64), toId)
            mstore(add(ptr, 32), fromId)
            mstore(ptr, rights)
            hash := or(shl(8, keccak256(ptr, 148)), ERC1155_TYPE) // Keccak-hashes the packed encoding, left-shifts by one byte, then writes type to the lowest-order byte
        }
    }

    /**
     * @notice Helper function to compute delegation location for `DelegationType.ERC1155`
     * @dev Equivalent to `location(ERC1155Hash(rights, fromId, toId, contract_, tokenId))`
     * @param fromId The account ID making the delegation
     * @param rights The rights specified by the delegation
     * @param toId The account ID receiving the delegation
     * @param tokenId The id of the ERC1155 token
     * @param contract_ The address of the ERC1155 token contract
     * @return computedLocation The storage location of the ERC1155 delegation with those parameters in the delegations mapping
     */
    function erc1155Location(uint256 fromId, bytes32 rights, uint256 toId, uint256 tokenId, address contract_)
        internal
        pure
        returns (bytes32 computedLocation)
    {
        assembly ("memory-safe") {
            // This block only allocates memory after the free memory pointer and in the scratch space
            let ptr := mload(64) // Cache the free memory pointer.
            // Lay out the variables from last to first, agnostic to upper 96 bits of address words.
            mstore(add(ptr, 116), tokenId)
            mstore(add(ptr, 84), contract_)
            mstore(add(ptr, 64), toId)
            mstore(add(ptr, 32), fromId)
            mstore(ptr, rights)
            mstore(0, or(shl(8, keccak256(ptr, 148)), ERC1155_TYPE)) // Computes erc1155Hash, then stores the result in scratch space
            mstore(32, DELEGATION_SLOT)
            computedLocation := keccak256(0, 64) // Runs keccak over the scratch space to obtain the storage key
        }
    }
}
