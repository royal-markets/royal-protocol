# Extra - Protocol Helpers

There are a few contracts included in the repo that are not part of the protocol, and yet may be helpful for entities building on top of the protocol.

## RecoveryProxy

This contract is intended to be used as a well-known Recovery address for entities offering "Recovery-as-a-Service" (or who offer Recovery in combination with other services).

This contract is intentionally upgradable, so that the Recovery provider can change its implementation/functionality without requiring each user to update their `recovery` address in their RoyalProtocol account data - since the RecoveryProxy address stays the same throughout upgrades.

## ProvenanceToken

A simple ERC721 contract which can be used as the NFT that gets assigned/associated to a ProvenanceClaim.

As written, this contract only exposes a `mintTo()` function that can only be called by an address with the `AIRDROPPER` role. This is designed to be used in conjunction with the `ProvenanceRegistrar` contract.

## ProvenanceRegistrar

The ProvenanceRegistrar is a contract which mints an NFT to the originator's custody address, and then registers a ProvenanceClaim on their behalf.

For this to work, the address of the `ProvenanceRegistrar` must be delegated to by the originator to operate on the protocol's `ProvenanceGateway` contract for the `"registerProvenance"` permission.

So, a call would need to be made to DelegateRegistry v2 of:

```solidity
// function delegateContract(
//   address to,
//   address contract_,
//   bytes32 rights,
//   bool enable
//)

// msg.sender = originator
delegateRegistry.delegateContract(
  provenanceRegistrar,
  provenanceGateway,
  "registerProvenance",
  true
)
```
