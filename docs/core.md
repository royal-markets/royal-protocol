# Royal Protocol Contracts

There are two main parts of the Royal Protocol - the Account System and the Provenance System.

Users create accounts by registering an account through the `IdGateway`. The Account system automatically assigns autoincrementing IDs to each user, but the user provides the rest of the data in the User struct:

```solidity
/**
  * @param id       The user's ID.
  * @param custody  The user's custody address. Controls the account.
  * @param username The user's username.
  * @param recovery The user's recovery address (Optional).
  *                   Can recover the ID to another custody address.
  */
struct User {
    uint256 id;
    address custody;
    string username;
    address recovery; // Optional
}
```

Once a user has a registered account, they can then register ProvenanceClaims - either on behalf of themselves for creative works where they were the author (originator) - or on behalf of other users: for example - a digital creative tool registering works on behalf of its users.

Regardless, both the originator (author of the work) and the registrar (entity registering the work) must have registered accounts in the Royal Protocol account system.

```solidity
/**
  * @param originatorId The RoyalProtocol ID of the originator.
                        (who created the content which this ProvenanceClaim represents).
  * @param registrarId  The RoyalProtocol ID of the registrar.
                        (who registered this ProvenanceClaim on behalf of the originator).
  * @param contentHash  The blake3 hash of the content which this ProvenanceClaim represents.
  * @param nftContract  The NFT contract of the NFT associated with this ProvenanceClaim. (Optional)
  * @param nftTokenId   The tokenID of the NFT associated with this ProvenanceClaim. (Optional)
  * @param blockNumber  The block.number that this provenance claim was registered in.
  */
struct ProvenanceClaim {
    // uint256 id; // TODO: This is nonsense
    uint256 originatorId;
    uint256 registrarId;
    bytes32 contentHash;
    address nftContract;
    uint256 nftTokenId;
    uint256 blockNumber;
}
```

> NOTE: For a registrar to have permission to register ProvenanceClaims on behalf of another account, delegations need to be set up in delegate.xyz's v2 DelegateRegistry.

```solidity
// msg.sender here would be the custody address of the account you are setting up delegation from.
// Note that you can also do this through a UI on the https://delegate.xyz/ website.
delegateRegistry.delegateContract(
  registrar,            // The address to delegate to.
  provenanceGateway,    // the contract the registrar will have delegated permissions on.
  "registerProvenance", // The specific `bytes32 rights` / permissions we are granting to the registrar.
  true                  // `true` enables delegation.
)
```

## 1. Account System Contracts

The account system is made up of 2 core contracts:

- IdRegistry - tracks and stores account data for Royal Protocol accounts.
- IdGateway - wrapper for protocol account creation & update logic.

Additionally, the protocol utilizes `delegate.xyz`'s v2 DelegateRegistry to determine permissions for certain actions: for example, whether or not a given address can:

- Register a ProvenanceClaim on an originator account's behalf
- Assign an NFT to an existing ProvenanceClaim by a given originator

### 1.1 IdRegistry

The IdRegistry lets any Ethereum address claim a unique Royal Protocol ID and a unique `username` for that account. An Ethereum address can only be associated with one Royal Protocol ID at a time.

- Each Royal Protocol ID has a `custody` address that manages the user's account data.

- Additionally, accounts can set an optional `recovery` address to allow transfering that account to another custody wallet, in case the initial custody wallet is lost.

<!-- TODO: Add more utility functions / getters that you wrote -->

#### Utility Functions

The IdRegistry provides various utility functions to look up an account or to look up account data:

```solidity
/// @notice Get the user data for the provided ID.
function getUserById(uint256 id) external view returns (User memory);

/// @notice Gets the ID for a given username.
function getIdByUsername(string calldata username) external view returns (uint256 id);

/// @notice Maps each address (custody) to its associated ID.
function idOf(address wallet) external view returns (uint256);

/// @notice Maps each ID to its associated custody address.
function custodyOf(uint256 id) external view returns (address);

/// @notice Maps each ID to its associated username.
function usernameOf(uint256 id) external view returns (string memory);

/// @notice Maps each ID to its associated recovery address.
function recoveryOf(uint256 id) external view returns (address);
```

