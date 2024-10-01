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
  * @param id The autoincrementing ID that identifies a ProvenanceClaim.
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
    uint256 id;
    uint256 originatorId;
    uint256 registrarId;
    bytes32 contentHash;
    address nftContract;
    uint256 nftTokenId;
    uint256 blockNumber;
}
```

> NOTE: For a registrar to have permission to register ProvenanceClaims on behalf of another account, delegations need to be set up in delegate.xyz's v2 DelegateRegistry.
>
> Alternatively, the originator can sign an EIP712 message granting permission to a registrar to register a single ProvenanceClaim on their behalf.

#### Delegation Example:

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

- `IdRegistry` - tracks and stores account data for Royal Protocol accounts.
- `IdGateway` - wrapper for protocol account creation & update logic.

Additionally, the protocol utilizes `delegate.xyz`'s v2 DelegateRegistry to determine permissions for certain actions: for example, whether or not a given address can:

- Register a ProvenanceClaim on an originator's behalf
- Assign an NFT to an existing ProvenanceClaim on an originator's behalf

### 1.1 IdRegistry

The IdRegistry lets any Ethereum address claim a unique Royal Protocol ID and a unique `username` for that account. An Ethereum address can only be associated with one Royal Protocol ID at a time.

- Each Royal Protocol ID has a `custody` address that manages the user's account data.

- Additionally, accounts can set an optional `recovery` address to allow transfering that account to another custody wallet, in case the initial custody wallet is lost.

#### Registration

Here's a rough example of how to register a new Royal Protocol account:

```solidity
string calldata myUsername = "HelloWorld";

// Recovery addresses are optional,
// and allow recovering an account if you lose access to the custody address
address recovery = address(0);

// NOTE: Right now the fee for registration is set to 0 - so registration is free,
//       but this may change moving forward.
uint256 registerFee = idGateway.registerFee();

// The `custody` address here will be `msg.sender`.
uint256 protocolAccountId = idGateway.register{value: registerFee}(myUsername, recovery);
```

For other account management, like changing a username, changing the recovery address, or transfering the account to another custody address, look at the [`IIdGateway` interface](../src/core/interfaces/IIdGateway.sol) to see function signatures.

#### Utility Functions

The IdRegistry provides various utility functions to look up an account or to look up account data:

```solidity
/// @notice Get the user data for the provided ID.
function getUserById(uint256 id) external view returns (User memory);

/// @notice Gets the User data for the provided custody address.
function getUserByAddress(address custody) external view returns (User memory);

/// @notice Gets the User data for a given username.
function getUserByUsername(string calldata username) external view returns (User memory);
```

### 1.2 IdGateway

The IdGateway is a thin wrapper around account registration. The IdRegistry cannot be hit directly for account creation or management - all account activity must go through the IdGateway.

> NOTE: Account data is _read_ from the `IdRegistry`, but all write activity happens through the `IdGateway`.

Having an abstraction layer above account registration and management opens up the possibilities for future changes, like different access control logic, without touching the core IdRegistry that holds account data.

#### Utility Functions

The IdGateway also provides a utility function to check if a provided username is valid and available:

```solidity
    /**
     * @notice Check if a username is valid.
     *         Intended to be used by DApps to check if a username is valid before attempting to register it.
     *         Also used by the IdRegistry when registering a new ID.
     *
     * @return True if the username is valid, reverts otherwise.
     *
     * - Must be unique.
     * - Must be <= 16 bytes (ASCII characters) in length.
     * - All characters must be alphanumeric or "_" underscores.
     */
    function checkUsername(string calldata username) external view returns (bool);
```

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

The two actions that delegations are possible for right now are registering a ProvenanceClaim, or attaching an NFT to an existing ProvenanceClaim that does not yet have an attached NFT.

> NOTE: In the following examples, `msg.sender` is the `registrar`, which could be the custody address of the `originatorId` (a self-registration), or could be the custody address of some other protocol account (which would require delegation from the originator).

```solidity
        // Check that the registrar has permission to register provenance on behalf of the originator.
        idRegistry.canAct(originatorId, msg.sender, provenanceGateway, "registerProvenance")

        // Check that the assigner has permission to assign an NFT to a ProvenanceClaim on behalf of the originator.
        idRegistry.canAct(originatorId, msg.sender, provenanceGateway, "assignNft")
