// SPDX-License-Identifier: CC0-1.0
pragma solidity >=0.8.0;

/**
 * @title IDelegateRegistry
 * @notice A standalone immutable registry storing delegated permissions from one address to another
 */
interface IDelegateRegistry {
    /// @notice Delegation type, NONE is used when a delegation does not exist or is revoked
    enum DelegationType {
        NONE,
        ALL,
        CONTRACT,
        ERC721,
        ERC20,
        ERC1155
    }

    /// @notice Struct for returning delegations
    struct Delegation {
        DelegationType type_;
        uint256 toId;
        uint256 fromId;
        bytes32 rights;
        address contract_;
        uint256 tokenId;
        uint256 amount;
    }

    /// @notice Emitted when a Royal Protocol ID delegates or revokes rights for their entire account
    event DelegateAll(uint256 indexed fromId, uint256 indexed toId, bytes32 rights, bool enable);

    /// @notice Emitted when a Royal Protocol ID delegates or revokes rights for a contract address
    event DelegateContract(
        uint256 indexed fromId, uint256 indexed toId, address indexed contract_, bytes32 rights, bool enable
    );

    /// @notice Emitted when a Royal Protocol ID delegates or revokes rights for an ERC721 tokenId
    event DelegateERC721(
        uint256 indexed fromId,
        uint256 indexed toId,
        address indexed contract_,
        uint256 tokenId,
        bytes32 rights,
        bool enable
    );

    /// @notice Emitted when a Royal Protocol ID delegates or revokes rights for an amount of ERC20 tokens
    event DelegateERC20(
        uint256 indexed fromId, uint256 indexed toId, address indexed contract_, bytes32 rights, uint256 amount
    );

    /// @notice Emitted when a Royal Protocol ID delegates or revokes rights for an amount of an ERC1155 tokenId
    event DelegateERC1155(
        uint256 indexed fromId,
        uint256 indexed toId,
        address indexed contract_,
        uint256 tokenId,
        bytes32 rights,
        uint256 amount
    );

    /// @notice Emitted when the IdRegistry is set.
    event IdRegistrySet(address indexed oldIdRegistry, address indexed newIdRegistry);

    /// @notice Thrown if multicall calldata is malformed
    error MulticallFailed();

    /// @notice Thrown if the delegator does not exist
    error DelegatorDoesNotExist();

    /// @notice Thrown if the delegatee does not exist
    error DelegateeDoesNotExist();

    /**
     * --------  INITIALIZE ---------
     */
    function initialize(address idRegistry_, address initialOwner_) external;

    /**
     * -----------  WRITE -----------
     */

    /**
     * @notice Call multiple functions in the current contract and return the data from all of them if they all succeed
     * @param data The encoded function data for each of the calls to make to this contract
     * @return results The results from each of the calls passed in via data
     */
    function multicall(bytes[] calldata data) external payable returns (bytes[] memory results);

    /**
     * @notice Allow the delegate to act on behalf of the Royal Protocol ID of `msg.sender` for all contracts
     * @param toId The Royal Protocol ID to act as delegate
     * @param rights Specific subdelegation rights granted to the delegate, pass an empty bytestring to encompass all rights
     * @param enable Whether to enable or disable this delegation, true delegates and false revokes
     * @return delegationHash The unique identifier of the delegation
     */
    function delegateAll(uint256 toId, bytes32 rights, bool enable) external payable returns (bytes32 delegationHash);

    /**
     * @notice Allow the delegate to act on behalf of the Royal Protocol ID of the signer for all contracts
     * @param fromId The Royal Protocol ID to act as delegator
     * @param toId The Royal Protocol ID to act as delegate
     * @param rights Specific subdelegation rights granted to the delegate, pass an empty bytestring to encompass all rights
     * @param enable Whether to enable or disable this delegation, true delegates and false revokes
     * @param deadline The deadline for the signature to be valid
     * @param sig The signature to validate the delegation
     * @return delegationHash The unique identifier of the delegation
     */
    function delegateAllFor(
        uint256 fromId,
        uint256 toId,
        bytes32 rights,
        bool enable,
        uint256 deadline,
        bytes calldata sig
    ) external payable returns (bytes32 delegationHash);

