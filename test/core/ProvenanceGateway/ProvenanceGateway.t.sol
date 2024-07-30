// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IProvenanceRegistry} from "../../../src/core/interfaces/IProvenanceRegistry.sol";
import {ProvenanceTest} from "../ProvenanceTest.sol";
import {ERC721Mock} from "../Utils.sol";

contract ProvenanceGatewayTest is ProvenanceTest {
    // =============================================================
    //                           EVENTS
    // =============================================================

    event ProvenanceRegistered(
        uint256 id,
        uint256 indexed originatorId,
        uint256 indexed registrarId,
        bytes32 indexed contentHash,
        address nftContract,
        uint256 nftTokenId
    );

    // =============================================================
    //                          ERRORS
    // =============================================================

    error OriginatorDoesNotExist();
    error RegistrarDoesNotExist();
    error NftNotOwnedByOriginator();
    error NftTokenAlreadyUsed();
    error ContentHashAlreadyRegistered();

    // =============================================================
    //                   Constants / Immutables
    // =============================================================

    function test_VERSION() public view {
        assertEq(provenanceGateway.VERSION(), "2024-07-29");
    }

    function test_REGISTER_TYPEHASH() public view {
        assertEq(
            provenanceGateway.REGISTER_TYPEHASH(),
            keccak256(
                "Register(uint256 originatorId,bytes32 contentHash,address nftContract,uint256 nftTokenId,uint256 nonce,uint256 deadline)"
            )
        );
    }

    function test_PROVENANCE_REGISTRY() public view {
        assertEq(address(provenanceGateway.PROVENANCE_REGISTRY()), address(provenanceRegistry));
    }

    function test_eip712Domain() public view {
        (
            bytes1 fields,
            string memory name,
            string memory version,
            uint256 chainId,
            address verifyingContract,
            bytes32 salt,
            uint256[] memory extensions
        ) = provenanceGateway.eip712Domain();

        assertEq(fields, hex"0f");
        assertEq(name, "RoyalProtocol_ProvenanceGateway");
        assertEq(version, "1");
        assertEq(chainId, block.chainid);
        assertEq(verifyingContract, address(provenanceGateway));
        assertEq(salt, bytes32(0));
        assertEq(extensions.length, 0);
    }

    // =============================================================
    //                       constructor()
    // =============================================================

    function test_UnpausedWhenDeployed() public view {
        assertEq(provenanceGateway.paused(), false);
    }

    function test_OwnerSetWhenDeployed() public view {
        assertEq(provenanceGateway.owner(), PROVENANCE_GATEWAY_OWNER);
    }

    function test_idRegistry() public view {
        assertEq(address(provenanceGateway.idRegistry()), address(idRegistry));
    }

    function test_idRegistryFrozen() public view {
        assertEq(provenanceGateway.idRegistryFrozen(), false);
    }

    // =============================================================
    //                       Receiving ETH
    // =============================================================

    function testFuzz_RevertWhenReceivingDirectPayment(address sender, uint256 amount) public {
        vm.deal(sender, amount);
        vm.expectRevert();
        vm.prank(sender);
        payable(address(provenanceGateway)).transfer(amount);
    }

    // =============================================================
    //                        register()
    // =============================================================

    function testFuzz_register_WhenCustodyIsCallerAndNftHolder(
        address custody,
        bytes32 contentHash,
        bytes32 nftContractSalt,
        uint256 nftTokenId,
        uint256 blockNumber
    ) public {
        // Bound inputs that need to be bound
        vm.assume(custody != address(0));

        // Register the custody as an originator, and mint the NFT to the custody.
        uint256 originatorId = _register(custody, "username");
        address nftContract = _createMockERC721(nftContractSalt);
        ERC721Mock(nftContract).mint(custody, nftTokenId);

        // Roll the block number forward to simulate the block number at the time of registration.
        vm.roll(blockNumber);

        // Assert preconditions.
        uint256 expectedId = 1;
        _assertRegisterPreconditions(expectedId, originatorId, contentHash, nftContract, nftTokenId);

        // Register the provenance claim and check the event.
        vm.expectEmit();
        emit ProvenanceRegistered({
            id: expectedId,
            originatorId: originatorId,
            registrarId: originatorId,
            contentHash: contentHash,
            nftContract: nftContract,
            nftTokenId: nftTokenId
        });

        vm.prank(custody);
        provenanceGateway.register(originatorId, contentHash, nftContract, nftTokenId);

        // Assert postconditions.
        _assertRegisterPostconditions(expectedId, originatorId, originatorId, contentHash, nftContract, nftTokenId);
    }

    function testFuzz_register_WhenCustodyIsCallerButOperatorIsNftHolder(
        address custody,
        address operator,
        bytes32 contentHash,
        bytes32 nftContractSalt,
        uint256 nftTokenId,
        uint256 blockNumber
    ) public {
        // Bound inputs that need to be bound
        vm.assume(custody != address(0));
        vm.assume(operator != address(0));
        vm.assume(custody != operator);

        // Register the custody as an originator, and mint the NFT to the custody.
        uint256 originatorId = _register(custody, "username", operator);
        address nftContract = _createMockERC721(nftContractSalt);
        ERC721Mock(nftContract).mint(operator, nftTokenId);

        // Roll the block number forward to simulate the block number at the time of registration.
        vm.roll(blockNumber);

        // Assert preconditions.
        uint256 expectedId = 1;
        _assertRegisterPreconditions(expectedId, originatorId, contentHash, nftContract, nftTokenId);

        // Register the provenance claim and check the event.
        vm.expectEmit();
        emit ProvenanceRegistered({
            id: expectedId,
            originatorId: originatorId,
            registrarId: originatorId,
            contentHash: contentHash,
            nftContract: nftContract,
            nftTokenId: nftTokenId
        });

        vm.prank(custody);
        provenanceGateway.register(originatorId, contentHash, nftContract, nftTokenId);

        // Assert postconditions.
        _assertRegisterPostconditions(expectedId, originatorId, originatorId, contentHash, nftContract, nftTokenId);
    }

    function testFuzz_register_WhenOperatorIsCallerAndNftHolder(
        address custody,
        address operator,
        bytes32 contentHash,
        bytes32 nftContractSalt,
        uint256 nftTokenId,
        uint256 blockNumber
    ) public {
        // Bound inputs that need to be bound
        vm.assume(custody != address(0));
        vm.assume(operator != address(0));
        vm.assume(custody != operator);

        // Register the custody as an originator, and mint the NFT to the custody.
        uint256 originatorId = _register(custody, "username", operator);
        address nftContract = _createMockERC721(nftContractSalt);
        ERC721Mock(nftContract).mint(operator, nftTokenId);

        // Roll the block number forward to simulate the block number at the time of registration.
        vm.roll(blockNumber);

        // Assert preconditions.
        uint256 expectedId = 1;
        _assertRegisterPreconditions(expectedId, originatorId, contentHash, nftContract, nftTokenId);

        // Register the provenance claim and check the event.
        vm.expectEmit();
        emit ProvenanceRegistered({
            id: expectedId,
            originatorId: originatorId,
            registrarId: originatorId,
            contentHash: contentHash,
            nftContract: nftContract,
            nftTokenId: nftTokenId
        });

        vm.prank(operator);
        provenanceGateway.register(originatorId, contentHash, nftContract, nftTokenId);

        // Assert postconditions.
        _assertRegisterPostconditions(expectedId, originatorId, originatorId, contentHash, nftContract, nftTokenId);
    }

    function testFuzz_register_WhenOperatorIsCallerButCustodyIsNftHolder(
        address custody,
        address operator,
        bytes32 contentHash,
        bytes32 nftContractSalt,
        uint256 nftTokenId,
        uint256 blockNumber
    ) public {
        // Bound inputs that need to be bound
        vm.assume(custody != address(0));
        vm.assume(operator != address(0));
        vm.assume(custody != operator);

        // Register the custody as an originator, and mint the NFT to the custody.
        uint256 originatorId = _register(custody, "username", operator);
        address nftContract = _createMockERC721(nftContractSalt);
        ERC721Mock(nftContract).mint(custody, nftTokenId);

        // Roll the block number forward to simulate the block number at the time of registration.
        vm.roll(blockNumber);

        // Assert preconditions.
        uint256 expectedId = 1;
        _assertRegisterPreconditions(expectedId, originatorId, contentHash, nftContract, nftTokenId);

        // Register the provenance claim and check the event.
        vm.expectEmit();
        emit ProvenanceRegistered({
            id: expectedId,
            originatorId: originatorId,
            registrarId: originatorId,
            contentHash: contentHash,
            nftContract: nftContract,
            nftTokenId: nftTokenId
        });

        vm.prank(operator);
        provenanceGateway.register(originatorId, contentHash, nftContract, nftTokenId);

        // Assert postconditions.
        _assertRegisterPostconditions(expectedId, originatorId, originatorId, contentHash, nftContract, nftTokenId);
    }

    function testFuzz_register_WhenRegistrarIsDelegatedByCustody(
        address custody,
        address registrar,
        bytes32 contentHash,
        bytes32 nftContractSalt,
        uint256 nftTokenId,
        uint256 blockNumber
    ) public {
        // Bound inputs that need to be bound
        vm.assume(custody != address(0));
        vm.assume(registrar != address(0) && custody != registrar);

        // Register the custody and registrar addresses, and mint the NFT to the custody.
        uint256 originatorId = _register(custody, "username");
        uint256 registrarId = _register(registrar, "registrar");

        address nftContract = _createMockERC721(nftContractSalt);
        ERC721Mock(nftContract).mint(custody, nftTokenId);

        _delegateProvenanceRegistration(custody, registrar);

        // Roll the block number forward to simulate the block number at the time of registration.
        vm.roll(blockNumber);

        // Assert preconditions.
        uint256 expectedId = 1;
        _assertRegisterPreconditions(expectedId, originatorId, contentHash, nftContract, nftTokenId);

        // Register the provenance claim and check the event.
        vm.expectEmit();
        emit ProvenanceRegistered({
            id: expectedId,
            originatorId: originatorId,
            registrarId: registrarId,
            contentHash: contentHash,
            nftContract: nftContract,
            nftTokenId: nftTokenId
        });

        vm.prank(registrar);
        provenanceGateway.register(originatorId, contentHash, nftContract, nftTokenId);

        // Assert postconditions.
        _assertRegisterPostconditions(expectedId, originatorId, registrarId, contentHash, nftContract, nftTokenId);
    }

    function testFuzz_register_WhenRegistrarIsDelegatedByOperator(
        address custody,
        address operator,
        address registrar,
        bytes32 contentHash,
        bytes32 nftContractSalt,
        uint256 nftTokenId,
        uint256 blockNumber
    ) public {
        // Bound inputs that need to be bound
        // NOTE: For some reason, delegate.xyz doesn't seem to like delegations from the ECRecover address (address(1)), so include that in the vm.assume() check.
        vm.assume(custody != address(0));
        vm.assume(operator != address(0) && operator != address(1) && operator != custody);
        vm.assume(registrar != address(0) && custody != registrar && operator != registrar);

        // Register the custody and registrar addresses, and mint the NFT to the custody.
        uint256 originatorId = _register(custody, "username", operator);
        uint256 registrarId = _register(registrar, "registrar");

        address nftContract = _createMockERC721(nftContractSalt);
        ERC721Mock(nftContract).mint(custody, nftTokenId);

        _delegateProvenanceRegistration(operator, registrar);

        // Roll the block number forward to simulate the block number at the time of registration.
        vm.roll(blockNumber);

        // Assert preconditions.
        uint256 expectedId = 1;
        _assertRegisterPreconditions(expectedId, originatorId, contentHash, nftContract, nftTokenId);

        // Register the provenance claim and check the event.
        vm.expectEmit();
        emit ProvenanceRegistered({
            id: expectedId,
            originatorId: originatorId,
            registrarId: registrarId,
            contentHash: contentHash,
            nftContract: nftContract,
            nftTokenId: nftTokenId
        });

        vm.prank(registrar);
        provenanceGateway.register(originatorId, contentHash, nftContract, nftTokenId);

        // Assert postconditions.
        _assertRegisterPostconditions(expectedId, originatorId, registrarId, contentHash, nftContract, nftTokenId);
    }

    function testFuzz_register_WhenTwoUsersRegisterTheSameContentHash(
        address custody1,
        address custody2,
        bytes32 contentHash,
        bytes32 nftContractSalt,
        uint256 nftTokenId1,
        uint256 nftTokenId2,
        uint256 blockNumber
    ) public {
        // Bound inputs that need to be bound
        vm.assume(custody1 != address(0) && custody2 != address(0) && custody1 != custody2);
        vm.assume(nftTokenId1 != nftTokenId2);

        // Register the custody addresses as originators, and mint the NFTs to the custody.
        uint256 originatorId1 = _register(custody1, "username1");
        uint256 originatorId2 = _register(custody2, "username2");

        address nftContract = _createMockERC721(nftContractSalt);
        ERC721Mock(nftContract).mint(custody1, nftTokenId1);
        ERC721Mock(nftContract).mint(custody2, nftTokenId2);

        // Roll the block number forward to simulate the block number at the time of registration.
        vm.roll(blockNumber);

        // Assert preconditions.
        uint256 expectedId1 = 1;
        uint256 expectedId2 = 2;
        _assertRegisterPreconditions(expectedId1, originatorId1, contentHash, nftContract, nftTokenId1);
        _assertRegisterPreconditions(expectedId2, originatorId2, contentHash, nftContract, nftTokenId2);

        // Register the provenance claim and check the event.
        vm.expectEmit();
        emit ProvenanceRegistered({
            id: expectedId1,
            originatorId: originatorId1,
            registrarId: originatorId1,
            contentHash: contentHash,
            nftContract: nftContract,
            nftTokenId: nftTokenId1
        });

        vm.prank(custody1);
        provenanceGateway.register(originatorId1, contentHash, nftContract, nftTokenId1);
        _assertRegisterPostconditions(expectedId1, originatorId1, originatorId1, contentHash, nftContract, nftTokenId1);

        // Now register the same contentHash with a different originator, and it should work.
        vm.expectEmit();
        emit ProvenanceRegistered({
            id: expectedId2,
            originatorId: originatorId2,
            registrarId: originatorId2,
            contentHash: contentHash,
            nftContract: nftContract,
            nftTokenId: nftTokenId2
        });

        vm.prank(custody2);
        provenanceGateway.register(originatorId2, contentHash, nftContract, nftTokenId2);
        _assertRegisterPostconditions(expectedId2, originatorId2, originatorId2, contentHash, nftContract, nftTokenId2);
    }

    function testFuzz_register_RevertWhenProvenanceGatewayPaused(
        address custody,
        bytes32 contentHash,
        bytes32 nftContractSalt,
        uint256 nftTokenId
    ) public {
        // Bound inputs that need to be bound
        vm.assume(custody != address(0));

        // Register the custody as an originator, and mint the NFT to the custody.
        uint256 originatorId = _register(custody, "username");
        address nftContract = _createMockERC721(nftContractSalt);
        ERC721Mock(nftContract).mint(custody, nftTokenId);

        vm.prank(PROVENANCE_GATEWAY_OWNER);
        provenanceGateway.pause();

        vm.expectRevert(EnforcedPause.selector);
        vm.prank(custody);
        provenanceGateway.register(originatorId, contentHash, nftContract, nftTokenId);
    }

    function testFuzz_register_RevertWhenProvenanceRegistryPaused(
        address custody,
        bytes32 contentHash,
        bytes32 nftContractSalt,
        uint256 nftTokenId
    ) public {
        // Bound inputs that need to be bound
        vm.assume(custody != address(0));

        // Register the custody as an originator, and mint the NFT to the custody.
        uint256 originatorId = _register(custody, "username");
        address nftContract = _createMockERC721(nftContractSalt);
        ERC721Mock(nftContract).mint(custody, nftTokenId);

        vm.prank(PROVENANCE_REGISTRY_OWNER);
        provenanceRegistry.pause();

        vm.expectRevert(EnforcedPause.selector);
        vm.prank(custody);
        provenanceGateway.register(originatorId, contentHash, nftContract, nftTokenId);
    }

    function testFuzz_register_RevertWhenOriginatorDoesNotExist(
        address custody,
        uint256 originatorId,
        bytes32 contentHash,
        bytes32 nftContractSalt,
        uint256 nftTokenId
    ) public {
        // Bound inputs that need to be bound
        vm.assume(custody != address(0));

        // Purposely don't register the custody as an originator.
        address nftContract = _createMockERC721(nftContractSalt);
        ERC721Mock(nftContract).mint(custody, nftTokenId);

        vm.expectRevert(OriginatorDoesNotExist.selector);
        vm.prank(custody);
        provenanceGateway.register(originatorId, contentHash, nftContract, nftTokenId);
    }

    function testFuzz_register_RevertWhenRegistrarDoesNotExist(
        address custody,
        address registrar,
        bytes32 contentHash,
        bytes32 nftContractSalt,
        uint256 nftTokenId
    ) public {
        // Bound inputs that need to be bound
        vm.assume(custody != address(0));
        vm.assume(registrar != address(0) && registrar != custody);

        // Purposely don't register the custody as an originator.
        uint256 originatorId = _register(custody, "username");
        address nftContract = _createMockERC721(nftContractSalt);
        ERC721Mock(nftContract).mint(custody, nftTokenId);

        vm.expectRevert(RegistrarDoesNotExist.selector);
        vm.prank(registrar);
        provenanceGateway.register(originatorId, contentHash, nftContract, nftTokenId);
    }

    function testFuzz_register_RevertWhenNftNotOwnedByOriginator(
        address custody,
        address nftOwner,
        bytes32 contentHash,
        bytes32 nftContractSalt,
        uint256 nftTokenId
    ) public {
        // Bound inputs that need to be bound
        vm.assume(custody != address(0));
        vm.assume(nftOwner != address(0) && nftOwner != custody);

        // Register the custody as an originator, and mint the NFT to the nftOwner.
        uint256 originatorId = _register(custody, "username");
        address nftContract = _createMockERC721(nftContractSalt);
        ERC721Mock(nftContract).mint(nftOwner, nftTokenId);

        vm.expectRevert(NftNotOwnedByOriginator.selector);
        vm.prank(custody);
        provenanceGateway.register(originatorId, contentHash, nftContract, nftTokenId);
    }

    function testFuzz_register_RevertWhenNftTokenAlreadyUsed(
        address custody,
        bytes32 contentHash1,
        bytes32 contentHash2,
        bytes32 nftContractSalt,
        uint256 nftTokenId
    ) public {
        // Bound inputs that need to be bound
        vm.assume(custody != address(0));

        // Register the custody as an originator, and mint the NFT to the nftOwner.
        uint256 originatorId = _register(custody, "username");
        address nftContract = _createMockERC721(nftContractSalt);
        ERC721Mock(nftContract).mint(custody, nftTokenId);

        vm.prank(custody);
        uint256 id = provenanceGateway.register(originatorId, contentHash1, nftContract, nftTokenId);
        _assertRegisterPostconditions(id, originatorId, originatorId, contentHash1, nftContract, nftTokenId);

        // Attempt to register the same NFT token with a different content hash.
        vm.expectRevert(NftTokenAlreadyUsed.selector);
        vm.prank(custody);
        provenanceGateway.register(originatorId, contentHash2, nftContract, nftTokenId);
    }

    function testFuzz_register_RevertWhenContentHashAlreadyRegistered(
        address custody,
        bytes32 contentHash,
        bytes32 nftContractSalt,
        uint256 nftTokenId1,
        uint256 nftTokenId2
    ) public {
        // Bound inputs that need to be bound
        vm.assume(custody != address(0));
        vm.assume(nftTokenId1 != nftTokenId2);

        // Register the custody as an originator, and mint the NFT to the nftOwner.
        uint256 originatorId = _register(custody, "username");
        address nftContract = _createMockERC721(nftContractSalt);
        ERC721Mock(nftContract).mint(custody, nftTokenId1);
        ERC721Mock(nftContract).mint(custody, nftTokenId2);

        vm.prank(custody);
        uint256 id = provenanceGateway.register(originatorId, contentHash, nftContract, nftTokenId1);
        _assertRegisterPostconditions(id, originatorId, originatorId, contentHash, nftContract, nftTokenId1);

        // The same user will attempt to register a contentHash that has already been registered.
        vm.expectRevert(ContentHashAlreadyRegistered.selector);
        vm.prank(custody);
        provenanceGateway.register(originatorId, contentHash, nftContract, nftTokenId2);
    }

    /// @dev Registrar isn't delegated, so doesn't have permission to register on behalf of the originator.
    function testFuzz_register_RevertWhenUnauthorized(
        address custody,
        address registrar,
        bytes32 contentHash,
        bytes32 nftContractSalt,
        uint256 nftTokenId
    ) public {
        // Bound inputs that need to be bound
        vm.assume(custody != address(0));
        vm.assume(registrar != address(0) && registrar != custody);

        // Register the custody as an originator, and mint the NFT to the custody.
        uint256 originatorId = _register(custody, "username");
        _register(registrar, "registrar");

        address nftContract = _createMockERC721(nftContractSalt);
        ERC721Mock(nftContract).mint(custody, nftTokenId);

        // Even though the registrar has an ID in the system, its not set up for delegation from the originator, so this will fail.
        vm.expectRevert(Unauthorized.selector);
        vm.prank(registrar);
        provenanceGateway.register(originatorId, contentHash, nftContract, nftTokenId);
    }

    // TODO:
    // =============================================================
    //                      registerFor()
    // =============================================================

    // TODO: Could breakdown registerFor even more like I broke down register().
    // testFuzz_registerFor();
    // testFuzz_registerFor_RevertWhenPaused();
    // testFuzz_registerFor_RevertWhenOriginatorDoesNotExist();
    // testFuzz_registerFor_RevertWhenRegistrarDoesNotExist();
    // testFuzz_registerFor_RevertWhenNftNotOwnedByOriginator();
    // testFuzz_registerFor_RevertWhenNftTokenAlreadyUsed();
    // testFuzz_registerFor_RevertWhenContentHashAlreadyRegistered();
    // testFuzz_registerFor_RevertWhenInvalidSignature();
    // testFuzz_registerFor_RevertWhenUnauthorized();

    // =============================================================
    //                        ASSERTION HELPERS
    // =============================================================

    function _assertRegisterPreconditions(
        uint256 id,
        uint256 originatorId,
        bytes32 contentHash,
        address nftContract,
        uint256 nftTokenId
    ) internal view {
        assertEq(provenanceRegistry.idCounter(), 0);

        assertEq(provenanceRegistry.provenanceClaimIdOfNftToken(nftContract, nftTokenId), 0);
        assertEq(provenanceRegistry.provenanceClaimIdOfOriginatorAndHash(originatorId, contentHash), 0);

        IProvenanceRegistry.ProvenanceClaim memory provenanceClaim = provenanceRegistry.provenanceClaim(id);
        assertEq(provenanceClaim.originatorId, 0);
        assertEq(provenanceClaim.registrarId, 0);
        assertEq(provenanceClaim.contentHash, 0);
        assertEq(provenanceClaim.nftContract, address(0));
        assertEq(provenanceClaim.nftTokenId, 0);
        assertEq(provenanceClaim.blockNumber, 0);
    }

    function _assertRegisterPostconditions(
        uint256 id,
        uint256 originatorId,
        uint256 registrarId,
        bytes32 contentHash,
        address nftContract,
        uint256 nftTokenId
    ) internal view {
        assertEq(provenanceRegistry.idCounter(), id);

        assertEq(provenanceRegistry.provenanceClaimIdOfNftToken(nftContract, nftTokenId), id);
        assertEq(provenanceRegistry.provenanceClaimIdOfOriginatorAndHash(originatorId, contentHash), id);

        IProvenanceRegistry.ProvenanceClaim memory provenanceClaim = provenanceRegistry.provenanceClaim(id);
        assertEq(provenanceClaim.originatorId, originatorId);
        assertEq(provenanceClaim.registrarId, registrarId);
        assertEq(provenanceClaim.contentHash, contentHash);
        assertEq(provenanceClaim.nftContract, nftContract);
        assertEq(provenanceClaim.nftTokenId, nftTokenId);

        // NOTE: Where appropriate, blockNumber is fuzzed and set via vm.roll().
        //       Might be cleaner to pass in blockNumber as a param here, but this is sufficient for now.
        assertEq(provenanceClaim.blockNumber, block.number);
    }

    // TODO:
    // =============================================================
    //                        SIGNATURE HELPERS
    // =============================================================
}
