# Royal Protocol

## Introduction

The Royal Protocol offers an immutable solution to register and verify authorship of creative works.
The protocol is completely open-source and permissionless and designed for multiple parties to utilize and build on.

Registering provenance onchain will enable provability of authorship or creation across a wide range of creative works, including:

- Music
- Digital Artwork
- Essays & Blog Posts
- Software packages

## Contracts

This repository contains all the contracts deployed and used by the Royal Protocol (the core protocol contracts), as well as sample contracts for entities that want to interact with the Royal Protocol or extend it.

### Core Protocol Contracts

The core protocol contracts are divided between the Account system, the Provenance system, and the Delegation system.

**Account System**:

Users create accounts by registering them through the `IdGateway`.
The account system is ID-based, not address based.
Because of this, you can transfer the account between addresses if desired, and recover an account a different address if needed (if you set up recovery in advance).

- **[IdRegistry](./src/IdRegistry.sol)** - track account data for Royal Protocol accounts.
- **[IdGateway](./src/IdGateway.sol)** - wrapper for account creation & update logic - handles all write functions.

**Provenance System**:

A `ProvenanceClaim` ties together a Royal Protocol Account ID with a [blake3 hash](<https://en.wikipedia.org/wiki/BLAKE_(hash_function)#BLAKE3>) of some piece of content.
This lets us tie identities, of both the creator and the AI model if relevant, with a creative work such as a piece of music, artwork, etc.
The `ProvenanceRegistry` holds `ProvenanceClaim` data for creative works.
Each `ProvenanceClaim` may be associated with an NFT owned by the "originator" of the `ProvenanceClaim`.
Any given NFT can only be associated with a single `ProvenanceClaim`.

- **[ProvenanceRegistry](./src/ProvenanceRegistry.sol)** - track `ProvenanceClaim` data, claimed by Royal Protocol accounts.
- **[ProvenanceGateway](./src/ProvenanceGateway.sol)** - wrapper for `ProvenanceClaim` registration logic - handles all write functions.

**Delegation System**:

Users can delegate certain actions on the protocol to other protocol Account IDs. For example, one account may register provenance on behalf of another account that has delegated permissions to it. Delegations may also be used by 3rd-party extensions of the protocol.

- **[DelegateRegistry](./src/delegation/DelegateRegistry.sol)** - track `Delegation` data, written by Royal Protocol accounts.

#### Deployment Addresses

The v1.0 contracts are deployed on both Base Mainnet and Base Sepolia, to the same canonical addresses on both networks.

| Contract                                                  | Address                                                                                                               | On testnet                                                                                                |
| --------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------- |
| [IdRegistry](./src/IdRegistry.sol)                        | [0x0000002c243D1231dEfA58915324630AB5dBd4f4](https://basescan.org/address/0x0000002c243D1231dEfA58915324630AB5dBd4f4) | [Testnet block explorer](https://sepolia.basescan.org/address/0x0000002c243D1231dEfA58915324630AB5dBd4f4) |
| [IdGateway](./src/IdGateway.sol)                          | [0x000000aA0d40b46F0A78d145c321a9DcfD154Ba7](https://basescan.org/address/0x000000aA0d40b46F0A78d145c321a9DcfD154Ba7) | [Testnet block explorer](https://sepolia.basescan.org/address/0x000000aA0d40b46F0A78d145c321a9DcfD154Ba7) |
| [ProvenanceRegistry](./src/ProvenanceRegistry.sol)        | [0x0000009F840EeF8A92E533468A0Ef45a1987Da66](https://basescan.org/address/0x0000009F840EeF8A92E533468A0Ef45a1987Da66) | [Testnet block explorer](https://sepolia.basescan.org/address/0x0000009F840EeF8A92E533468A0Ef45a1987Da66) |
| [ProvenanceGateway](./src/ProvenanceGateway.sol)          | [0x000000456Bb9Fd42ADd75F4b5c2247f47D45a0A2](https://basescan.org/address/0x000000456Bb9Fd42ADd75F4b5c2247f47D45a0A2) | [Testnet block explorer](https://sepolia.basescan.org/address/0x000000456Bb9Fd42ADd75F4b5c2247f47D45a0A2) |
| [DelegateRegistry](./src/delegation/DelegateRegistry.sol) | [0x000000f1CABe81De9e020C9fac95318b14B80F14](https://basescan.org/address/0x000000f1CABe81De9e020C9fac95318b14B80F14) | [Testnet block explorer](https://sepolia.basescan.org/address/0x000000f1CABe81De9e020C9fac95318b14B80F14) |

### Sample Contracts

These extra contracts are included in this repo for use by service providers or other entities operating within the protocol.

#### RecoveryProxy

When users register for an account they can specify a recovery address that will be allowed to reset their address should they lose their custody wallet's passphrase.

**[`RecoveryProxy`](./src/extra/RecoveryProxy.sol)** is a smart contract that can recover an account to a different address.

The recovery address could also, for example, be a [multi-sig](https://safe.global/wallet) to enable [social recovery](https://wiki.polkadot.network/docs/kusama-social-recovery).

For now, Royal's `RecoveryProxy` is deployed at address [`0x06428ebF3D4A6322611792BDf674EE2600e37E29`](https://basescan.org/address/0x06428ebF3D4A6322611792BDf674EE2600e37E29).
_If_ you register for account recovery through our web interface, and lose your passphrase, we'll be able to reset your account's address.

**Note:** If you are registering your account directly with the `IdGateway` contracts, do _not_ put this as a recovery address.
Unless you registered through our web interface, we won't have any way to authenticate you and won't reset your address.

#### RoyalProtocolAccount

There are a few functions that would be useful to any contract attempting to interact with the Royal Protocol. **[`RoyalProtocolAccount`](./src/extra/RoyalProtocolAccount.sol)** is an abstract contract that any contract can inherit with logic for managing a Royal Protocol account (owned by a smart contract) and registering `ProvenanceClaim`s from a smart contract.

## Contributing

Contributions are welcome!

This is a Foundry repo - if you haven't used Foundry before, [read more here.](https://book.getfoundry.sh/)

The basic commands:

- `forge build` - Builds the contracts.
- `forge fmt` - Formats the contracts (think Prettier).
- `yarn lint` - Runs [solhint](https://github.com/protofire/solhint) - a Solidity linter, with our lint config.
- `slither . --skip-assembly` - Runs [slither](https://github.com/crytic/slither) - a security-focused code analyzer
- `forge test` - Runs tests. If you contribute, hopefully there are more tests after your contribution!