    /**
     * @notice Allow the delegate to act on behalf of the Royal Protocol ID of `msg.sender` for a specific contract
     * @param toId The Royal Protocol ID to act as delegate
     * @param contract_ The contract on which rights are being delegated
     * @param rights Specific subdelegation rights granted to the delegate, pass an empty bytestring to encompass all rights
     * @param enable Whether to enable or disable this delegation, true delegates and false revokes
     * @return delegationHash The unique identifier of the delegation
     */
    function delegateContract(uint256 toId, address contract_, bytes32 rights, bool enable)
        external
        payable
        returns (bytes32 delegationHash);

    /**
     * @notice Allow the delegate to act on behalf of the Royal Protocol ID of the signer for a specific contract
     * @param fromId The Royal Protocol ID to act as delegator
     * @param toId The Royal Protocol ID to act as delegate
     * @param contract_ The contract on which rights are being delegated
     * @param rights Specific subdelegation rights granted to the delegate, pass an empty bytestring to encompass all rights
     * @param enable Whether to enable or disable this delegation, true delegates and false revokes
     * @param deadline The deadline for the signature to be valid
     * @param sig The signature to validate the delegation
     * @return delegationHash The unique identifier of the delegation
     */
    function delegateContractFor(
        uint256 fromId,
        uint256 toId,
        address contract_,
        bytes32 rights,
        bool enable,
        uint256 deadline,
        bytes calldata sig
    ) external payable returns (bytes32 delegationHash);

    /**
     * @notice Allow the delegate to act on behalf of the Royal Protocol ID of `msg.sender` for a specific ERC721 token
     * @param toId The Royal Protocol ID to act as delegate
     * @param contract_ The contract whose rights are being delegated
     * @param tokenId The token id to delegate
     * @param rights Specific subdelegation rights granted to the delegate, pass an empty bytestring to encompass all rights
     * @param enable Whether to enable or disable this delegation, true delegates and false revokes
     * @return delegationHash The unique identifier of the delegation
     */
    function delegateERC721(uint256 toId, address contract_, uint256 tokenId, bytes32 rights, bool enable)
        external
        payable
        returns (bytes32 delegationHash);

    /**
     * @notice Allow the delegate to act on behalf of the Royal Protocol ID of the signer for a specific ERC721 token
     * @param fromId The Royal Protocol ID to act as delegator
     * @param toId The Royal Protocol ID to act as delegate
     * @param contract_ The contract whose rights are being delegated
     * @param tokenId The token id to delegate
     * @param rights Specific subdelegation rights granted to the delegate, pass an empty bytestring to encompass all rights
     * @param enable Whether to enable or disable this delegation, true delegates and false revokes
     * @param deadline The deadline for the signature to be valid
     * @param sig The signature to validate the delegation
     * @return delegationHash The unique identifier of the delegation
     */
    function delegateERC721For(
        uint256 fromId,
        uint256 toId,
        address contract_,
        uint256 tokenId,
        bytes32 rights,
        bool enable,
        uint256 deadline,
        bytes calldata sig
    ) external payable returns (bytes32 delegationHash);

    /**
     * @notice Allow the delegate to act on behalf of the Royal Protocol ID of `msg.sender` for a specific amount of ERC20 tokens
     * @dev The actual amount is not encoded in the hash, just the existence of a amount (since it is an upper bound)
     * @param toId The Royal Protocol ID to act as delegate
     * @param contract_ The address for the fungible token contract
     * @param rights Specific subdelegation rights granted to the delegate, pass an empty bytestring to encompass all rights
     * @param amount The amount to delegate, > 0 delegates and 0 revokes
     * @return delegationHash The unique identifier of the delegation
     */
    function delegateERC20(uint256 toId, address contract_, bytes32 rights, uint256 amount)
        external
        payable
        returns (bytes32 delegationHash);