```

Right now, the IdRegistry looks up delegations on the `delegate.xyz` v2 DelegateRegistry - but the contract address that the IdRegistry uses to determine delegation at is updatable. This gives the protocol the possibility to expand or change delegation logic moving forward.

## 2. Provenance System Contracts

The provenance system is made up of 2 core contracts:

- `ProvenanceRegistry` - tracks and stores ProvenanceClaim data.
- `ProvenanceGateway` - wrapper for ProvenanceClaim validation and registration logic.

### 2.1 ProvenanceRegistry

The ProvenanceRegistry holds ProvenanceClaim data for creative works. Each ProvenanceClaim _may_ be associated with an NFT owned by the "originator" of the ProvenanceClaim - and any given NFT can only be associated with a single ProvenanceClaim.

A ProvenanceClaim ties together a RoyalProtocol Account ID with a `blake3` hash of some piece of content.

Because blockchain interactions have a deterministic ordering - anyone can determine who claimed any given piece of content first. Additionally, since each ProvenanceClaim has both an `originatorId` and a `registrarId` - the potential to get a "co-signature" from a respected or trusted registrar provides another data point to determine which ProvenanceClaim is "true" or correct.

```solidity
/**
  * @notice A provenance claim.
  *
  * @param id The autoincrementing ID that identifies a given ProvenanceClaim.
  * @param originatorId The RoyalProtocol ID of the originator. (who created the content which this ProvenanceClaim represents).
  * @param registrarId The RoyalProtocol ID of the registrar. (who registered this ProvenanceClaim on behalf of the originator).
  * @param contentHash The blake3 hash of the content which this ProvenanceClaim represents.
  *
  * @param nftContract The NFT contract of the associated NFT of this ProvenanceClaim (optional).
  * @param nftTokenId The token ID of the NFT associated with this ProvenanceClaim (optional).
  * @param blockNumber The block number this provenance claim was registered in.
  */
struct ProvenanceClaim {
    uint256 id;
    uint256 originatorId;
    uint256 registrarId;
    bytes32 contentHash;
    address nftContract;
    uint256 nftTokenId;
    uint256 blockNumber;
}
```

Just like the IdRegistry & IdGateway, The ProvenanceRegistry cannot be written to directly, and must be accessed through the ProvenanceGateway.

#### Utility Functions

The ProvenanceRegistry provides various getter functions to look up a ProvenanceClaim:

```solidity
    /// @notice The ProvenanceClaim for a given ID.
    function provenanceClaim(uint256 id) external view returns (ProvenanceClaim memory);

    /// @notice The ProvenanceClaim for a given originator ID and blake3 contentHash.
    function provenanceClaimOfOriginatorAndHash(uint256 originatorId, bytes32 contentHash)
        external
        view
        returns (ProvenanceClaim memory);

    /// @notice The ProvenanceClaim for a given NFT token.
    function provenanceClaimOfNftToken(address nftContract, uint256 nftTokenId)
        external
        view
        returns (ProvenanceClaim memory);
```

### 2.2 ProvenanceGateway

The ProvenanceGateway is a wrapper around registering ProvenanceClaims and assigning ERC721 NFTs to ProvenanceClaims that do not yet have an assigned NFT.

Having an abstraction layer above registering ProvenanceClaims opens up the possibility for different validation logic or other future changes without touching the core ProvenanceRegistry that actually holds the data.

#### Registration and Assigning NFTs

Here's an rough example of how to register a ProvenanceClaim:

```solidity
// NOTE: Right now the fee for registration is set to 0 - so registration is free,
//       but this may change moving forward.
uint256 registerFee = provenanceGateway.registerFee();

// The `custody` address of the registrar here will be `msg.sender`.
uint256 provenanceClaimId = provenanceGateway.register{value: registerFee}({
  originatorId: originatorId, // Account that created the content.
  contentHash: contentHash, // blake3 hash of content
  nftContract: address(0),
  nftTokenId: 0
  });
```

You could provide the `nftContract` and `nftTokenId` when doing the initial registration, but here is how you would assign an NFT after the fact:

```solidity
  // Assumes `msg.sender` has permission to do assignNft for this provenanceClaim:
  // either `msg.sender` is the custody address of originatorId,
  // or `msg.sender` is the custody address of a registrar that has been delegated by the originator.
  provenanceGateway.assignNft(provenanceClaimId, nftContract, nftTokenId);
```