<!-- TODO: Rewrite this -->

### 1.2 IdGateway

The IdGateway is a thin wrapper around account registration. The IdRegistry cannot be hit directly for account registration - all account registration must go through the IdGateway.

While the IdGateway just passes through the request at the moment - having an abstraction layer above account registration opens up the possibilities for future changes, like different account validation logic, without touching the core IdRegistry that holds account data.

<!-- TODO: Review -->

### 1.3 DelegateRegistry

The `delegate.xyz` DelegateRegistry is only used by one function on the IdRegistry - `canAct()`:

```solidity
/**
  * @notice Check if an address can take a given action on behalf of an ID.
  *
  * NOTE: Because the logic here is based on the delegateRegistry, we can swap out
  *       the delegateRegistry from `delegate.xyz` to our own implementation in the future,
  *       if we ever want to update/upgrade the logic for `canAct()`.
  *
  * @param id The RoyalProtocol ID to check.
  * @param actor The address attempting to take the action.
  * @param contractAddr The address of the contract the action is being taken on.
  * @param rights The rights being requested. (Optional).
  */
function canAct(uint256 id, address actor, address contractAddr, bytes32 rights) external view returns (bool);
```

This function is used by the Provenance System to determine whether a given Ethereum address (the "actor") can take an action on behalf of some protocol account.

Right now, the IdRegistry looks up delegations on the `delegate.xyz` v2 DelegateRegistry - but the contract that the IdRegistry looks at is updatable - so it is possible to deploy a custom DelegateRegistry (that adheres to the same basic interface) if more functionality is desired in the future.

<!-- TODO: Review / rewrite all provenance system stuff -->

## 2. Provenance System Contracts

The provenance system is made up of 2 core contracts:

- ProvenanceRegistry - tracks and stores ProvenanceClaim data.
- ProvenanceGateway - wrapper for ProvenanceClaim validation and registration logic.

### 2.1 ProvenanceRegistry

The ProvenanceRegistry holds ProvenanceClaim data for creative works. Each ProvenanceClaim _may_ be associated with an NFT owned by the "originator" of the ProvenanceClaim - and any given NFT can only be associated with a single ProvenanceClaim.

A ProvenanceClaim ties together a RoyalProtocol Account ID with a `blake3` hash of some piece of content.

Because blockchain interactions have a deterministic ordering - anyone can determine who claimed any given piece of content first.

```solidity
/**
  * @notice A provenance claim.
  *
  * @param originatorId The RoyalProtocol ID of the originator. (who created the content which this ProvenanceClaim represents).
  * @param registrarId The RoyalProtocol ID of the registrar. (who registered this ProvenanceClaim on behalf of the originator).
  * @param contentHash The blake3 hash of the content which this ProvenanceClaim represents.
  *
  * @param nftContract The NFT contract of the associated NFT of this ProvenanceClaim (optional).
  * @param nftTokenId The token ID of the NFT associated with this ProvenanceClaim (optional).
  * @param blockNumber The block number this provenance claim was registered in.
  */
struct ProvenanceClaim {
    // uint256 id => TODO ridiculous.
    uint256 originatorId;
    uint256 registrarId;
    bytes32 contentHash;
    address nftContract;
    uint256 nftTokenId;
    uint256 blockNumber;
}
```

The ProvenanceRegistry cannot be written to directly, and must be accessed through the ProvenanceGateway.

Also, the `ProvenanceRegistry` contract is not upgradable - but can swap out the implementation of the `ProvenanceGateway` it points at.

### 2.2 ProvenanceGateway

The ProvenanceGateway is a wrapper around registering ProvenanceClaims and assigning ERC721 NFTs to ProvenanceClaims that do not yet have an assigned NFT.

Having an abstraction layer above provenance claiming opens up the possibility for different validation logic or other future changes without touching the core ProvenanceRegistry that actually holds the data.
