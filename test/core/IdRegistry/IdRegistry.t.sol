// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ProvenanceTest} from "../ProvenanceTest.sol";

import {IdRegistry} from "../../../src/core/IdRegistry.sol";

contract IdRegistryTest is ProvenanceTest {
    // =============================================================
    //                           EVENTS
    // =============================================================

    event Transfer(address indexed from, address indexed to, uint256 indexed id);
    event RecoveryAddressChanged(uint256 indexed id, address indexed recovery);
    event Recovered(uint256 indexed id, address indexed to);

    event IdGatewaySet(address oldIdGateway, address newIdGateway);
    event IdGatewayFrozen(address idGateway);
    event UsernameGatewaySet(address oldUsernameGateway, address newUsernameGateway);
    event UsernameGatewayFrozen(address usernameGateway);
    event DelegateRegistrySet(address oldDelegateRegistry, address newDelegateRegistry);
    event DelegateRegistryFrozen(address delegateRegistry);

    // =============================================================
    //                          ERRORS
    // =============================================================

    error OnlyIdGateway();
    error OnlyUsernameGateway();

    error CustodyAlreadyRegistered();

    error OnlyCustody();
    error OnlyRecovery();

    error Frozen();
    error HasNoId();

    // =============================================================
    //                    Constants / Immutables
    // =============================================================

    function test_name() public view {
        assertEq(idRegistry.name(), "RoyalProtocol ID");
    }

    function test_VERSION() public view {
        assertEq(idRegistry.VERSION(), "2024-08-22");
    }

    function test_TRANSFER_TYPEHASH() public view {
        assertEq(
            idRegistry.TRANSFER_TYPEHASH(), keccak256("Transfer(uint256 id,address to,uint256 nonce,uint256 deadline)")
        );
    }

    function test_RECOVER_TYPEHASH() public view {
        assertEq(
            idRegistry.RECOVER_TYPEHASH(), keccak256("Recover(uint256 id,address to,uint256 nonce,uint256 deadline)")
        );
    }

    function test_CHANGE_RECOVERY_TYPEHASH() public view {
        assertEq(
            idRegistry.CHANGE_RECOVERY_TYPEHASH(),
            keccak256("ChangeRecovery(uint256 id,address newRecovery,uint256 nonce,uint256 deadline)")
        );
    }

    function test_GRACE_PERIOD() public view {
        assertEq(idRegistry.GRACE_PERIOD(), 24 hours);
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
        ) = idRegistry.eip712Domain();

        assertEq(fields, hex"0f");
        assertEq(name, "RoyalProtocol_IdRegistry");
        assertEq(version, "1");
        assertEq(chainId, block.chainid);
        assertEq(verifyingContract, address(idRegistry));
        assertEq(salt, bytes32(0));
        assertEq(extensions.length, 0);
    }

    // TODO: Where are the mappings tested? In the IdGateway tests?

    // =============================================================
    //                        constructor()
    // =============================================================

    function test_PausedWhenDeployed() public {
        idRegistry = new IdRegistry(ID_REGISTRY_MIGRATOR, ID_REGISTRY_OWNER);
        assertEq(idRegistry.paused(), true);
    }

    function test_OwnerSetWhenDeployed() public view {
        assertEq(idRegistry.owner(), ID_REGISTRY_OWNER);
    }

    function test_MigratorSetWhenDeployed() public view {
        assertEq(idRegistry.migrator(), ID_REGISTRY_MIGRATOR);
    }

    function test_delegateRegistry_DefaultsToV2() public view {
        address delegateRegistryV2 = 0x00000000000000447e69651d841bD8D104Bed493;
        assertEq(idRegistry.delegateRegistry(), address(delegateRegistryV2));
    }

    // =============================================================
    //                        Receiving ETH
    // =============================================================

    function testFuzz_RevertWhenReceivingDirectPayment(address sender, uint256 amount) public {
        vm.deal(sender, amount);
        vm.expectRevert();
        vm.prank(sender);
        payable(address(idRegistry)).transfer(amount);
    }

    // TODO: Is this sufficiently tested by the IdGateway tests?
    // =============================================================
    //                        register()
    // =============================================================

    function testFuzz_register_RevertWhenCalledByNonIdGateway(
        address caller,
        address custody,
        uint8 usernameLength_,
        address recovery
    ) public {
        // Bound inputs that need to be bound.
        vm.assume(caller != address(idGateway));
        vm.assume(custody != address(0));
        uint256 usernameLength = _boundUsernameLength(usernameLength_);
        string memory username = _getRandomValidUniqueUsername(usernameLength);

        vm.expectRevert(OnlyIdGateway.selector);
        vm.prank(caller);
        idRegistry.register(custody, username, recovery);
    }

    // =============================================================
    //                        transfer()
    // =============================================================

    function testFuzz_transfer(address from, uint8 usernameLength_, address recovery, uint256 toPk_, uint40 deadline_)
        public
    {
        // Bound inputs that need to be bound.
        vm.assume(from != address(0));
        uint256 usernameLength = _boundUsernameLength(usernameLength_);
        string memory username = _getRandomValidUniqueUsername(usernameLength);

        uint256 toPk = _boundPk(toPk_);
        address to = vm.addr(toPk);
        vm.assume(to != from);

        uint256 deadline = _boundDeadline(deadline_);

        // Register the ID that we're going to transfer.
        uint256 id = _register(from, username, recovery);

        // Check preconditions.
        _assertTransferPreconditions(id, from, to, username, recovery);

        // Get signature from `to` address authorizing receiving the transfer, and transfer the ID.
        bytes memory sig = _signTransfer(toPk, id, to, deadline);

        vm.expectEmit();
        emit Transfer(from, to, id);
        vm.prank(from);
        idRegistry.transfer(to, deadline, sig);

        // Check that the ID was transferred.
        _assertTransferPostconditions(id, from, to, username, recovery);
    }

    function testFuzz_transfer_RevertWhenIdRegistryPaused(
        address from,
        uint8 usernameLength_,
        address recovery,
        uint256 toPk_,
        uint40 deadline_
    ) public {
        // Bound inputs that need to be bound.
        vm.assume(from != address(0));
        uint256 usernameLength = _boundUsernameLength(usernameLength_);
        string memory username = _getRandomValidUniqueUsername(usernameLength);

        uint256 toPk = _boundPk(toPk_);
        address to = vm.addr(toPk);
        vm.assume(to != from);

        uint256 deadline = _boundDeadline(deadline_);

        // Register the ID that we're going to transfer.
        uint256 id = _register(from, username, recovery);

        // Check preconditions.
        _assertTransferPreconditions(id, from, to, username, recovery);

        // Pause the IdRegistry.
        vm.prank(ID_REGISTRY_OWNER);
        idRegistry.pause();

        // Get signature from `to` address authorizing receiving the transfer, and revert as expected.
        bytes memory sig = _signTransfer(toPk, id, to, deadline);

        // Revert as expected.
        vm.expectRevert(EnforcedPause.selector);
        vm.prank(from);
        idRegistry.transfer(to, deadline, sig);
    }

    function testFuzz_transfer_RevertWhenCalledByNonCustody(
        address caller,
        address from,
        uint8 usernameLength_,
        address recovery,
        uint256 toPk_,
        uint40 deadline_
    ) public {
        // Bound inputs that need to be bound.
        vm.assume(caller != from && caller != address(0));
        vm.assume(from != address(0));
        uint256 usernameLength = _boundUsernameLength(usernameLength_);
        string memory username = _getRandomValidUniqueUsername(usernameLength);

        uint256 toPk = _boundPk(toPk_);
        address to = vm.addr(toPk);
        vm.assume(to != from);

        uint256 deadline = _boundDeadline(deadline_);

        // Register the ID that we're going to transfer.
        uint256 id = _register(from, username, recovery);

        // Check preconditions.
        _assertTransferPreconditions(id, from, to, username, recovery);

        // Get signature from `to` address authorizing receiving the transfer, and revert as expected.
        bytes memory sig = _signTransfer(toPk, id, to, deadline);
        vm.expectRevert(OnlyCustody.selector);
        vm.prank(caller);
        idRegistry.transfer(to, deadline, sig);
    }

    function testFuzz_transfer_RevertWhenToAddressAlreadyHasId(
        address from,
        uint8 usernameLength_,
        address recovery,
        uint256 toPk_,
        uint40 deadline_
    ) public {
        // Bound inputs that need to be bound.
        vm.assume(from != address(0));

        // Reserve "to" username
        _registeredUsernames["to"] = true;

        uint256 usernameLength = _boundUsernameLength(usernameLength_);
        string memory username = _getRandomValidUniqueUsername(usernameLength);

        uint256 toPk = _boundPk(toPk_);
        address to = vm.addr(toPk);
        vm.assume(to != from);

        uint256 deadline = _boundDeadline(deadline_);

        // Register the ID that we're going to transfer.
        uint256 fromId = _register(from, username, recovery);

        // Register the ID that the `to` address already has.
        _register(to, "to");

        // Get signature from `to` address authorizing receiving the transfer, and revert as expected.
        bytes memory sig = _signTransfer(toPk, fromId, to, deadline);
        vm.expectRevert(CustodyAlreadyRegistered.selector);
        vm.prank(from);
        idRegistry.transfer(to, deadline, sig);
    }

    // TODO: testFuzz_transfer_RevertWhenToDeadlineExpired
    // TODO: testFuzz_transfer_RevertWhenToNonceInvalid
    // TODO: testFuzz_transfer_RevertWhenToSignerInvalid

    // =============================================================
    //                        transferFor()
    // =============================================================

    function testFuzz_transferFor(
        address caller,
        uint256 fromPk_,
        uint8 usernameLength_,
        address recovery,
        uint40 fromDeadline_,
        uint256 toPk_,
        uint40 toDeadline_
    ) public {
        // Bound inputs that need to be bound.
        uint256 fromPk = _boundPk(fromPk_);
        address from = vm.addr(fromPk);

        uint256 usernameLength = _boundUsernameLength(usernameLength_);
        string memory username = _getRandomValidUniqueUsername(usernameLength);

        uint256 toPk = _boundPk(toPk_);
        address to = vm.addr(toPk);
        vm.assume(to != from);

        uint256 fromDeadline = _boundDeadline(fromDeadline_);
        uint256 toDeadline = _boundDeadline(toDeadline_);

        // Assert Preconditions
        uint256 id = _register(from, username, recovery);
        _assertTransferPreconditions(id, from, to, username, recovery);

        // Get signature from `to` address authorizing receiving the transfer, and transfer the ID.
        bytes memory fromSig = _signTransfer(fromPk, id, to, fromDeadline);
        bytes memory toSig = _signTransfer(toPk, id, to, toDeadline);

        vm.expectEmit();
        emit Transfer(from, to, id);
        vm.prank(caller);
        idRegistry.transferFor(id, to, fromDeadline, fromSig, toDeadline, toSig);

        _assertTransferPostconditions(id, from, to, username, recovery);
    }

    function testFuzz_transferFor_RevertWhenIdRegistryPaused(
        address caller,
        uint256 fromPk_,
        uint8 usernameLength_,
        uint40 fromDeadline_,
        uint256 toPk_,
        uint40 toDeadline_
    ) public {
        // Bound inputs that need to be bound.
        uint256 fromPk = _boundPk(fromPk_);
        address from = vm.addr(fromPk);

        uint256 usernameLength = _boundUsernameLength(usernameLength_);
        string memory username = _getRandomValidUniqueUsername(usernameLength);

        uint256 toPk = _boundPk(toPk_);
        address to = vm.addr(toPk);
        vm.assume(to != from);

        uint256 fromDeadline = _boundDeadline(fromDeadline_);
        uint256 toDeadline = _boundDeadline(toDeadline_);

        // Assert Preconditions
        uint256 id = _register(from, username);

        // Pause the IdRegistry.
        vm.prank(ID_REGISTRY_OWNER);
        idRegistry.pause();

        // Get signature from `to` address authorizing receiving the transfer, and transfer the ID.
        bytes memory fromSig = _signTransfer(fromPk, id, to, fromDeadline);
        bytes memory toSig = _signTransfer(toPk, id, to, toDeadline);

        vm.expectRevert(EnforcedPause.selector);
        vm.prank(caller);
        idRegistry.transferFor(id, to, fromDeadline, fromSig, toDeadline, toSig);
    }

    function testFuzz_transferFor_RevertWhenToAddressAlreadyHasAnId(
        address caller,
        uint256 fromPk_,
        uint8 usernameLength_,
        uint40 fromDeadline_,
        uint256 toPk_,
        uint40 toDeadline_
    ) public {
        // Bound inputs that need to be bound.
        uint256 fromPk = _boundPk(fromPk_);
        address from = vm.addr(fromPk);

        // Reserve "to" username
        _registeredUsernames["to"] = true;

        uint256 usernameLength = _boundUsernameLength(usernameLength_);
        string memory username = _getRandomValidUniqueUsername(usernameLength);

        uint256 toPk = _boundPk(toPk_);
        address to = vm.addr(toPk);
        vm.assume(to != from);

        uint256 fromDeadline = _boundDeadline(fromDeadline_);
        uint256 toDeadline = _boundDeadline(toDeadline_);

        // Assert Preconditions
        uint256 fromId = _register(from, username);
        _register(to, "to");

        // Get signature from `to` address authorizing receiving the transfer, and transfer the ID.
        bytes memory fromSig = _signTransfer(fromPk, fromId, to, fromDeadline);
        bytes memory toSig = _signTransfer(toPk, fromId, to, toDeadline);

        vm.expectRevert(CustodyAlreadyRegistered.selector);
        vm.prank(caller);
        idRegistry.transferFor(fromId, to, fromDeadline, fromSig, toDeadline, toSig);
    }

    // TODO: testFuzz_transferUsername_RevertWhenFromDeadlineExpired
    // TODO: testFuzz_transferUsername_RevertWhenFromNonceInvalid
    // TODO: testFuzz_transferUsername_RevertWhenFromSignerInvalid
    // TODO: testFuzz_transferUsername_RevertWhenToDeadlineExpired
    // TODO: testFuzz_transferUsername_RevertWhenToNonceInvalid
    // TODO: testFuzz_transferUsername_RevertWhenToSignerInvalid

    // =============================================================
    //              transferAndClearRecovery()
    // =============================================================

    function testFuzz_transferAndClearRecovery(address from, uint8 usernameLength_, uint256 toPk_, uint40 deadline_)
        public
    {
        // Bound inputs that need to be bound.
        vm.assume(from != address(0));
        uint256 usernameLength = _boundUsernameLength(usernameLength_);
        string memory username = _getRandomValidUniqueUsername(usernameLength);

        uint256 toPk = _boundPk(toPk_);
        address to = vm.addr(toPk);
        vm.assume(to != from);

        uint256 deadline = _boundDeadline(deadline_);

        // Register the ID that we're going to transfer.
        uint256 id = _register(from, username);

        // Check preconditions.
        _assertTransferAndChangePreconditions(id, from, username, to);

        // Get signature from `to` address authorizing receiving the transfer, and transfer the ID.
        bytes memory sig = _signTransfer(toPk, id, to, deadline);

        vm.expectEmit();
        emit Transfer(from, to, id);
        vm.expectEmit();
        emit RecoveryAddressChanged(id, address(0));
        vm.prank(from);
        idRegistry.transferAndClearRecovery(to, deadline, sig);

        // Check that the ID was transferred.
        _assertTransferAndChangePostconditions(id, from, username, to, address(0));
    }

    function testFuzz_transferAndClearRecovery_RevertWhenIdRegistryPaused(
        address from,
        uint8 usernameLength_,
        uint256 toPk_,
        uint40 deadline_
    ) public {
        // Bound inputs that need to be bound.
        vm.assume(from != address(0));
        uint256 usernameLength = _boundUsernameLength(usernameLength_);
        string memory username = _getRandomValidUniqueUsername(usernameLength);

        uint256 toPk = _boundPk(toPk_);
        address to = vm.addr(toPk);
        vm.assume(to != from);

        uint256 deadline = _boundDeadline(deadline_);

        // Register the ID that we're going to transfer.
        uint256 id = _register(from, username);

        // Check preconditions.
        _assertTransferAndChangePreconditions(id, from, username, to);

        // Pause IdRegistry
        vm.prank(ID_REGISTRY_OWNER);
        idRegistry.pause();

        // Get signature from `to` address authorizing receiving the transfer, and transfer the ID.
        bytes memory sig = _signTransfer(toPk, id, to, deadline);

        vm.expectRevert(EnforcedPause.selector);
        vm.prank(from);
        idRegistry.transferAndClearRecovery(to, deadline, sig);
    }

    function testFuzz_transferAndClearRecovery_RevertWhenCalledByNonCustody(
        address caller,
        address from,
        uint8 usernameLength_,
        uint256 toPk_,
        uint40 deadline_
    ) public {
        // Bound inputs that need to be bound.
        vm.assume(from != address(0));
        uint256 usernameLength = _boundUsernameLength(usernameLength_);
        string memory username = _getRandomValidUniqueUsername(usernameLength);

        uint256 toPk = _boundPk(toPk_);
        address to = vm.addr(toPk);
        vm.assume(to != from);

        vm.assume(caller != from && caller != address(0));

        uint256 deadline = _boundDeadline(deadline_);

        // Register the ID that we're going to transfer.
        uint256 id = _register(from, username);

        // Check preconditions.
        _assertTransferAndChangePreconditions(id, from, username, to);

        // Get signature from `to` address authorizing receiving the transfer, and transfer the ID.
        bytes memory sig = _signTransfer(toPk, id, to, deadline);
        vm.expectRevert(OnlyCustody.selector);
        vm.prank(caller);
        idRegistry.transferAndClearRecovery(to, deadline, sig);
    }

    function testFuzz_transferAndClearRecovery_RevertWhenToAddressAlreadyHasId(
        address from,
        uint8 usernameLength_,
        uint256 toPk_,
        uint40 deadline_
    ) public {
        // Bound inputs that need to be bound.
        vm.assume(from != address(0));

        // Reserve "to" username
        _registeredUsernames["to"] = true;

        uint256 usernameLength = _boundUsernameLength(usernameLength_);
        string memory username = _getRandomValidUniqueUsername(usernameLength);

        uint256 toPk = _boundPk(toPk_);
        address to = vm.addr(toPk);
        vm.assume(to != from);

        uint256 deadline = _boundDeadline(deadline_);

        // Register the ID that we're going to transfer.
        uint256 fromId = _register(from, username);

        // Register the ID that the `to` address already has.
        _register(to, "to");

        // Get signature from `to` address authorizing receiving the transfer, and revert as expected.
        bytes memory sig = _signTransfer(toPk, fromId, to, deadline);
        vm.expectRevert(CustodyAlreadyRegistered.selector);
        vm.prank(from);
        idRegistry.transferAndClearRecovery(to, deadline, sig);
    }

    // TODO: testFuzz_transferAndClearRecovery_RevertWhenToDeadlineExpired
    // TODO: testFuzz_transferAndClearRecovery_RevertWhenToNonceInvalid
    // TODO: testFuzz_transferAndClearRecovery_RevertWhenToSignerInvalid

    // TODO:
    // =============================================================
    //              transferAndClearRecoveryFor()
    // =============================================================

    // TODO: Tested sufficiently by UsernameGateway?
    // =============================================================
    //                      unsafeTransferUsername()
    // =============================================================

    function testFuzz_unsafeTransferUsername_RevertWhenCalledByNonUsernameGateway(
        address caller,
        address from,
        address to,
        uint8 initialFromUsernameLength_,
        uint8 newFromUsernameLength_,
        uint8 initialToUsernameLength_
    ) public {
        // Bound inputs that need to be bound.
        vm.assume(caller != address(usernameGateway));
        vm.assume(from != address(0));
        vm.assume(to != address(0));
        vm.assume(from != to);

        uint256 initialFromUsernameLength = _boundUsernameLength(initialFromUsernameLength_);
        string memory initialFromUsername = _getRandomValidUniqueUsername(initialFromUsernameLength);
        uint256 newFromUsernameLength = _boundUsernameLength(newFromUsernameLength_);
        string memory newFromUsername = _getRandomValidUniqueUsername(newFromUsernameLength);
        uint256 initialToUsernameLength = _boundUsernameLength(initialToUsernameLength_);
        string memory initialToUsername = _getRandomValidUniqueUsername(initialToUsernameLength);

        // Register the IDs that we're going to transfer usernames between
        uint256 fromId = _register(from, initialFromUsername);
        uint256 toId = _register(to, initialToUsername);

        vm.expectRevert(OnlyUsernameGateway.selector);
        vm.prank(caller);
        idRegistry.unsafeTransferUsername(fromId, toId, newFromUsername);
    }

    // TODO: Tested sufficiently by UsernameGateway?
    // =============================================================
    //                      unsafeChangeUsername()
    // =============================================================

    function testFuzz_unsafeChangeUsername_RevertWhenCalledByNonUsernameGateway(
        address caller,
        address custody,
        uint8 initialUsernameLength_,
        uint8 newUsernameLength_
    ) public {
        // Bound inputs that need to be bound.
        vm.assume(caller != address(usernameGateway));
        vm.assume(custody != address(0));

        uint256 initialUsernameLength = _boundUsernameLength(initialUsernameLength_);
        string memory initialUsername = _getRandomValidUniqueUsername(initialUsernameLength);
        uint256 newUsernameLength = _boundUsernameLength(newUsernameLength_);
        string memory newUsername = _getRandomValidUniqueUsername(newUsernameLength);

        // Register the IDs that we're going to transfer usernames between
        uint256 id = _register(custody, initialUsername);

        vm.expectRevert(OnlyUsernameGateway.selector);
        vm.prank(caller);
        idRegistry.unsafeChangeUsername(id, newUsername);
    }

    // TODO:
    // =============================================================
    //                      changeRecovery()
    // =============================================================

    // TODO:
    // =============================================================
    //                      changeRecoveryFor()
    // =============================================================

    // TODO:
    // =============================================================
    //                      recover()
    // =============================================================

    function testFuzz_recover(address from, uint8 usernameLength_, address recovery, uint256 toPk_, uint40 deadline_)
        public
    {
        // Bound inputs that need to be bound.
        vm.assume(from != address(0));
        uint256 usernameLength = _boundUsernameLength(usernameLength_);
        string memory username = _getRandomValidUniqueUsername(usernameLength);

        uint256 toPk = _boundPk(toPk_);
        address to = vm.addr(toPk);
        vm.assume(to != from);

        uint256 deadline = _boundDeadline(deadline_);

        // Register the ID that we're going to recover.
        uint256 id = _register(from, username, recovery);

        // Check preconditions. (Recovery is basically a transfer)
        _assertTransferPreconditions(id, from, to, username, recovery);

        // Get signature from `to` address authorizing receiving the transfer, and transfer the ID.
        bytes memory sig = _signRecover(toPk, id, to, deadline);

        // Prank recovery address to sign the recovery, and recover the ID.
        vm.expectEmit();
        emit Transfer(from, to, id);
        vm.expectEmit();
        emit Recovered(id, to);

        vm.prank(recovery);
        idRegistry.recover(id, to, deadline, sig);

        // Check that the ID was transferred.
        _assertTransferPostconditions(id, from, to, username, recovery);
    }

    // TODO: Way more recover tests, not just the golden path.
    // TODO:
    // =============================================================
    //                      recoverFor()
    // =============================================================

    // =============================================================
    //                      Permissioned Actions
    // =============================================================
    // TODO: setIdGateway()
    // TODO: freezeIdGateway()
    // TODO: setUsernameGateway()
    // TODO: freezeUsernameGateway()
    // TODO: setDelegateRegistry()
    // TODO: freezeDelegateRegistry()

    // TODO: Only check the onlyMigrator modifier here.
    // Separate test file for the actual migration functionality.
    // =============================================================
    //                      Migration
    // =============================================================

    // =============================================================
    //                      View Functions
    // =============================================================

    function testFuzz_getUserById(address custody, uint8 usernameLength_, address recovery) public {
        // Bound inputs that need to be bound.
        vm.assume(custody != address(0));
        uint256 usernameLength = _boundUsernameLength(usernameLength_);
        string memory username = _getRandomValidUniqueUsername(usernameLength);

        // Register the ID that we're going to recover.
        uint256 id = _register(custody, username, recovery);

        // Get the user by ID and check the results.
        IdRegistry.User memory user = idRegistry.getUserById(id);
        assertEq(user.custody, custody);
        assertEq(user.username, username);
        assertEq(user.recovery, recovery);
    }

    function testFuzz_getUserById_RevertWhenIdDoesNotExist(uint256 id) public {
        vm.expectRevert(HasNoId.selector);
        idRegistry.getUserById(id);
    }

    function testFuzz_getIdByUsername(address custody, uint8 usernameLength_, address recovery) public {
        // Bound inputs that need to be bound.
        vm.assume(custody != address(0));
        uint256 usernameLength = _boundUsernameLength(usernameLength_);
        string memory username = _getRandomValidUniqueUsername(usernameLength);

        // Register the ID that we're going to recover.
        uint256 id = _register(custody, username, recovery);

        // Get the user by ID and check the results.
        uint256 id_ = idRegistry.getIdByUsername(username);
        assertEq(id_, id);
    }

    function testFuzz_getIdByUsername_RevertWhenUsernameDoesNotExist(uint8 usernameLength_) public {
        uint256 usernameLength = _boundUsernameLength(usernameLength_);
        string memory username = _getRandomValidUniqueUsername(usernameLength);

        vm.expectRevert(HasNoId.selector);
        idRegistry.getIdByUsername(username);
    }

    function testFuzz_getUserByAddress(address custody, uint8 usernameLength_, address recovery) public {
        // Bound inputs that need to be bound.
        vm.assume(custody != address(0));
        uint256 usernameLength = _boundUsernameLength(usernameLength_);
        string memory username = _getRandomValidUniqueUsername(usernameLength);

        // Register the ID that we're going to recover.
        uint256 id = _register(custody, username, recovery);

        // Get the user by ID and check the results.
        IdRegistry.User memory user = idRegistry.getUserByAddress(custody);
        assertEq(user.id, id);
        assertEq(user.custody, custody);
        assertEq(user.username, username);
        assertEq(user.recovery, recovery);
    }

    function testFuzz_getUserByAddress_RevertWhenAddressDoesNotExist(address custody) public {
        vm.expectRevert(HasNoId.selector);
        idRegistry.getUserByAddress(custody);
    }

    function testFuzz_getUserByUsername(address custody, uint8 usernameLength_, address recovery) public {
        // Bound inputs that need to be bound.
        vm.assume(custody != address(0));
        uint256 usernameLength = _boundUsernameLength(usernameLength_);
        string memory username = _getRandomValidUniqueUsername(usernameLength);

        // Register the ID that we're going to recover.
        uint256 id = _register(custody, username, recovery);

        // Get the user by ID and check the results.
        IdRegistry.User memory user = idRegistry.getUserByUsername(username);
        assertEq(user.id, id);
        assertEq(user.custody, custody);
        assertEq(user.username, username);
        assertEq(user.recovery, recovery);
    }

    function testFuzz_getUserByUsername_RevertWhenUsernameDoesNotExist(uint8 usernameLength_) public {
        uint256 usernameLength = _boundUsernameLength(usernameLength_);
        string memory username = _getRandomValidUniqueUsername(usernameLength);

        vm.expectRevert(HasNoId.selector);
        idRegistry.getUserByUsername(username);
    }

    // TODO:
    // =============================================================
    //                      canAct()
    // =============================================================

    // =============================================================
    //                      Signature Helpers - View Fns
    // =============================================================

    // TODO: verifyCustodySignature()
    // TODO: verifyIdSignature()

    // =============================================================
    //                        ASSERTION HELPERS
    // =============================================================

    // TODO: Doc
    function _assertTransferPreconditions(
        uint256 id,
        address from,
        address to,
        string memory username,
        address recovery
    ) internal view {
        assertEq(idRegistry.idOf(from), id);
        assertEq(idRegistry.custodyOf(id), from);

        assertEq(idRegistry.idOf(to), 0);

        assertEq(idRegistry.usernameOf(id), username);
        assertEq(idRegistry.getIdByUsername(username), id);
        assertEq(idRegistry.recoveryOf(id), recovery);
    }

    // TODO: Doc
    function _assertTransferPostconditions(
        uint256 id,
        address from,
        address to,
        string memory username,
        address recovery
    ) internal view {
        assertEq(idRegistry.idOf(from), 0);

        assertEq(idRegistry.custodyOf(id), to);
        assertEq(idRegistry.idOf(to), id);

        assertEq(idRegistry.usernameOf(id), username);
        assertEq(idRegistry.getIdByUsername(username), id);
        assertEq(idRegistry.recoveryOf(id), recovery);
    }

    // TODO: Doc
    function _assertTransferAndChangePreconditions(uint256 id, address from, string memory username, address to)
        internal
        view
    {
        assertEq(idRegistry.idOf(from), id);
        assertEq(idRegistry.custodyOf(id), from);
        assertEq(idRegistry.recoveryOf(id), address(0));

        assertEq(idRegistry.usernameOf(id), username);
        assertEq(idRegistry.getIdByUsername(username), id);

        assertEq(idRegistry.idOf(to), 0);
    }

    // TODO: Doc
    function _assertTransferAndChangePostconditions(
        uint256 id,
        address from,
        string memory username,
        address to,
        address newRecovery
    ) internal view {
        assertEq(idRegistry.idOf(from), 0);

        assertEq(idRegistry.custodyOf(id), to);
        assertEq(idRegistry.idOf(to), id);

        assertEq(idRegistry.usernameOf(id), username);
        assertEq(idRegistry.getIdByUsername(username), id);

        assertEq(idRegistry.recoveryOf(id), newRecovery);
    }

    // =============================================================
    //                        SIGNATURE HELPERS
    // =============================================================

    /// @dev Sign the EIP712 message for a transfer transaction.
    function _signTransfer(uint256 pk, uint256 id, address to, uint256 deadline)
        internal
        view
        returns (bytes memory signature)
    {
        bytes32 digest = idRegistry.hashTypedData(
            keccak256(abi.encode(idRegistry.TRANSFER_TYPEHASH(), id, to, idRegistry.nonces(to), deadline))
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, digest);
        signature = abi.encodePacked(r, s, v);
        assertEq(signature.length, 65);
    }

    /// @dev Sign the EIP712 message for a Rransfer transaction.
    function _signRecover(uint256 pk, uint256 id, address to, uint256 deadline)
        internal
        view
        returns (bytes memory signature)
    {
        bytes32 digest = idRegistry.hashTypedData(
            keccak256(abi.encode(idRegistry.RECOVER_TYPEHASH(), id, to, idRegistry.nonces(to), deadline))
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, digest);
        signature = abi.encodePacked(r, s, v);
        assertEq(signature.length, 65);
    }
}