    /**
     * @notice Allow the delegate to act on behalf of the Royal Protocol ID of the signer for a specific amount of ERC20 tokens
     * @dev The actual amount is not encoded in the hash, just the existence of a amount (since it is an upper bound)
     * @param fromId The Royal Protocol ID to act as delegator
     * @param toId The Royal Protocol ID to act as delegate
     * @param contract_ The address for the fungible token contract
     * @param rights Specific subdelegation rights granted to the delegate, pass an empty bytestring to encompass all rights
     * @param amount The amount to delegate, > 0 delegates and 0 revokes
     * @param deadline The deadline for the signature to be valid
     * @param sig The signature to validate the delegation
     * @return delegationHash The unique identifier of the delegation
     */
    function delegateERC20For(
        uint256 fromId,
        uint256 toId,
        address contract_,
        bytes32 rights,
        uint256 amount,
        uint256 deadline,
        bytes calldata sig
    ) external payable returns (bytes32 delegationHash);

    /**
     * @notice Allow the delegate to act on behalf of the Royal Protocol ID of `msg.sender` for a specific amount of ERC1155 tokens
     * @dev The actual amount is not encoded in the hash, just the existence of a amount (since it is an upper bound)
     * @param toId The Royal Protocol ID to act as delegate
     * @param contract_ The address of the contract that holds the token
     * @param tokenId The token id to delegate
     * @param rights Specific subdelegation rights granted to the delegate, pass an empty bytestring to encompass all rights
     * @param amount The amount of that token id to delegate, > 0 delegates and 0 revokes
     * @return delegationHash The unique identifier of the delegation
     */
    function delegateERC1155(uint256 toId, address contract_, uint256 tokenId, bytes32 rights, uint256 amount)
        external
        payable
        returns (bytes32 delegationHash);

    /**
     * @notice Allow the delegate to act on behalf of the Royal Protocol ID of the signer for a specific amount of ERC1155 tokens
     * @dev The actual amount is not encoded in the hash, just the existence of a amount (since it is an upper bound)
     * @param fromId The Royal Protocol ID to act as delegator
     * @param toId The Royal Protocol ID to act as delegate
     * @param contract_ The address of the contract that holds the token
     * @param tokenId The token id to delegate
     * @param rights Specific subdelegation rights granted to the delegate, pass an empty bytestring to encompass all rights
     * @param amount The amount of that token id to delegate, > 0 delegates and 0 revokes
     * @param deadline The deadline for the signature to be valid
     * @param sig The signature to validate the delegation
     * @return delegationHash The unique identifier of the delegation
     */
    function delegateERC1155For(
        uint256 fromId,
        uint256 toId,
        address contract_,
        uint256 tokenId,
        bytes32 rights,
        uint256 amount,
        uint256 deadline,
        bytes calldata sig
    ) external payable returns (bytes32 delegationHash);

    /**
     * ----------- CHECKS -----------
     */

    /**
     * @notice Check if `to` is a delegate of `from` for all contracts
     * @param toId The delegated Royal Protocol account to check
     * @param fromId The Royal Protocol account that issued the delegation
     * @param rights Specific rights to check for, pass the zero value to ignore subdelegations and check full delegations only
     * @return valid Whether delegate is granted to act on the from's behalf
     */
    function checkDelegateForAll(uint256 toId, uint256 fromId, bytes32 rights) external view returns (bool);

    /**
     * @notice Check if `to` is a delegate of `from` for the specified `contract_` or all contracts
     * @param toId The delegated Royal Protocol account to check
     * @param fromId The Royal Protocol account that issued the delegation
     * @param contract_ The specific contract address being checked
     * @param rights Specific rights to check for, pass the zero value to ignore subdelegations and check full delegations only
     * @return valid Whether delegate is granted to act on from's behalf for entire wallet or that specific contract
     */
    function checkDelegateForContract(uint256 toId, uint256 fromId, address contract_, bytes32 rights)
        external
        view
        returns (bool);

