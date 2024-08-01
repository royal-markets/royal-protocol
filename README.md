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
2. **[IdGateway](./src/core/IdGateway.sol)** - wrapper for protocol account registration logic.
3. **[UsernameGateway](./src/core/UsernameGateway.sol)** - wrapper for changing usernames and username validation logic.

**Provenance System**:

4. **[ProvenanceRegistry](./src/core/ProvenanceRegistry.sol)** - tracks ProvenanceClaim data, claimed by Royal Protocol accounts.
5. **[ProvenanceGateway](./src/core/ProvenanceGateway.sol)** - wrapper for ProvenanceClaim validation and registration logic.

### Extras

In addition to the "core" contracts, there are some extra contracts included in this repo that may be useful for service providers or other entities operating within the protocol:

6. **[RecoveryProxy](./src/extra/RecoveryProxy.sol)** - A smart contract that can be set as the `recovery` address for an account. Intended to be used by entities offering "Recovery-as-a-Service".
7. **[ProvenanceToken](./src/extra/ProvenanceToken.sol)** - A simple ERC721 NFT contract. Each ProvenanceClaim requires a corresponding NFT token. This contract specifically was designed to be used with the ProvenanceRegistrar contract.
8. **[ProvenanceRegistrar](./src/extra/ProvenanceRegistrar.sol)** - A smart contract that can register provenance on behalf of other users. For that to work, this contract's address needs to be registered as the `operator` address of some protocol account, and delegations from users need to be set to this smart contract address on [delegate.xyz](https://delegate.xyz/).

## Deployments

The v1.0 contracts are deployed on both Base Mainnet and Base Sepolia, to the same canonical addresses on both mainnet and testnet.

### Base

| Contract           | Address                                                                                                               |
| ------------------ | --------------------------------------------------------------------------------------------------------------------- |
| IdRegistry         | [0x00000000F74144b0dF049137A0F9416a920F2514](https://basescan.org/address/0x00000000F74144b0dF049137A0F9416a920F2514) |
| IdGateway          | [0x000000005F8bda585d7D2b1A0b7e29e12a94910a](https://basescan.org/address/0x000000005F8bda585d7D2b1A0b7e29e12a94910a) |
| UsernameGateway    | [0x00000000A3B81eB162644186b972C0b6a6f5b8E0](https://basescan.org/address/0x00000000A3B81eB162644186b972C0b6a6f5b8E0) |
| ProvenanceRegistry | [0x00000000956fF4AD0c5b076fB77C23a2B0EaD0D9](https://basescan.org/address/0x00000000956fF4AD0c5b076fB77C23a2B0EaD0D9) |
| ProvenanceGateway  | [0x00000000D224D4E84852C3EBE334aE0E914620d3](https://basescan.org/address/0x00000000D224D4E84852C3EBE334aE0E914620d3) |

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
