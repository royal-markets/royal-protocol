# Royal Protocol

## Introduction

The Royal Protocol offers an immutable solution to register and verify authorship of creative works. The protocol is completely open and designed for multiple parties to utilize and build against.

Registering provenance on-chain will enable provability of authorship / creation across a wide range of creative works, including:

- Music
- Digital Artwork
- Essays & Blog Posts
- ...

## Contracts

This repository contains all the contracts deployed and used by the Royal Protocol. The contracts can be grouped into two different classifications:

**Account System**:

1. **[IdRegistry](./src/core/IdRegistry.sol)** - tracks account data for Royal Protocol accounts.
2. **[IdGateway](./src/core/IdGateway.sol)** - wrapper for account creation & update logic.

**Provenance System**:

4. **[ProvenanceRegistry](./src/core/ProvenanceRegistry.sol)** - tracks ProvenanceClaim data, claimed by Royal Protocol accounts.
5. **[ProvenanceGateway](./src/core/ProvenanceGateway.sol)** - wrapper for ProvenanceClaim registration logic.

### Extras

In addition to the "core" contracts, there are some extra contracts included in this repo that may be useful for service providers or other entities operating within the protocol:

6. **[RecoveryProxy](./src/extra/RecoveryProxy.sol)** - A smart contract that can be set as the `recovery` address for an account. Intended to be used by entities offering "Recovery-as-a-Service".
7. **[ProvenanceToken](./src/extra/ProvenanceToken.sol)** - A simple ERC721 NFT contract. Each ProvenanceClaim can optionally have a corresponding NFT token. This contract specifically was designed to be used with the ProvenanceRegistrar contract.
8. **[ProvenanceRegistrar](./src/extra/ProvenanceRegistrar.sol)** - A smart contract that can register provenance on behalf of other users. For that to work, delegations from users need to be set to this smart contract address on [delegate.xyz](https://delegate.xyz/).
9. **[RoyalProtocolAccount](./src/extra/RoyalProtocolAccount.sol)** - An `abstract` contract with logic for managing a RoyalProtocol account and registering ProvenanceClaims from a smart contract. Extended by the `ProvenanceRegistrar` contract.

## Deployments

The v1.0 contracts are deployed on both Base Mainnet and Base Sepolia, to the same canonical addresses on both mainnet and testnet.

### Base

| Contract           | Address                                                                                                               |
| ------------------ | --------------------------------------------------------------------------------------------------------------------- |
| IdRegistry         | [0x0000002c243D1231dEfA58915324630AB5dBd4f4](https://basescan.org/address/0x0000002c243D1231dEfA58915324630AB5dBd4f4) |
| IdGateway          | [0x000000aA0d40b46F0A78d145c321a9DcfD154Ba7](https://basescan.org/address/0x000000aA0d40b46F0A78d145c321a9DcfD154Ba7) |
| ProvenanceRegistry | [0x0000009F840EeF8A92E533468A0Ef45a1987Da66](https://basescan.org/address/0x0000009F840EeF8A92E533468A0Ef45a1987Da66) |
| ProvenanceGateway  | [0x000000456Bb9Fd42ADd75F4b5c2247f47D45a0A2](https://basescan.org/address/0x000000456Bb9Fd42ADd75F4b5c2247f47D45a0A2) |

## Contributing

Contributions are welcome!

This is a Foundry repo - if you haven't used Foundry before, [read more here.](https://book.getfoundry.sh/)

The basic commands:

- `forge build` - Builds the contracts.
- `forge fmt` - Formats the contracts (think Prettier).
- `yarn lint` - Runs [solhint](https://github.com/protofire/solhint) - a Solidity linter, with our lint config.
- `slither . --skip-assembly` - Runs [slither](https://github.com/crytic/slither) - a security-focused code analyzer
- `forge test` - Runs tests. If you contribute, hopefully there are more tests after your contribution.
- `yarn coverage` - Runs a coverage tool and boots up an HTML page to inspect coverage.