    /**
     * @notice Check if `to` is a delegate of `from` for the specific `contract` and `tokenId`, the entire `contract_`, or all contracts
     * @param toId The delegated Royal Protocol account to check
     * @param fromId The Royal Protocol account that issued the delegation
     * @param contract_ The specific contract address being checked
     * @param tokenId The token id for the token to delegating
     * @param rights Specific rights to check for, pass the zero value to ignore subdelegations and check full delegations only
     * @return valid Whether delegate is granted to act on from's behalf for entire wallet, that contract, or that specific tokenId
     */
    function checkDelegateForERC721(uint256 toId, uint256 fromId, address contract_, uint256 tokenId, bytes32 rights)
        external
        view
        returns (bool);

    /**
     * @notice Returns the amount of ERC20 tokens the delegate is granted rights to act upon on behalf of fromId
     * @param toId The delegated Royal Protocol account to check
     * @param fromId The Royal Protocol account that issued the delegation
     * @param contract_ The address of the token contract
     * @param rights Specific rights to check for, pass the zero value to ignore subdelegations and check full delegations only
     * @return balance The delegated balance, which will be 0 if the delegation does not exist
     */
    function checkDelegateForERC20(uint256 toId, uint256 fromId, address contract_, bytes32 rights)
        external
        view
        returns (uint256);

    /**
     * @notice Returns the amount of a ERC1155 tokens the delegate is granted rights to act upon on behalf of fromId
     * @param toId The delegated Royal Protocol account to check
     * @param fromId The Royal Protocol account that issued the delegation
     * @param contract_ The address of the token contract
     * @param tokenId The token id to check the delegated amount of
     * @param rights Specific rights to check for, pass the zero value to ignore subdelegations and check full delegations only
     * @return balance The delegated balance, which will be 0 if the delegation does not exist
     */
    function checkDelegateForERC1155(uint256 toId, uint256 fromId, address contract_, uint256 tokenId, bytes32 rights)
        external
        view
        returns (uint256);

    /**
     * ----------- ENUMERATIONS -----------
     */

    /**
     * @notice Returns all enabled delegations a given delegate has received
     * @param toId The Royal Protocol account to retrieve delegations for
     * @return delegations Array of Delegation structs
     */
    function getIncomingDelegations(uint256 toId) external view returns (Delegation[] memory delegations);

    /**
     * @notice Returns all enabled delegations an address has given out
     * @param fromId The Royal Protocol account to retrieve delegations for
     * @return delegations Array of Delegation structs
     */
    function getOutgoingDelegations(uint256 fromId) external view returns (Delegation[] memory delegations);

    /**
     * @notice Returns all hashes associated with enabled delegations an address has received
     * @param toId The Royal Protocol account to retrieve incoming delegation hashes for
     * @return delegationHashes Array of delegation hashes
     */
    function getIncomingDelegationHashes(uint256 toId) external view returns (bytes32[] memory delegationHashes);

    /**
     * @notice Returns all hashes associated with enabled delegations an address has given out
     * @param fromId The Royal Protocol account to retrieve outgoing delegation hashes for
     * @return delegationHashes Array of delegation hashes
     */
    function getOutgoingDelegationHashes(uint256 fromId) external view returns (bytes32[] memory delegationHashes);

    /**
     * @notice Returns the delegations for a given array of delegation hashes
     * @param delegationHashes is an array of hashes that correspond to delegations
     * @return delegations Array of Delegation structs, return empty structs for nonexistent or revoked delegations
     */
    function getDelegationsFromHashes(bytes32[] calldata delegationHashes)
        external
        view
        returns (Delegation[] memory delegations);

    /**
     * ----------- STORAGE ACCESS -----------
     */

    /**
     * @notice Allows external contracts to read arbitrary storage slots
     */
    function readSlot(bytes32 location) external view returns (bytes32);

    /**
     * @notice Allows external contracts to read an arbitrary array of storage slots
     */
    function readSlots(bytes32[] calldata locations) external view returns (bytes32[] memory);
}
