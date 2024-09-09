// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ProvenanceTest} from "../ProvenanceTest.sol";

contract IdGatewayTest is ProvenanceTest {
    // =============================================================
    //                           EVENTS
    // =============================================================

    // NOTE: These events are actually emitted by IdRegistry (which IdGateway wraps).
    event Registered(uint256 id, address indexed custody, string username, address indexed recovery);
    event Transfer(address indexed from, address indexed to, uint256 indexed id);
    event UsernameChanged(uint256 indexed id, string username);
    event UsernameTransferred(uint256 indexed fromId, uint256 indexed toId, string username);
    event RecoveryAddressChanged(uint256 indexed id, address indexed recovery);
    event Recovered(uint256 indexed id, address indexed to);

    // =============================================================
    //                           ERRORS
    // =============================================================

    error CustodyAlreadyRegistered();
    error UsernameAlreadyRegistered();
    error UsernameTooLong();
    error UsernameTooShort();
    error UsernameContainsInvalidChar();
    error HasNoId();

    // =============================================================
    //                   Constants / Immutables
    // =============================================================

    function test_VERSION() public view {
        assertEq(idGateway.VERSION(), "2024-09-07");
    }

    function test_REGISTER_TYPEHASH() public view {
        assertEq(
            idGateway.REGISTER_TYPEHASH(),
            keccak256("Register(address custody,string username,address recovery,uint256 nonce,uint256 deadline)")
        );
    }

    function test_TRANSFER_TYPEHASH() public view {
        assertEq(
            idGateway.TRANSFER_TYPEHASH(), keccak256("Transfer(uint256 id,address to,uint256 nonce,uint256 deadline)")
        );
    }

    function test_TRANSFER_USERNAME_TYPEHASH() public view {
        assertEq(
            idGateway.TRANSFER_USERNAME_TYPEHASH(),
            keccak256(
                "TransferUsername(uint256 fromId,uint256 toId,string newFromUsername,uint256 nonce,uint256 deadline)"
            )
        );
    }

    function test_CHANGE_USERNAME_TYPEHASH() public view {
        assertEq(
            idGateway.CHANGE_USERNAME_TYPEHASH(),
            keccak256("ChangeUsername(uint256 id,string newUsername,uint256 nonce,uint256 deadline)")
        );
    }

    function test_CHANGE_RECOVERY_TYPEHASH() public view {
        assertEq(
            idGateway.CHANGE_RECOVERY_TYPEHASH(),
            keccak256("ChangeRecovery(uint256 id,address newRecovery,uint256 nonce,uint256 deadline)")
        );
    }

    function test_RECOVER_TYPEHASH() public view {
        assertEq(
            idGateway.RECOVER_TYPEHASH(), keccak256("Recover(uint256 id,address to,uint256 nonce,uint256 deadline)")
        );
    }

    function test_idRegistry() public view {
        assertEq(address(idGateway.idRegistry()), address(idRegistry));
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
        ) = idGateway.eip712Domain();

        assertEq(fields, hex"0f");
        assertEq(name, "RoyalProtocol_IdGateway");
        assertEq(version, "1");
        assertEq(chainId, block.chainid);
        assertEq(verifyingContract, address(idGateway));
        assertEq(salt, bytes32(0));
        assertEq(extensions.length, 0);
    }

    // =============================================================
    //                  constructor() / initialize()
    // =============================================================

    function test_UnpausedWhenDeployed() public view {
        assertEq(idGateway.paused(), false);
    }

    function test_OwnerSetWhenDeployed() public view {
        assertEq(idGateway.owner(), ID_GATEWAY_OWNER);
    }

    // =============================================================
    //                        Receiving ETH
    // =============================================================

    // Run 256 times, with different (address, amount) tuples
    function testFuzz_RevertWhenReceivingDirectPayment(address sender, uint256 amount) public {
        vm.deal(sender, amount);
        vm.expectRevert();
        vm.prank(sender);
        payable(address(idGateway)).transfer(amount);
    }

    // =============================================================
    //                          register()
    // =============================================================

    function testFuzz_register(address custody, uint8 usernameLength_, address recovery) public {
        // Bound inputs that need to be bound.
        vm.assume(custody != address(0));
        uint256 usernameLength = _boundUsernameLength(usernameLength_);
        string memory username = _getRandomValidUniqueUsername(usernameLength);

        // Assert Preconditions
        uint256 expectedId = 1;
        _assertRegisterPreconditions(expectedId, custody);

        // Call .register() and check the emitted event
        vm.expectEmit();
        emit Registered(expectedId, custody, username, recovery);
        vm.prank(custody);
        idGateway.register(username, recovery);

        // Assert Postconditions
        _assertRegisterPostconditions(expectedId, custody, username, recovery);
    }

    function testFuzz_register_RevertWhenIdGatewayPaused(address custody, uint8 usernameLength_, address recovery)
        public
    {
        // Pause the IdGateway
        vm.prank(ID_GATEWAY_OWNER);
        idGateway.pause();

        // Bound inputs that need to be bound.
        vm.assume(custody != address(0));
        uint256 usernameLength = _boundUsernameLength(usernameLength_);
        string memory username = _getRandomValidUniqueUsername(usernameLength);

        // Call .register() and check the revert error
        vm.expectRevert(EnforcedPause.selector);
        vm.prank(custody);
        idGateway.register(username, recovery);
    }

    function testFuzz_register_RevertWhenIdRegistryPaused(address custody, uint8 usernameLength_, address recovery)
        public
    {
        // Pause the IdRegistry
        vm.prank(ID_REGISTRY_OWNER);
        idRegistry.pause();

        // Bound inputs that need to be bound.
        vm.assume(custody != address(0));
        uint256 usernameLength = _boundUsernameLength(usernameLength_);
        string memory username = _getRandomValidUniqueUsername(usernameLength);

        // Call .register() and check the revert error
        vm.expectRevert(EnforcedPause.selector);
        vm.prank(custody);
        idGateway.register(username, recovery);
    }

    function testFuzz_register_RevertWhenCustodyAlreadyRegistered(address custody) public {
        vm.assume(custody != address(0));

        vm.prank(custody);
        idGateway.register("username1", address(0));

        vm.expectRevert(CustodyAlreadyRegistered.selector);
        vm.prank(custody);
        idGateway.register("username2", address(0));
    }

    function testFuzz_register_RevertWhenUsernameAlreadyRegistered(
        address custody1,
        address custody2,
        uint8 usernameLength_
    ) public {
        // Bound inputs that need to be bound.
        vm.assume(custody1 != address(0));
        vm.assume(custody2 != address(0));
        vm.assume(custody1 != custody2);
        uint256 usernameLength = _boundUsernameLength(usernameLength_);
        string memory username = _getRandomValidUniqueUsername(usernameLength);

        vm.prank(custody1);
        idGateway.register(username, address(0));

        vm.expectRevert(UsernameAlreadyRegistered.selector);
        vm.prank(custody2);
        idGateway.register(username, address(0));
    }

    function testFuzz_register_RevertWhenUsernameTooLong(address custody, uint8 usernameLength_) public {
        vm.assume(custody != address(0));

        uint256 invalidUsernameLength = _boundUsernameLengthTooLong(usernameLength_);
        string memory username = _getRandomValidUniqueUsername(invalidUsernameLength);

        vm.expectRevert(UsernameTooLong.selector);
        vm.prank(custody);
        idGateway.register(username, address(0));
    }

    function testFuzz_register_RevertWhenUsernameTooShort(address custody) public {
        vm.assume(custody != address(0));

        // Currently, usernames of a single character are acceptable, so the only invalid length is 0.
        string memory username = "";

        vm.expectRevert(UsernameTooShort.selector);
        vm.prank(custody);
        idGateway.register(username, address(0));
    }

    function testFuzz_register_RevertWhenUsernameContainsInvalidChar(address custody, bytes16 usernameBytes) public {
        vm.assume(custody != address(0));

        // Verify the username is invalid.
        string memory username = string(abi.encodePacked(usernameBytes));
        vm.assume(!_validateUsernameCharacters(username));

        vm.expectRevert(UsernameContainsInvalidChar.selector);
        vm.prank(custody);
        idGateway.register(username, address(0));
    }

    // =============================================================
    //                        registerFor()
    // =============================================================

    function testFuzz_registerFor(
        address caller,
        uint256 custodyPk_,
        uint8 usernameLength_,
        address recovery,
        uint40 deadline_
    ) public {
        // Bound inputs that need to be bound.
        uint256 custodyPk = _boundPk(custodyPk_);
        address custody = vm.addr(custodyPk);

        uint256 usernameLength = _boundUsernameLength(usernameLength_);
        string memory username = _getRandomValidUniqueUsername(usernameLength);

        uint256 deadline = _boundDeadline(deadline_);

        // Assert Preconditions
        uint256 expectedId = 1;
        assertEq(idGateway.nonces(custody), 0);
        _assertRegisterPreconditions(expectedId, custody);

        // Register the ID with an EIP712 signature
        bytes memory sig = _signRegister(custodyPk, custody, username, recovery, deadline);

        // Call .registerFor() and check the emitted event
        vm.expectEmit();
        emit Registered(expectedId, custody, username, recovery);
        vm.prank(caller);
        idGateway.registerFor(custody, username, recovery, deadline, sig);

        // Assert Postconditions
        assertEq(idGateway.nonces(custody), 1);
        _assertRegisterPostconditions(expectedId, custody, username, recovery);
    }

    function testFuzz_registerFor_RevertWhenIdGatewayPaused(
        address caller,
        uint256 custodyPk_,
        uint8 usernameLength_,
        address recovery,
        uint40 deadline_
    ) public {
        // Pause the IdGateway
        vm.prank(ID_GATEWAY_OWNER);
        idGateway.pause();

        // Bound inputs that need to be bound.
        uint256 custodyPk = _boundPk(custodyPk_);
        address custody = vm.addr(custodyPk);

        uint256 usernameLength = _boundUsernameLength(usernameLength_);
        string memory username = _getRandomValidUniqueUsername(usernameLength);

        uint256 deadline = _boundDeadline(deadline_);

        // Register the ID with an EIP712 signature
        bytes memory sig = _signRegister(custodyPk, custody, username, recovery, deadline);

        // Call .registerFor() and check the revert error
        vm.expectRevert(EnforcedPause.selector);
        vm.prank(caller);
        idGateway.registerFor(custody, username, recovery, deadline, sig);
    }

    function testFuzz_registerFor_RevertWhenIdRegistryPaused(
        address caller,
        uint256 custodyPk_,
        uint8 usernameLength_,
        address recovery,
        uint40 deadline_
    ) public {
        // Pause the IdRegistry
        vm.prank(ID_REGISTRY_OWNER);
        idRegistry.pause();

        // Bound inputs that need to be bound.
        uint256 custodyPk = _boundPk(custodyPk_);
        address custody = vm.addr(custodyPk);

        uint256 usernameLength = _boundUsernameLength(usernameLength_);
        string memory username = _getRandomValidUniqueUsername(usernameLength);

        uint256 deadline = _boundDeadline(deadline_);

        // Register the ID with an EIP712 signature
        bytes memory sig = _signRegister(custodyPk, custody, username, recovery, deadline);

        // Call .registerFor() and check the revert error
        vm.expectRevert(EnforcedPause.selector);
        vm.prank(caller);
        idGateway.registerFor(custody, username, recovery, deadline, sig);
    }

    function testFuzz_registerFor_RevertWhenCustodyAlreadyRegistered(
        address caller,
        uint256 custodyPk_,
        uint40 deadline_
    ) public {
        // Bound inputs that need to be bound.
        uint256 custodyPk = _boundPk(custodyPk_);
        address custody = vm.addr(custodyPk);
        address recovery = address(0);
        uint256 deadline = _boundDeadline(deadline_);

        // Register the ID with an EIP712 signature
        bytes memory sig1 = _signRegister(custodyPk, custody, "username1", recovery, deadline);
        vm.prank(caller);
        idGateway.registerFor(custody, "username1", recovery, deadline, sig1);

        // Expect the revert error
        bytes memory sig2 = _signRegister(custodyPk, custody, "username2", recovery, deadline);
        vm.expectRevert(CustodyAlreadyRegistered.selector);
        vm.prank(caller);
        idGateway.registerFor(custody, "username2", recovery, deadline, sig2);
    }

    function testFuzz_registerFor_RevertWhenUsernameAlreadyRegistered(
        address caller,
        uint256 custodyPk1_,
        uint256 custodyPk2_,
        uint8 usernameLength_,
        uint40 deadline_
    ) public {
        // Bound inputs that need to be bound.
        uint256 custodyPk1 = _boundPk(custodyPk1_);
        uint256 custodyPk2 = _boundPk(custodyPk2_);
        vm.assume(custodyPk1 != custodyPk2);
        address custody1 = vm.addr(custodyPk1);
        address custody2 = vm.addr(custodyPk2);

        uint256 usernameLength = _boundUsernameLength(usernameLength_);
        string memory username = _getRandomValidUniqueUsername(usernameLength);

        address recovery = address(0);
        uint256 deadline = _boundDeadline(deadline_);

        // Register the ID with an EIP712 signature
        bytes memory sig1 = _signRegister(custodyPk1, custody1, username, recovery, deadline);
        vm.prank(caller);
        idGateway.registerFor(custody1, username, recovery, deadline, sig1);

        // Expect the revert error
        bytes memory sig2 = _signRegister(custodyPk2, custody2, username, recovery, deadline);
        vm.expectRevert(UsernameAlreadyRegistered.selector);
        vm.prank(caller);
        idGateway.registerFor(custody2, username, recovery, deadline, sig2);
    }

    function testFuzz_registerFor_RevertWhenUsernameTooLong(
        address caller,
        uint256 custodyPk_,
        uint8 usernameLength_,
        uint40 deadline_
    ) public {
        // Bound inputs that need to be bound.
        uint256 custodyPk = _boundPk(custodyPk_);
        address custody = vm.addr(custodyPk);
        address recovery = address(0);
        uint256 deadline = _boundDeadline(deadline_);

        uint256 invalidUsernameLength = _boundUsernameLengthTooLong(usernameLength_);
        string memory username = _getRandomValidUniqueUsername(invalidUsernameLength);

        // Expect the revert error
        bytes memory sig = _signRegister(custodyPk, custody, username, recovery, deadline);
        vm.expectRevert(UsernameTooLong.selector);
        vm.prank(caller);
        idGateway.registerFor(custody, username, recovery, deadline, sig);
    }

    function testFuzz_registerFor_RevertWhenUsernameTooShort(address caller, uint256 custodyPk_, uint40 deadline_)
        public
    {
        // Bound inputs that need to be bound.
        uint256 custodyPk = _boundPk(custodyPk_);
        address custody = vm.addr(custodyPk);
        address recovery = address(0);
        uint256 deadline = _boundDeadline(deadline_);

        // Currently, usernames of a single character are acceptable, so the only invalid length is 0.
        string memory username = "";

        // Expect the revert error
        bytes memory sig = _signRegister(custodyPk, custody, username, recovery, deadline);
        vm.expectRevert(UsernameTooShort.selector);
        vm.prank(caller);
        idGateway.registerFor(custody, username, recovery, deadline, sig);
    }

    function testFuzz_registerFor_RevertWhenUsernameContainsInvalidChar(
        address caller,
        uint256 custodyPk_,
        bytes16 usernameBytes,
        uint40 deadline_
    ) public {
        // Bound inputs that need to be bound.
        uint256 custodyPk = _boundPk(custodyPk_);
        address custody = vm.addr(custodyPk);

        // Verify the username is invalid.
        string memory username = string(abi.encodePacked(usernameBytes));
        vm.assume(!_validateUsernameCharacters(username));

        address recovery = address(0);
        uint256 deadline = _boundDeadline(deadline_);

        // Register the ID with an EIP712 signature
        bytes memory sig = _signRegister(custodyPk, custody, username, recovery, deadline);
        vm.expectRevert(UsernameContainsInvalidChar.selector);
        vm.prank(caller);
        idGateway.registerFor(custody, username, recovery, deadline, sig);
    }

    // =============================================================
    //               registerFor() - Signature Reverts
    // =============================================================

    function testFuzz_registerFor_RevertWhenDeadlineExpired(
        address caller,
        uint256 custodyPk_,
        uint8 usernameLength_,
        address recovery,
        uint40 deadline_
    ) public {
        // Bound inputs that need to be bound.
        uint256 custodyPk = _boundPk(custodyPk_);
        address custody = vm.addr(custodyPk);

        uint256 usernameLength = _boundUsernameLength(usernameLength_);
        string memory username = _getRandomValidUniqueUsername(usernameLength);

        uint256 deadline = _boundDeadline(deadline_);

        // Register the ID with an EIP712 signature
        bytes memory sig = _signRegister(custodyPk, custody, username, recovery, deadline);

        // Fast forward past the deadline
        vm.warp(deadline + 1);

        // Expect the revert error
        vm.expectRevert(SignatureExpired.selector);
        vm.prank(caller);
        idGateway.registerFor(custody, username, recovery, deadline, sig);
    }

    function testFuzz_registerFor_RevertWhenNonceInvalid(
        address caller,
        uint256 custodyPk_,
        uint8 usernameLength_,
        address recovery,
        uint40 deadline_
    ) public {
        // Bound inputs that need to be bound.
        uint256 custodyPk = _boundPk(custodyPk_);
        address custody = vm.addr(custodyPk);

        uint256 usernameLength = _boundUsernameLength(usernameLength_);
        string memory username = _getRandomValidUniqueUsername(usernameLength);

        uint256 deadline = _boundDeadline(deadline_);

        // Register the ID with an EIP712 signature
        bytes memory sig = _signRegister(custodyPk, custody, username, recovery, deadline);

        // Have user invalidate their nonce
        vm.prank(custody);
        idGateway.useNonce();

        // Expect the revert error
        vm.expectRevert(InvalidSignature.selector);
        vm.prank(caller);
        idGateway.registerFor(custody, username, recovery, deadline, sig);
    }

    function testFuzz_registerFor_RevertWhenSignerInvalid(
        address caller,
        uint256 signerPk_,
        address custody,
        uint8 usernameLength_,
        address recovery,
        uint40 deadline_
    ) public {
        // Bound inputs that need to be bound.
        uint256 signerPk = _boundPk(signerPk_);
        address signer = vm.addr(signerPk);
        vm.assume(signer != custody);

        uint256 usernameLength = _boundUsernameLength(usernameLength_);
        string memory username = _getRandomValidUniqueUsername(usernameLength);

        uint256 deadline = _boundDeadline(deadline_);

        // Register the ID with an EIP712 signature
        bytes memory sig = _signRegister(signerPk, custody, username, recovery, deadline);

        // Expect the revert error since signer != custody
        vm.expectRevert(InvalidSignature.selector);
        vm.prank(caller);
        idGateway.registerFor(custody, username, recovery, deadline, sig);
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
        idGateway.transfer(to, deadline, sig);

        // Check that the ID was transferred.
        _assertTransferPostconditions(id, from, to, username, recovery);
    }

    // TODO: RevertWhenIdGatewayPaused

    function testFuzz_transfer_RevertWhenIdGatewayPaused(
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

        // Pause the IdGateway.
        vm.prank(ID_GATEWAY_OWNER);
        idGateway.pause();

        // Get signature from `to` address authorizing receiving the transfer, and revert as expected.
        bytes memory sig = _signTransfer(toPk, id, to, deadline);

        // Revert as expected.
        vm.expectRevert(EnforcedPause.selector);
        vm.prank(from);
        idGateway.transfer(to, deadline, sig);
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
        idGateway.transfer(to, deadline, sig);
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
        vm.expectRevert(HasNoId.selector);
        vm.prank(caller);
        idGateway.transfer(to, deadline, sig);
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
        idGateway.transfer(to, deadline, sig);
    }

    // TODO:
    // =============================================================
    //               transfer() - Signature Reverts
    // =============================================================

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
        idGateway.transferFor(id, to, fromDeadline, fromSig, toDeadline, toSig);

        _assertTransferPostconditions(id, from, to, username, recovery);
    }

    // TODO: testFuzz_transferFor_RevertWhenIdGatewayPaused

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
        idGateway.transferFor(id, to, fromDeadline, fromSig, toDeadline, toSig);
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
        idGateway.transferFor(fromId, to, fromDeadline, fromSig, toDeadline, toSig);
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
        idGateway.transferAndClearRecovery(to, deadline, sig);

        // Check that the ID was transferred.
        _assertTransferAndChangePostconditions(id, from, username, to, address(0));
    }

    // TODO: testFuzz_transferAndClearRecovery_RevertWhenIdGatewayPaused

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
        idGateway.transferAndClearRecovery(to, deadline, sig);
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
        vm.expectRevert(HasNoId.selector);
        vm.prank(caller);
        idGateway.transferAndClearRecovery(to, deadline, sig);
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
        idGateway.transferAndClearRecovery(to, deadline, sig);
    }

    // TODO: testFuzz_transferAndClearRecovery_RevertWhenToDeadlineExpired
    // TODO: testFuzz_transferAndClearRecovery_RevertWhenToNonceInvalid
    // TODO: testFuzz_transferAndClearRecovery_RevertWhenToSignerInvalid

    // TODO:
    // =============================================================
    //              transferAndClearRecoveryFor()
    // =============================================================

    // =============================================================
    //                        transferUsername()
    // =============================================================

    function testFuzz_transferUsername(
        address from,
        uint256 toPk_,
        uint8 initialFromUsernameLength_,
        uint8 initialToUsernameLength_,
        uint8 newFromUsernameLength_,
        uint40 toDeadline_
    ) public {
        // Bound inputs that need to be bound.
        vm.assume(from != address(0));
        uint256 toPk = _boundPk(toPk_);
        address to = vm.addr(toPk);
        vm.assume(from != to);

        uint256 initialFromUsernameLength = _boundUsernameLength(initialFromUsernameLength_);
        string memory initialFromUsername = _getRandomValidUniqueUsername(initialFromUsernameLength);
        uint256 initialToUsernameLength = _boundUsernameLength(initialToUsernameLength_);
        string memory initialToUsername = _getRandomValidUniqueUsername(initialToUsernameLength);
        uint256 newFromUsernameLength = _boundUsernameLength(newFromUsernameLength_);
        string memory newFromUsername = _getRandomValidUniqueUsername(newFromUsernameLength);

        uint256 toDeadline = _boundDeadline(toDeadline_);

        // Register the from and to addresses with their initial usernames.
        _register(from, initialFromUsername);
        _register(to, initialToUsername);
        uint256 fromId = idRegistry.idOf(from);
        uint256 toId = idRegistry.idOf(to);

        // Verify that the usernames were registered.
        assertEq(idRegistry.usernameOf(fromId), initialFromUsername);
        assertEq(idRegistry.usernameOf(toId), initialToUsername);

        // Transfer the username, with signature from `to` address accepting the new username.
        bytes memory toSig = _signChangeUsername(toPk, to, toId, initialFromUsername, toDeadline);

        vm.expectEmit();
        emit UsernameChanged(fromId, newFromUsername);
        vm.expectEmit();
        emit UsernameChanged(toId, initialFromUsername);
        vm.expectEmit();
        emit UsernameTransferred(fromId, toId, initialFromUsername);

        vm.prank(from);
        idGateway.transferUsername(toId, newFromUsername, toDeadline, toSig);

        // Assert that the username was transferred,
        // and that the `from` address has the `newFromUsername`.
        assertEq(idRegistry.usernameOf(fromId), newFromUsername);
        assertEq(idRegistry.usernameOf(toId), initialFromUsername);
    }

    function testFuzz_transferUsername_RevertWhenWhenIdRegistryPaused(
        address from,
        uint256 toPk_,
        uint8 initialFromUsernameLength_,
        uint8 initialToUsernameLength_,
        uint8 newFromUsernameLength_,
        uint40 toDeadline_
    ) public {
        // Bound inputs that need to be bound.
        vm.assume(from != address(0));
        uint256 toPk = _boundPk(toPk_);
        address to = vm.addr(toPk);
        vm.assume(from != to);

        uint256 initialFromUsernameLength = _boundUsernameLength(initialFromUsernameLength_);
        string memory initialFromUsername = _getRandomValidUniqueUsername(initialFromUsernameLength);
        uint256 initialToUsernameLength = _boundUsernameLength(initialToUsernameLength_);
        string memory initialToUsername = _getRandomValidUniqueUsername(initialToUsernameLength);
        uint256 newFromUsernameLength = _boundUsernameLength(newFromUsernameLength_);
        string memory newFromUsername = _getRandomValidUniqueUsername(newFromUsernameLength);

        uint256 toDeadline = _boundDeadline(toDeadline_);

        // Register the from and to addresses with their initial usernames.
        _register(from, initialFromUsername);
        _register(to, initialToUsername);
        uint256 fromId = idRegistry.idOf(from);
        uint256 toId = idRegistry.idOf(to);

        // Pause IdRegistry
        vm.prank(ID_REGISTRY_OWNER);
        idRegistry.pause();

        // Verify that the usernames were registered.
        assertEq(idRegistry.usernameOf(fromId), initialFromUsername);
        assertEq(idRegistry.usernameOf(toId), initialToUsername);

        // Transfer the username, with signature from `to` address accepting the new username.
        bytes memory toSig = _signChangeUsername(toPk, to, toId, initialFromUsername, toDeadline);

        vm.expectRevert(EnforcedPause.selector);
        vm.prank(from);
        idGateway.transferUsername(toId, newFromUsername, toDeadline, toSig);
    }

    function testFuzz_transferUsername_RevertWhenIdGatewayPaused(
        address from,
        uint256 toPk_,
        uint8 initialFromUsernameLength_,
        uint8 initialToUsernameLength_,
        uint8 newFromUsernameLength_,
        uint40 toDeadline_
    ) public {
        // Bound inputs that need to be bound.
        vm.assume(from != address(0));
        uint256 toPk = _boundPk(toPk_);
        address to = vm.addr(toPk);
        vm.assume(from != to);

        uint256 initialFromUsernameLength = _boundUsernameLength(initialFromUsernameLength_);
        string memory initialFromUsername = _getRandomValidUniqueUsername(initialFromUsernameLength);
        uint256 initialToUsernameLength = _boundUsernameLength(initialToUsernameLength_);
        string memory initialToUsername = _getRandomValidUniqueUsername(initialToUsernameLength);
        uint256 newFromUsernameLength = _boundUsernameLength(newFromUsernameLength_);
        string memory newFromUsername = _getRandomValidUniqueUsername(newFromUsernameLength);

        uint256 toDeadline = _boundDeadline(toDeadline_);

        // Register the from and to addresses with their initial usernames.
        _register(from, initialFromUsername);
        _register(to, initialToUsername);
        uint256 toId = idRegistry.idOf(to);

        // Pause IdGateway
        vm.prank(ID_GATEWAY_OWNER);
        idGateway.pause();

        // Attempt to transfer the username, but expect a revert.
        bytes memory toSig = _signChangeUsername(toPk, to, toId, initialFromUsername, toDeadline);
        vm.expectRevert(EnforcedPause.selector);
        vm.prank(from);
        idGateway.transferUsername(toId, newFromUsername, toDeadline, toSig);
    }

    // NOTE: All these username checks will likely have shared functionality,
    // since we'll need to generate these cases for each function.
    function testFuzz_transferUsername_RevertWhenUsernameAlreadyRegistered(
        address from,
        uint256 toPk_,
        address charlie,
        uint8 initialFromUsernameLength_,
        uint8 initialToUsernameLength_,
        uint8 newFromUsernameLength_,
        uint40 toDeadline_
    ) public {
        // Bound inputs that need to be bound.
        vm.assume(from != address(0));
        uint256 toPk = _boundPk(toPk_);
        address to = vm.addr(toPk);
        vm.assume(from != to);
        vm.assume(charlie != address(0) && charlie != from && charlie != to);

        uint256 initialFromUsernameLength = _boundUsernameLength(initialFromUsernameLength_);
        string memory initialFromUsername = _getRandomValidUniqueUsername(initialFromUsernameLength);
        uint256 initialToUsernameLength = _boundUsernameLength(initialToUsernameLength_);
        string memory initialToUsername = _getRandomValidUniqueUsername(initialToUsernameLength);
        uint256 newFromUsernameLength = _boundUsernameLength(newFromUsernameLength_);
        string memory newFromUsername = _getRandomValidUniqueUsername(newFromUsernameLength);

        uint256 toDeadline = _boundDeadline(toDeadline_);

        // Register the from and to addresses with their initial usernames.
        _register(from, initialFromUsername);
        _register(to, initialToUsername);
        uint256 toId = idRegistry.idOf(to);

        // Register a random 3rd person (charlie) with the desired newFromUsername,
        // before `from` has a chance to register it.
        _register(charlie, newFromUsername);

        // Attempt to transfer the username, but expect a revert.
        bytes memory toSig = _signChangeUsername(toPk, to, toId, initialFromUsername, toDeadline);
        vm.expectRevert(UsernameAlreadyRegistered.selector);
        vm.prank(from);
        idGateway.transferUsername(toId, newFromUsername, toDeadline, toSig);
    }

    function testFuzz_transferUsername_RevertWhenUsernameTooLong(
        address from,
        uint256 toPk_,
        uint8 initialFromUsernameLength_,
        uint8 initialToUsernameLength_,
        uint8 newFromUsernameLength_,
        uint40 toDeadline_
    ) public {
        // Bound inputs that need to be bound.
        vm.assume(from != address(0));
        uint256 toPk = _boundPk(toPk_);
        address to = vm.addr(toPk);
        vm.assume(from != to);

        uint256 initialFromUsernameLength = _boundUsernameLength(initialFromUsernameLength_);
        string memory initialFromUsername = _getRandomValidUniqueUsername(initialFromUsernameLength);
        uint256 initialToUsernameLength = _boundUsernameLength(initialToUsernameLength_);
        string memory initialToUsername = _getRandomValidUniqueUsername(initialToUsernameLength);
        uint256 invalidUsernameLength = _boundUsernameLengthTooLong(newFromUsernameLength_);
        string memory newFromUsername = _getRandomValidUniqueUsername(invalidUsernameLength);

        uint256 toDeadline = _boundDeadline(toDeadline_);

        // Register the from and to addresses with their initial usernames.
        _register(from, initialFromUsername);
        _register(to, initialToUsername);
        uint256 toId = idRegistry.idOf(to);

        // Attempt to transfer the username, but expect a revert.
        bytes memory toSig = _signChangeUsername(toPk, to, toId, initialFromUsername, toDeadline);
        vm.expectRevert(UsernameTooLong.selector);
        vm.prank(from);
        idGateway.transferUsername(toId, newFromUsername, toDeadline, toSig);
    }

    function testFuzz_transferUsername_RevertWhenUsernameTooShort(
        address from,
        uint256 toPk_,
        uint8 initialFromUsernameLength_,
        uint8 initialToUsernameLength_,
        uint40 toDeadline_
    ) public {
        // Bound inputs that need to be bound.
        vm.assume(from != address(0));
        uint256 toPk = _boundPk(toPk_);
        address to = vm.addr(toPk);
        vm.assume(from != to);

        uint256 initialFromUsernameLength = _boundUsernameLength(initialFromUsernameLength_);
        string memory initialFromUsername = _getRandomValidUniqueUsername(initialFromUsernameLength);
        uint256 initialToUsernameLength = _boundUsernameLength(initialToUsernameLength_);
        string memory initialToUsername = _getRandomValidUniqueUsername(initialToUsernameLength);

        // Currently, usernames of a single character are acceptable, so the only invalid length is 0.
        string memory newFromUsername = "";

        uint256 toDeadline = _boundDeadline(toDeadline_);

        // Register the from and to addresses with their initial usernames.
        _register(from, initialFromUsername);
        _register(to, initialToUsername);
        uint256 toId = idRegistry.idOf(to);

        // Attempt to transfer the username, but expect a revert.
        bytes memory toSig = _signChangeUsername(toPk, to, toId, initialFromUsername, toDeadline);
        vm.expectRevert(UsernameTooShort.selector);
        vm.prank(from);
        idGateway.transferUsername(toId, newFromUsername, toDeadline, toSig);
    }

    function testFuzz_transferUsername_RevertWhenUsernameContainsInvalidChar(
        address from,
        uint256 toPk_,
        uint8 initialFromUsernameLength_,
        uint8 initialToUsernameLength_,
        bytes16 newFromUsernameBytes_,
        uint40 toDeadline_
    ) public {
        // Bound inputs that need to be bound.
        vm.assume(from != address(0));
        uint256 toPk = _boundPk(toPk_);
        address to = vm.addr(toPk);
        vm.assume(from != to);

        uint256 initialFromUsernameLength = _boundUsernameLength(initialFromUsernameLength_);
        string memory initialFromUsername = _getRandomValidUniqueUsername(initialFromUsernameLength);
        uint256 initialToUsernameLength = _boundUsernameLength(initialToUsernameLength_);
        string memory initialToUsername = _getRandomValidUniqueUsername(initialToUsernameLength);

        string memory newFromUsername = string(abi.encodePacked(newFromUsernameBytes_));
        vm.assume(!_validateUsernameCharacters(newFromUsername));

        uint256 toDeadline = _boundDeadline(toDeadline_);

        // Register the from and to addresses with their initial usernames.
        _register(from, initialFromUsername);
        _register(to, initialToUsername);
        uint256 toId = idRegistry.idOf(to);

        // Attempt to transfer the username, but expect a revert.
        bytes memory toSig = _signChangeUsername(toPk, to, toId, initialFromUsername, toDeadline);
        vm.expectRevert(UsernameContainsInvalidChar.selector);
        vm.prank(from);
        idGateway.transferUsername(toId, newFromUsername, toDeadline, toSig);
    }

    // Signature reverts
    // TODO: testFuzz_transferUsername_RevertWhenDeadlineExpired
    // TODO: testFuzz_transferUsername_RevertWhenNonceInvalid
    // TODO: testFuzz_transferUsername_RevertWhenSignerInvalid

    // =============================================================
    //                        transferUsernameFor()
    // =============================================================

    function testFuzz_transferUsernameFor(
        address registrar,
        uint256 fromPk_,
        uint256 toPk_,
        uint8 initialFromUsernameLength_,
        uint8 initialToUsernameLength_,
        uint8 newFromUsernameLength_,
        uint40 fromDeadline_,
        uint40 toDeadline_
    ) public {
        // Bound inputs that need to be bound.
        uint256 fromPk = _boundPk(fromPk_);
        address from = vm.addr(fromPk);
        uint256 toPk = _boundPk(toPk_);
        address to = vm.addr(toPk);
        vm.assume(from != to);

        uint256 initialFromUsernameLength = _boundUsernameLength(initialFromUsernameLength_);
        string memory initialFromUsername = _getRandomValidUniqueUsername(initialFromUsernameLength);
        uint256 initialToUsernameLength = _boundUsernameLength(initialToUsernameLength_);
        string memory initialToUsername = _getRandomValidUniqueUsername(initialToUsernameLength);
        uint256 newFromUsernameLength = _boundUsernameLength(newFromUsernameLength_);
        string memory newFromUsername = _getRandomValidUniqueUsername(newFromUsernameLength);

        uint256 fromDeadline = _boundDeadline(fromDeadline_);
        uint256 toDeadline = _boundDeadline(toDeadline_);

        // Register the from and to addresses with their initial usernames.
        _register(from, initialFromUsername);
        _register(to, initialToUsername);
        uint256 fromId = idRegistry.idOf(from);
        uint256 toId = idRegistry.idOf(to);

        // Verify that the usernames were registered.
        assertEq(idRegistry.usernameOf(fromId), initialFromUsername);
        assertEq(idRegistry.usernameOf(toId), initialToUsername);

        // Transfer the username, with signature from `to` address accepting the new username.
        bytes memory fromSig = _signTransferUsername(fromPk, from, fromId, toId, newFromUsername, fromDeadline);
        bytes memory toSig = _signChangeUsername(toPk, to, toId, initialFromUsername, toDeadline);

        vm.expectEmit();
        emit UsernameChanged(fromId, newFromUsername);
        vm.expectEmit();
        emit UsernameChanged(toId, initialFromUsername);
        vm.expectEmit();
        emit UsernameTransferred(fromId, toId, initialFromUsername);
        vm.prank(registrar);
        idGateway.transferUsernameFor(fromId, toId, newFromUsername, fromDeadline, fromSig, toDeadline, toSig);

        // Assert that the username was transferred,
        // and that the `from` address has the `newFromUsername`.
        assertEq(idRegistry.usernameOf(fromId), newFromUsername);
        assertEq(idRegistry.usernameOf(toId), initialFromUsername);
    }

    function testFuzz_transferUsernameFor_RevertWhenWhenIdRegistryPaused(
        address registrar,
        uint256 fromPk_,
        uint256 toPk_,
        uint8 initialFromUsernameLength_,
        uint8 initialToUsernameLength_,
        uint8 newFromUsernameLength_,
        uint40 fromDeadline_,
        uint40 toDeadline_
    ) public {
        // Bound inputs that need to be bound.
        uint256 fromPk = _boundPk(fromPk_);
        address from = vm.addr(fromPk);
        uint256 toPk = _boundPk(toPk_);
        address to = vm.addr(toPk);
        vm.assume(from != to);

        uint256 initialFromUsernameLength = _boundUsernameLength(initialFromUsernameLength_);
        string memory initialFromUsername = _getRandomValidUniqueUsername(initialFromUsernameLength);
        uint256 initialToUsernameLength = _boundUsernameLength(initialToUsernameLength_);
        string memory initialToUsername = _getRandomValidUniqueUsername(initialToUsernameLength);
        uint256 newFromUsernameLength = _boundUsernameLength(newFromUsernameLength_);
        string memory newFromUsername = _getRandomValidUniqueUsername(newFromUsernameLength);

        uint256 fromDeadline = _boundDeadline(fromDeadline_);
        uint256 toDeadline = _boundDeadline(toDeadline_);

        // Register the from and to addresses with their initial usernames.
        _register(from, initialFromUsername);
        _register(to, initialToUsername);
        uint256 fromId = idRegistry.idOf(from);
        uint256 toId = idRegistry.idOf(to);

        // Pause IdRegistry
        vm.prank(ID_REGISTRY_OWNER);
        idRegistry.pause();

        // Verify that the usernames were registered.
        assertEq(idRegistry.usernameOf(fromId), initialFromUsername);
        assertEq(idRegistry.usernameOf(toId), initialToUsername);

        // Transfer the username, with signature from `to` address accepting the new username.
        bytes memory fromSig = _signTransferUsername(fromPk, from, fromId, toId, newFromUsername, fromDeadline);
        bytes memory toSig = _signChangeUsername(toPk, to, toId, initialFromUsername, toDeadline);

        vm.expectRevert(EnforcedPause.selector);
        vm.prank(registrar);
        idGateway.transferUsernameFor(fromId, toId, newFromUsername, fromDeadline, fromSig, toDeadline, toSig);

        // Assert that the username was NOT transferred,
        // and that the `from` address has the `newFromUsername`.
        assertEq(idRegistry.usernameOf(fromId), initialFromUsername);
    }

    function testFuzz_transferUsernameFor_RevertWhenIdGatewayPaused(
        address registrar,
        uint256 fromPk_,
        uint256 toPk_,
        uint8 initialFromUsernameLength_,
        uint8 initialToUsernameLength_,
        uint8 newFromUsernameLength_,
        uint40 fromDeadline_,
        uint40 toDeadline_
    ) public {
        // Bound inputs that need to be bound.
        uint256 fromPk = _boundPk(fromPk_);
        address from = vm.addr(fromPk);
        uint256 toPk = _boundPk(toPk_);
        address to = vm.addr(toPk);
        vm.assume(from != to);

        uint256 initialFromUsernameLength = _boundUsernameLength(initialFromUsernameLength_);
        string memory initialFromUsername = _getRandomValidUniqueUsername(initialFromUsernameLength);
        uint256 initialToUsernameLength = _boundUsernameLength(initialToUsernameLength_);
        string memory initialToUsername = _getRandomValidUniqueUsername(initialToUsernameLength);
        uint256 newFromUsernameLength = _boundUsernameLength(newFromUsernameLength_);
        string memory newFromUsername = _getRandomValidUniqueUsername(newFromUsernameLength);

        uint256 fromDeadline = _boundDeadline(fromDeadline_);
        uint256 toDeadline = _boundDeadline(toDeadline_);

        // Register the from and to addresses with their initial usernames.
        _register(from, initialFromUsername);
        _register(to, initialToUsername);
        uint256 fromId = idRegistry.idOf(from);
        uint256 toId = idRegistry.idOf(to);

        // Pause IdGateway
        vm.prank(ID_GATEWAY_OWNER);
        idGateway.pause();

        // Verify that the usernames were registered.
        assertEq(idRegistry.usernameOf(fromId), initialFromUsername);
        assertEq(idRegistry.usernameOf(toId), initialToUsername);

        // Transfer the username, with signature from `to` address accepting the new username.
        bytes memory fromSig = _signTransferUsername(fromPk, from, fromId, toId, newFromUsername, fromDeadline);
        bytes memory toSig = _signChangeUsername(toPk, to, toId, initialFromUsername, toDeadline);
        vm.expectRevert(EnforcedPause.selector);
        vm.prank(registrar);
        idGateway.transferUsernameFor(fromId, toId, newFromUsername, fromDeadline, fromSig, toDeadline, toSig);
    }

    function testFuzz_transferUsernameFor_RevertWhenUsernameAlreadyRegistered(
        address registrar,
        uint256 fromPk_,
        uint256 toPk_,
        address charlie,
        uint8 initialFromUsernameLength_,
        uint8 initialToUsernameLength_,
        uint8 newFromUsernameLength_,
        uint40 fromDeadline_,
        uint40 toDeadline_
    ) public {
        // Bound inputs that need to be bound.
        uint256 fromPk = _boundPk(fromPk_);
        address from = vm.addr(fromPk);
        uint256 toPk = _boundPk(toPk_);
        address to = vm.addr(toPk);
        vm.assume(from != to);
        vm.assume(charlie != address(0) && charlie != from && charlie != to);

        uint256 initialFromUsernameLength = _boundUsernameLength(initialFromUsernameLength_);
        string memory initialFromUsername = _getRandomValidUniqueUsername(initialFromUsernameLength);
        uint256 initialToUsernameLength = _boundUsernameLength(initialToUsernameLength_);
        string memory initialToUsername = _getRandomValidUniqueUsername(initialToUsernameLength);
        uint256 newFromUsernameLength = _boundUsernameLength(newFromUsernameLength_);
        string memory newFromUsername = _getRandomValidUniqueUsername(newFromUsernameLength);

        uint256 fromDeadline = _boundDeadline(fromDeadline_);
        uint256 toDeadline = _boundDeadline(toDeadline_);

        // Register the from and to addresses with their initial usernames.
        _register(from, initialFromUsername);
        _register(to, initialToUsername);
        uint256 fromId = idRegistry.idOf(from);
        uint256 toId = idRegistry.idOf(to);

        // Register a random 3rd person (charlie) with the desired newFromUsername,
        // before `from` has a chance to register it.
        _register(charlie, newFromUsername);

        // Transfer the username, with signature from `to` address accepting the new username.
        bytes memory fromSig = _signTransferUsername(fromPk, from, fromId, toId, newFromUsername, fromDeadline);
        bytes memory toSig = _signChangeUsername(toPk, to, toId, initialFromUsername, toDeadline);
        vm.expectRevert(UsernameAlreadyRegistered.selector);
        vm.prank(registrar);
        idGateway.transferUsernameFor(fromId, toId, newFromUsername, fromDeadline, fromSig, toDeadline, toSig);
    }

    function testFuzz_transferUsernameFor_RevertWhenUsernameTooLong(
        address registrar,
        uint256 fromPk_,
        uint256 toPk_,
        uint8 initialFromUsernameLength_,
        uint8 initialToUsernameLength_,
        uint8 newFromUsernameLength_,
        uint40 fromDeadline_,
        uint40 toDeadline_
    ) public {
        // Bound inputs that need to be bound.
        uint256 fromPk = _boundPk(fromPk_);
        address from = vm.addr(fromPk);
        uint256 toPk = _boundPk(toPk_);
        address to = vm.addr(toPk);
        vm.assume(from != to);

        uint256 initialFromUsernameLength = _boundUsernameLength(initialFromUsernameLength_);
        string memory initialFromUsername = _getRandomValidUniqueUsername(initialFromUsernameLength);
        uint256 initialToUsernameLength = _boundUsernameLength(initialToUsernameLength_);
        string memory initialToUsername = _getRandomValidUniqueUsername(initialToUsernameLength);
        uint256 invalidUsernameLength = _boundUsernameLengthTooLong(newFromUsernameLength_);
        string memory newFromUsername = _getRandomValidUniqueUsername(invalidUsernameLength);

        uint256 fromDeadline = _boundDeadline(fromDeadline_);
        uint256 toDeadline = _boundDeadline(toDeadline_);

        // Register the from and to addresses with their initial usernames.
        _register(from, initialFromUsername);
        _register(to, initialToUsername);
        uint256 fromId = idRegistry.idOf(from);
        uint256 toId = idRegistry.idOf(to);

        // Transfer the username, with signature from `to` address accepting the new username.
        bytes memory fromSig = _signTransferUsername(fromPk, from, fromId, toId, newFromUsername, fromDeadline);
        bytes memory toSig = _signChangeUsername(toPk, to, toId, initialFromUsername, toDeadline);

        vm.expectRevert(UsernameTooLong.selector);
        vm.prank(registrar);
        idGateway.transferUsernameFor(fromId, toId, newFromUsername, fromDeadline, fromSig, toDeadline, toSig);
    }

    function testFuzz_transferUsernameFor_RevertWhenUsernameTooShort(
        address registrar,
        uint256 fromPk_,
        uint256 toPk_,
        uint8 initialFromUsernameLength_,
        uint8 initialToUsernameLength_,
        uint40 fromDeadline_,
        uint40 toDeadline_
    ) public {
        // Bound inputs that need to be bound.
        uint256 fromPk = _boundPk(fromPk_);
        address from = vm.addr(fromPk);
        uint256 toPk = _boundPk(toPk_);
        address to = vm.addr(toPk);
        vm.assume(from != to);

        uint256 initialFromUsernameLength = _boundUsernameLength(initialFromUsernameLength_);
        string memory initialFromUsername = _getRandomValidUniqueUsername(initialFromUsernameLength);
        uint256 initialToUsernameLength = _boundUsernameLength(initialToUsernameLength_);
        string memory initialToUsername = _getRandomValidUniqueUsername(initialToUsernameLength);

        // Currently, usernames of a single character are acceptable, so the only invalid length is 0.
        string memory newFromUsername = "";

        uint256 fromDeadline = _boundDeadline(fromDeadline_);
        uint256 toDeadline = _boundDeadline(toDeadline_);

        // Register the from and to addresses with their initial usernames.
        _register(from, initialFromUsername);
        _register(to, initialToUsername);
        uint256 fromId = idRegistry.idOf(from);
        uint256 toId = idRegistry.idOf(to);

        // Transfer the username, with signature from `to` address accepting the new username.
        bytes memory fromSig = _signTransferUsername(fromPk, from, fromId, toId, newFromUsername, fromDeadline);
        bytes memory toSig = _signChangeUsername(toPk, to, toId, initialFromUsername, toDeadline);

        vm.expectRevert(UsernameTooShort.selector);
        vm.prank(registrar);
        idGateway.transferUsernameFor(fromId, toId, newFromUsername, fromDeadline, fromSig, toDeadline, toSig);
    }

    function testFuzz_transferUsernameFor_RevertWhenUsernameContainsInvalidChar(
        address registrar,
        uint256 fromPk_,
        uint256 toPk_,
        uint8 initialFromUsernameLength_,
        uint8 initialToUsernameLength_,
        bytes16 newFromUsernameBytes_,
        uint40 fromDeadline_,
        uint40 toDeadline_
    ) public {
        // Bound inputs that need to be bound.
        uint256 fromPk = _boundPk(fromPk_);
        address from = vm.addr(fromPk);
        uint256 toPk = _boundPk(toPk_);
        address to = vm.addr(toPk);
        vm.assume(from != to);

        uint256 initialFromUsernameLength = _boundUsernameLength(initialFromUsernameLength_);
        string memory initialFromUsername = _getRandomValidUniqueUsername(initialFromUsernameLength);
        uint256 initialToUsernameLength = _boundUsernameLength(initialToUsernameLength_);
        string memory initialToUsername = _getRandomValidUniqueUsername(initialToUsernameLength);

        string memory newFromUsername = string(abi.encodePacked(newFromUsernameBytes_));
        vm.assume(!_validateUsernameCharacters(newFromUsername));

        uint256 fromDeadline = _boundDeadline(fromDeadline_);
        uint256 toDeadline = _boundDeadline(toDeadline_);

        // Register the from and to addresses with their initial usernames.
        _register(from, initialFromUsername);
        _register(to, initialToUsername);
        uint256 fromId = idRegistry.idOf(from);
        uint256 toId = idRegistry.idOf(to);

        // Transfer the username, with signature from `to` address accepting the new username.
        bytes memory fromSig = _signTransferUsername(fromPk, from, fromId, toId, newFromUsername, fromDeadline);
        bytes memory toSig = _signChangeUsername(toPk, to, toId, initialFromUsername, toDeadline);
        vm.expectRevert(UsernameContainsInvalidChar.selector);
        vm.prank(registrar);
        idGateway.transferUsernameFor(fromId, toId, newFromUsername, fromDeadline, fromSig, toDeadline, toSig);
    }

    // Signature reverts

    // TODO: testFuzz_transferUsername_RevertWhenFromDeadlineExpired
    // TODO: testFuzz_transferUsername_RevertWhenFromNonceInvalid
    // TODO: testFuzz_transferUsername_RevertWhenFromSignerInvalid
    // TODO: testFuzz_transferUsername_RevertWhenToDeadlineExpired
    // TODO: testFuzz_transferUsername_RevertWhenToNonceInvalid
    // TODO: testFuzz_transferUsername_RevertWhenToSignerInvalid

    // =============================================================
    //                        changeUsername()
    // =============================================================

    function testFuzz_changeUsername(address custody, uint8 initialUsernameLength_, uint8 newUsernameLength_) public {
        // Bound inputs that need to be bound.
        vm.assume(custody != address(0));

        uint256 initialUsernameLength = _boundUsernameLength(initialUsernameLength_);
        string memory initialUsername = _getRandomValidUniqueUsername(initialUsernameLength);
        uint256 newUsernameLength = _boundUsernameLength(newUsernameLength_);
        string memory newUsername = _getRandomValidUniqueUsername(newUsernameLength);

        // Register the custody address with its initial username.
        _register(custody, initialUsername);
        uint256 id = idRegistry.idOf(custody);

        // Verify that the username was registered.
        assertEq(idRegistry.usernameOf(id), initialUsername);

        // Change the username.
        vm.expectEmit();
        emit UsernameChanged(id, newUsername);
        vm.prank(custody);
        idGateway.changeUsername(newUsername);

        // Assert that the username was updated.
        assertEq(idRegistry.usernameOf(id), newUsername);
    }

    function testFuzz_changeUsername_RevertWhenIdRegistryPaused(
        address custody,
        uint8 initialUsernameLength_,
        uint8 newUsernameLength_
    ) public {
        // Bound inputs that need to be bound.
        vm.assume(custody != address(0));

        uint256 initialUsernameLength = _boundUsernameLength(initialUsernameLength_);
        string memory initialUsername = _getRandomValidUniqueUsername(initialUsernameLength);
        uint256 newUsernameLength = _boundUsernameLength(newUsernameLength_);
        string memory newUsername = _getRandomValidUniqueUsername(newUsernameLength);

        // Register the custody address with its initial username.
        _register(custody, initialUsername);
        uint256 id = idRegistry.idOf(custody);

        // Verify that the username was registered.
        assertEq(idRegistry.usernameOf(id), initialUsername);

        // Pause IdRegistry
        vm.prank(ID_REGISTRY_OWNER);
        idRegistry.pause();

        // Change the username.
        vm.expectRevert(EnforcedPause.selector);
        vm.prank(custody);
        idGateway.changeUsername(newUsername);

        // Assert that the username was NOT updated.
        assertEq(idRegistry.usernameOf(id), initialUsername);
    }

    function testFuzz_changeUsername_RevertWhenIdGatewayPaused(
        address custody,
        uint8 initialUsernameLength_,
        uint8 newUsernameLength_
    ) public {
        // Bound inputs that need to be bound.
        vm.assume(custody != address(0));

        uint256 initialUsernameLength = _boundUsernameLength(initialUsernameLength_);
        string memory initialUsername = _getRandomValidUniqueUsername(initialUsernameLength);
        uint256 newUsernameLength = _boundUsernameLength(newUsernameLength_);
        string memory newUsername = _getRandomValidUniqueUsername(newUsernameLength);

        // Register the custody address with its initial username.
        _register(custody, initialUsername);
        uint256 id = idRegistry.idOf(custody);

        // Verify that the username was registered.
        assertEq(idRegistry.usernameOf(id), initialUsername);

        // Pause IdGateway
        vm.prank(ID_GATEWAY_OWNER);
        idGateway.pause();

        // Change the username.
        vm.expectRevert(EnforcedPause.selector);
        vm.prank(custody);
        idGateway.changeUsername(newUsername);
    }

    function testFuzz_changeUsername_RevertWhenUsernameAlreadyRegistered(
        address custody,
        address charlie,
        uint8 initialUsernameLength_,
        uint8 newUsernameLength_
    ) public {
        // Bound inputs that need to be bound.
        vm.assume(custody != address(0));
        vm.assume(charlie != address(0) && charlie != custody);

        uint256 initialUsernameLength = _boundUsernameLength(initialUsernameLength_);
        string memory initialUsername = _getRandomValidUniqueUsername(initialUsernameLength);
        uint256 newUsernameLength = _boundUsernameLength(newUsernameLength_);
        string memory newUsername = _getRandomValidUniqueUsername(newUsernameLength);

        // Register the custody address with its initial username.
        _register(custody, initialUsername);
        uint256 id = idRegistry.idOf(custody);

        // Register a random 3rd person (charlie) with the desired newUsername,
        // before `custody` has a chance to register it.
        _register(charlie, newUsername);
        uint256 charlieId = idRegistry.idOf(charlie);

        // Verify that the username was registered.
        assertEq(idRegistry.usernameOf(id), initialUsername);
        assertEq(idRegistry.usernameOf(charlieId), newUsername);

        // Change the username.
        vm.expectRevert(UsernameAlreadyRegistered.selector);
        vm.prank(custody);
        idGateway.changeUsername(newUsername);
    }

    function testFuzz_changeUsername_RevertWhenUsernameTooLong(
        address custody,
        uint8 initialUsernameLength_,
        uint8 newUsernameLength_
    ) public {
        // Bound inputs that need to be bound.
        vm.assume(custody != address(0));

        uint256 initialUsernameLength = _boundUsernameLength(initialUsernameLength_);
        string memory initialUsername = _getRandomValidUniqueUsername(initialUsernameLength);
        uint256 invalidUsernameLength = _boundUsernameLengthTooLong(newUsernameLength_);
        string memory newUsername = _getRandomValidUniqueUsername(invalidUsernameLength);

        // Register the custody address with its initial username.
        _register(custody, initialUsername);
        uint256 id = idRegistry.idOf(custody);

        // Verify that the username was registered.
        assertEq(idRegistry.usernameOf(id), initialUsername);

        // Attempt to change the username.
        vm.expectRevert(UsernameTooLong.selector);
        vm.prank(custody);
        idGateway.changeUsername(newUsername);
    }

    function testFuzz_changeUsername_RevertWhenUsernameTooShort(address custody, uint8 initialUsernameLength_) public {
        // Bound inputs that need to be bound.
        vm.assume(custody != address(0));

        uint256 initialUsernameLength = _boundUsernameLength(initialUsernameLength_);
        string memory initialUsername = _getRandomValidUniqueUsername(initialUsernameLength);

        // Currently, usernames of a single character are acceptable, so the only invalid length is 0.
        string memory newUsername = "";

        // Register the custody address with its initial username.
        _register(custody, initialUsername);
        uint256 id = idRegistry.idOf(custody);

        // Verify that the username was registered.
        assertEq(idRegistry.usernameOf(id), initialUsername);

        // Attempt to change the username.
        vm.expectRevert(UsernameTooShort.selector);
        vm.prank(custody);
        idGateway.changeUsername(newUsername);
    }

    function testFuzz_changeUsername_RevertWhenUsernameContainsInvalidChar(
        address custody,
        uint8 initialUsernameLength_,
        bytes16 newUsernameBytes_
    ) public {
        // Bound inputs that need to be bound.
        vm.assume(custody != address(0));

        uint256 initialUsernameLength = _boundUsernameLength(initialUsernameLength_);
        string memory initialUsername = _getRandomValidUniqueUsername(initialUsernameLength);
        string memory newUsername = string(abi.encodePacked(newUsernameBytes_));
        vm.assume(!_validateUsernameCharacters(newUsername));

        // Register the custody address with its initial username.
        _register(custody, initialUsername);
        uint256 id = idRegistry.idOf(custody);

        // Verify that the username was registered.
        assertEq(idRegistry.usernameOf(id), initialUsername);

        // Attempt to change the username.
        vm.expectRevert(UsernameContainsInvalidChar.selector);
        vm.prank(custody);
        idGateway.changeUsername(newUsername);
    }

    // =============================================================
    //                        changeUsernameFor()
    // =============================================================

    function testFuzz_changeUsernameFor(
        address registrar,
        uint256 custodyPk_,
        uint8 initialUsernameLength_,
        uint8 newUsernameLength_,
        uint40 deadline_
    ) public {
        // Bound inputs that need to be bound.
        uint256 custodyPk = _boundPk(custodyPk_);
        address custody = vm.addr(custodyPk);

        uint256 initialUsernameLength = _boundUsernameLength(initialUsernameLength_);
        string memory initialUsername = _getRandomValidUniqueUsername(initialUsernameLength);
        uint256 newUsernameLength = _boundUsernameLength(newUsernameLength_);
        string memory newUsername = _getRandomValidUniqueUsername(newUsernameLength);

        uint256 deadline = _boundDeadline(deadline_);

        // Register the from address with its initial username.
        _register(custody, initialUsername);
        uint256 id = idRegistry.idOf(custody);

        // Verify that the username was registered.
        assertEq(idRegistry.usernameOf(id), initialUsername);

        // Change the username.
        bytes memory sig = _signChangeUsername(custodyPk, custody, id, newUsername, deadline);
        vm.expectEmit();
        emit UsernameChanged(id, newUsername);
        vm.prank(registrar);
        idGateway.changeUsernameFor(id, newUsername, deadline, sig);

        // Assert that the username was updated.
        assertEq(idRegistry.usernameOf(id), newUsername);
    }

    function testFuzz_changeUsernameFor_RevertWhenIdRegistryPaused(
        address registrar,
        uint256 custodyPk_,
        uint8 initialUsernameLength_,
        uint8 newUsernameLength_,
        uint40 deadline_
    ) public {
        // Bound inputs that need to be bound.
        uint256 custodyPk = _boundPk(custodyPk_);
        address custody = vm.addr(custodyPk);

        uint256 initialUsernameLength = _boundUsernameLength(initialUsernameLength_);
        string memory initialUsername = _getRandomValidUniqueUsername(initialUsernameLength);
        uint256 newUsernameLength = _boundUsernameLength(newUsernameLength_);
        string memory newUsername = _getRandomValidUniqueUsername(newUsernameLength);

        uint256 deadline = _boundDeadline(deadline_);

        // Register the from address with its initial username.
        _register(custody, initialUsername);
        uint256 id = idRegistry.idOf(custody);

        // Verify that the username was registered.
        assertEq(idRegistry.usernameOf(id), initialUsername);

        // Pause IdRegistry
        vm.prank(ID_REGISTRY_OWNER);
        idRegistry.pause();

        // Change the username.
        bytes memory sig = _signChangeUsername(custodyPk, custody, id, newUsername, deadline);
        vm.expectRevert(EnforcedPause.selector);
        vm.prank(registrar);
        idGateway.changeUsernameFor(id, newUsername, deadline, sig);

        // Assert that the username was NOT updated.
        assertEq(idRegistry.usernameOf(id), initialUsername);
    }

    function testFuzz_changeUsernameFor_RevertWhenIdGatewayPaused(
        address registrar,
        uint256 custodyPk_,
        uint8 initialUsernameLength_,
        uint8 newUsernameLength_,
        uint40 deadline_
    ) public {
        // Bound inputs that need to be bound.
        uint256 custodyPk = _boundPk(custodyPk_);
        address custody = vm.addr(custodyPk);

        uint256 initialUsernameLength = _boundUsernameLength(initialUsernameLength_);
        string memory initialUsername = _getRandomValidUniqueUsername(initialUsernameLength);
        uint256 newUsernameLength = _boundUsernameLength(newUsernameLength_);
        string memory newUsername = _getRandomValidUniqueUsername(newUsernameLength);

        uint256 deadline = _boundDeadline(deadline_);

        // Register the from address with its initial username.
        _register(custody, initialUsername);
        uint256 id = idRegistry.idOf(custody);

        // Verify that the username was registered.
        assertEq(idRegistry.usernameOf(id), initialUsername);

        // Pause IdGateway
        vm.prank(ID_GATEWAY_OWNER);
        idGateway.pause();

        // Attempt to change the username.
        bytes memory sig = _signChangeUsername(custodyPk, custody, id, newUsername, deadline);

        vm.expectRevert(EnforcedPause.selector);
        vm.prank(registrar);
        idGateway.changeUsernameFor(id, newUsername, deadline, sig);
    }

    function testFuzz_changeUsernameFor_RevertWhenUsernameAlreadyRegistered(
        address registrar,
        uint256 custodyPk_,
        address charlie,
        uint8 initialUsernameLength_,
        uint8 newUsernameLength_,
        uint40 deadline_
    ) public {
        // Bound inputs that need to be bound.
        uint256 custodyPk = _boundPk(custodyPk_);
        address custody = vm.addr(custodyPk);
        vm.assume(charlie != address(0) && charlie != custody);

        uint256 initialUsernameLength = _boundUsernameLength(initialUsernameLength_);
        string memory initialUsername = _getRandomValidUniqueUsername(initialUsernameLength);
        uint256 newUsernameLength = _boundUsernameLength(newUsernameLength_);
        string memory newUsername = _getRandomValidUniqueUsername(newUsernameLength);

        uint256 deadline = _boundDeadline(deadline_);

        // Register the from address with its initial username.
        _register(custody, initialUsername);
        uint256 id = idRegistry.idOf(custody);

        // Register a random 3rd person (charlie) with the desired newUsername.
        _register(charlie, newUsername);

        // Verify that the username was registered.
        assertEq(idRegistry.usernameOf(id), initialUsername);

        // Attempt to change the username.
        bytes memory sig = _signChangeUsername(custodyPk, custody, id, newUsername, deadline);

        vm.expectRevert(UsernameAlreadyRegistered.selector);
        vm.prank(registrar);
        idGateway.changeUsernameFor(id, newUsername, deadline, sig);
    }

    function testFuzz_changeUsernameFor_RevertWhenUsernameTooLong(
        address registrar,
        uint256 custodyPk_,
        uint8 initialUsernameLength_,
        uint8 newUsernameLength_,
        uint40 deadline_
    ) public {
        // Bound inputs that need to be bound.
        uint256 custodyPk = _boundPk(custodyPk_);
        address custody = vm.addr(custodyPk);

        uint256 initialUsernameLength = _boundUsernameLength(initialUsernameLength_);
        string memory initialUsername = _getRandomValidUniqueUsername(initialUsernameLength);
        uint256 invalidUsernameLength = _boundUsernameLengthTooLong(newUsernameLength_);
        string memory newUsername = _getRandomValidUniqueUsername(invalidUsernameLength);

        uint256 deadline = _boundDeadline(deadline_);

        // Register the from address with its initial username.
        _register(custody, initialUsername);
        uint256 id = idRegistry.idOf(custody);

        // Verify that the username was registered.
        assertEq(idRegistry.usernameOf(id), initialUsername);

        // Attempt to change the username.
        bytes memory sig = _signChangeUsername(custodyPk, custody, id, newUsername, deadline);

        vm.expectRevert(UsernameTooLong.selector);
        vm.prank(registrar);
        idGateway.changeUsernameFor(id, newUsername, deadline, sig);
    }

    function testFuzz_changeUsernameFor_RevertWhenUsernameTooShort(
        address registrar,
        uint256 custodyPk_,
        uint8 initialUsernameLength_,
        uint40 deadline_
    ) public {
        // Bound inputs that need to be bound.
        uint256 custodyPk = _boundPk(custodyPk_);
        address custody = vm.addr(custodyPk);

        uint256 initialUsernameLength = _boundUsernameLength(initialUsernameLength_);
        string memory initialUsername = _getRandomValidUniqueUsername(initialUsernameLength);
        // Currently, usernames of a single character are acceptable, so the only invalid length is 0.
        string memory newUsername = "";

        uint256 deadline = _boundDeadline(deadline_);

        // Register the from address with its initial username.
        _register(custody, initialUsername);
        uint256 id = idRegistry.idOf(custody);

        // Verify that the username was registered.
        assertEq(idRegistry.usernameOf(id), initialUsername);

        // Attempt to change the username.
        bytes memory sig = _signChangeUsername(custodyPk, custody, id, newUsername, deadline);

        vm.expectRevert(UsernameTooShort.selector);
        vm.prank(registrar);
        idGateway.changeUsernameFor(id, newUsername, deadline, sig);
    }

    function testFuzz_changeUsernameFor_RevertWhenUsernameContainsInvalidChar(
        address registrar,
        uint256 custodyPk_,
        uint8 initialUsernameLength_,
        bytes16 newUsernameBytes_,
        uint40 deadline_
    ) public {
        // Bound inputs that need to be bound.
        uint256 custodyPk = _boundPk(custodyPk_);
        address custody = vm.addr(custodyPk);

        uint256 initialUsernameLength = _boundUsernameLength(initialUsernameLength_);
        string memory initialUsername = _getRandomValidUniqueUsername(initialUsernameLength);
        string memory newUsername = string(abi.encodePacked(newUsernameBytes_));
        vm.assume(!_validateUsernameCharacters(newUsername));

        uint256 deadline = _boundDeadline(deadline_);

        // Register the from address with its initial username.
        _register(custody, initialUsername);
        uint256 id = idRegistry.idOf(custody);

        // Verify that the username was registered.
        assertEq(idRegistry.usernameOf(id), initialUsername);

        // Attempt to change the username.
        bytes memory sig = _signChangeUsername(custodyPk, custody, id, newUsername, deadline);

        vm.expectRevert(UsernameContainsInvalidChar.selector);
        vm.prank(registrar);
        idGateway.changeUsernameFor(id, newUsername, deadline, sig);
    }

    // Signature reverts
    // TODO: testFuzz_transferUsername_RevertWhenDeadlineExpired
    // TODO: testFuzz_transferUsername_RevertWhenNonceInvalid
    // TODO: testFuzz_transferUsername_RevertWhenSignerInvalid

    // =============================================================
    //                        forceTransferUsername()
    // =============================================================

    function testFuzz_forceTransferUsername(
        address from,
        address to,
        uint8 initialFromUsernameLength_,
        uint8 initialToUsernameLength_,
        uint8 newFromUsernameLength_
    ) public {
        // Bound inputs that need to be bound.
        vm.assume(from != address(0) && to != address(0) && from != to);

        uint256 initialFromUsernameLength = _boundUsernameLength(initialFromUsernameLength_);
        string memory initialFromUsername = _getRandomValidUniqueUsername(initialFromUsernameLength);
        uint256 initialToUsernameLength = _boundUsernameLength(initialToUsernameLength_);
        string memory initialToUsername = _getRandomValidUniqueUsername(initialToUsernameLength);
        uint256 newFromUsernameLength = _boundUsernameLength(newFromUsernameLength_);
        string memory newFromUsername = _getRandomValidUniqueUsername(newFromUsernameLength);

        // Register the from and to addresses with their initial usernames.
        _register(from, initialFromUsername);
        _register(to, initialToUsername);
        uint256 fromId = idRegistry.idOf(from);
        uint256 toId = idRegistry.idOf(to);

        // Verify that the usernames were registered.
        assertEq(idRegistry.usernameOf(fromId), initialFromUsername);
        assertEq(idRegistry.usernameOf(toId), initialToUsername);

        // Force a transfer of the username
        vm.expectEmit();
        emit UsernameChanged(fromId, newFromUsername);
        vm.expectEmit();
        emit UsernameChanged(toId, initialFromUsername);
        vm.expectEmit();
        emit UsernameTransferred(fromId, toId, initialFromUsername);

        vm.prank(ID_GATEWAY_OWNER);
        idGateway.forceTransferUsername(fromId, toId, newFromUsername);

        // Assert that the username was transferred,
        // and that the `from` address has the `newFromUsername`.
        assertEq(idRegistry.usernameOf(fromId), newFromUsername);
        assertEq(idRegistry.usernameOf(toId), initialFromUsername);
    }

    /// @dev Test `forceTransferUsername()` still works even when the IdGateway is paused.
    function testFuzz_forceTransferUsername_WhenIdGatewayPaused(
        address from,
        address to,
        uint8 initialFromUsernameLength_,
        uint8 initialToUsernameLength_,
        uint8 newFromUsernameLength_
    ) public {
        // Bound inputs that need to be bound.
        vm.assume(from != address(0) && to != address(0) && from != to);

        uint256 initialFromUsernameLength = _boundUsernameLength(initialFromUsernameLength_);
        string memory initialFromUsername = _getRandomValidUniqueUsername(initialFromUsernameLength);
        uint256 initialToUsernameLength = _boundUsernameLength(initialToUsernameLength_);
        string memory initialToUsername = _getRandomValidUniqueUsername(initialToUsernameLength);
        uint256 newFromUsernameLength = _boundUsernameLength(newFromUsernameLength_);
        string memory newFromUsername = _getRandomValidUniqueUsername(newFromUsernameLength);

        // Register the from and to addresses with their initial usernames.
        _register(from, initialFromUsername);
        _register(to, initialToUsername);
        uint256 fromId = idRegistry.idOf(from);
        uint256 toId = idRegistry.idOf(to);

        // Verify that the usernames were registered.
        assertEq(idRegistry.usernameOf(fromId), initialFromUsername);
        assertEq(idRegistry.usernameOf(toId), initialToUsername);

        // Pause IdGateway
        vm.prank(ID_GATEWAY_OWNER);
        idGateway.pause();

        // Force a transfer of the username
        vm.expectEmit();
        emit UsernameChanged(fromId, newFromUsername);
        vm.expectEmit();
        emit UsernameChanged(toId, initialFromUsername);
        vm.expectEmit();
        emit UsernameTransferred(fromId, toId, initialFromUsername);

        vm.prank(ID_GATEWAY_OWNER);
        idGateway.forceTransferUsername(fromId, toId, newFromUsername);

        // Assert that the username was transferred,
        // and that the `from` address has the `newFromUsername`.
        assertEq(idRegistry.usernameOf(fromId), newFromUsername);
        assertEq(idRegistry.usernameOf(toId), initialFromUsername);
    }

    function testFuzz_forceTransferUsername_RevertWhenIdRegistryPaused(
        address from,
        address to,
        uint8 initialFromUsernameLength_,
        uint8 initialToUsernameLength_,
        uint8 newFromUsernameLength_
    ) public {
        // Bound inputs that need to be bound.
        vm.assume(from != address(0) && to != address(0) && from != to);

        uint256 initialFromUsernameLength = _boundUsernameLength(initialFromUsernameLength_);
        string memory initialFromUsername = _getRandomValidUniqueUsername(initialFromUsernameLength);
        uint256 initialToUsernameLength = _boundUsernameLength(initialToUsernameLength_);
        string memory initialToUsername = _getRandomValidUniqueUsername(initialToUsernameLength);
        uint256 newFromUsernameLength = _boundUsernameLength(newFromUsernameLength_);
        string memory newFromUsername = _getRandomValidUniqueUsername(newFromUsernameLength);

        // Register the from and to addresses with their initial usernames.
        _register(from, initialFromUsername);
        _register(to, initialToUsername);
        uint256 fromId = idRegistry.idOf(from);
        uint256 toId = idRegistry.idOf(to);

        // Verify that the usernames were registered.
        assertEq(idRegistry.usernameOf(fromId), initialFromUsername);
        assertEq(idRegistry.usernameOf(toId), initialToUsername);

        // Pause IdRegistry
        vm.prank(ID_REGISTRY_OWNER);
        idRegistry.pause();

        // Attempt orce a transfer of the username
        vm.expectRevert(EnforcedPause.selector);
        vm.prank(ID_GATEWAY_OWNER);
        idGateway.forceTransferUsername(fromId, toId, newFromUsername);

        // Assert that the username was NOT transferred.
        assertEq(idRegistry.usernameOf(fromId), initialFromUsername);
        assertEq(idRegistry.usernameOf(toId), initialToUsername);
    }

    function testFuzz_forceTransferUsername_RevertWhenCalledByNonOwner(
        address caller,
        address from,
        address to,
        uint8 initialFromUsernameLength_,
        uint8 initialToUsernameLength_,
        uint8 newFromUsernameLength_
    ) public {
        // Bound inputs that need to be bound.
        vm.assume(caller != ID_GATEWAY_OWNER);
        vm.assume(from != address(0) && to != address(0) && from != to);

        uint256 initialFromUsernameLength = _boundUsernameLength(initialFromUsernameLength_);
        string memory initialFromUsername = _getRandomValidUniqueUsername(initialFromUsernameLength);
        uint256 initialToUsernameLength = _boundUsernameLength(initialToUsernameLength_);
        string memory initialToUsername = _getRandomValidUniqueUsername(initialToUsernameLength);
        uint256 newFromUsernameLength = _boundUsernameLength(newFromUsernameLength_);
        string memory newFromUsername = _getRandomValidUniqueUsername(newFromUsernameLength);

        // Register the from and to addresses with their initial usernames.
        _register(from, initialFromUsername);
        _register(to, initialToUsername);
        uint256 fromId = idRegistry.idOf(from);
        uint256 toId = idRegistry.idOf(to);

        // Verify that the usernames were registered.
        assertEq(idRegistry.usernameOf(fromId), initialFromUsername);
        assertEq(idRegistry.usernameOf(toId), initialToUsername);

        // Attempt to force a transfer of the username
        vm.expectRevert(Unauthorized.selector);
        vm.prank(caller);
        idGateway.forceTransferUsername(fromId, toId, newFromUsername);
    }

    function testFuzz_forceTransferUsername_RevertWhenUsernameAlreadyRegistered(
        address from,
        address to,
        address charlie,
        uint8 initialFromUsernameLength_,
        uint8 initialToUsernameLength_,
        uint8 newFromUsernameLength_
    ) public {
        // Bound inputs that need to be bound.
        vm.assume(from != address(0) && to != address(0) && from != to);
        vm.assume(charlie != address(0) && charlie != from && charlie != to);

        uint256 initialFromUsernameLength = _boundUsernameLength(initialFromUsernameLength_);
        string memory initialFromUsername = _getRandomValidUniqueUsername(initialFromUsernameLength);
        uint256 initialToUsernameLength = _boundUsernameLength(initialToUsernameLength_);
        string memory initialToUsername = _getRandomValidUniqueUsername(initialToUsernameLength);
        uint256 newFromUsernameLength = _boundUsernameLength(newFromUsernameLength_);
        string memory newFromUsername = _getRandomValidUniqueUsername(newFromUsernameLength);

        // Register the from and to addresses with their initial usernames.
        _register(from, initialFromUsername);
        _register(to, initialToUsername);
        uint256 fromId = idRegistry.idOf(from);
        uint256 toId = idRegistry.idOf(to);

        // Register a random 3rd person (charlie) with the desired newFromUsername,
        // before `from` has a chance to register it.
        _register(charlie, newFromUsername);

        // Verify that the usernames were registered.
        assertEq(idRegistry.usernameOf(fromId), initialFromUsername);
        assertEq(idRegistry.usernameOf(toId), initialToUsername);
        assertEq(idRegistry.usernameOf(idRegistry.idOf(charlie)), newFromUsername);

        // Attempt to force a transfer of the username
        vm.expectRevert(UsernameAlreadyRegistered.selector);
        vm.prank(ID_GATEWAY_OWNER);
        idGateway.forceTransferUsername(fromId, toId, newFromUsername);
    }

    function testFuzz_forceTransferUsername_RevertWhenUsernameTooLong(
        address from,
        address to,
        uint8 initialFromUsernameLength_,
        uint8 initialToUsernameLength_,
        uint8 newFromUsernameLength_
    ) public {
        // Bound inputs that need to be bound.
        vm.assume(from != address(0) && to != address(0) && from != to);

        uint256 initialFromUsernameLength = _boundUsernameLength(initialFromUsernameLength_);
        string memory initialFromUsername = _getRandomValidUniqueUsername(initialFromUsernameLength);
        uint256 initialToUsernameLength = _boundUsernameLength(initialToUsernameLength_);
        string memory initialToUsername = _getRandomValidUniqueUsername(initialToUsernameLength);
        uint256 invalidUsernameLength = _boundUsernameLengthTooLong(newFromUsernameLength_);
        string memory newFromUsername = _getRandomValidUniqueUsername(invalidUsernameLength);

        // Register the from and to addresses with their initial usernames.
        _register(from, initialFromUsername);
        _register(to, initialToUsername);
        uint256 fromId = idRegistry.idOf(from);
        uint256 toId = idRegistry.idOf(to);

        // Verify that the usernames were registered.
        assertEq(idRegistry.usernameOf(fromId), initialFromUsername);
        assertEq(idRegistry.usernameOf(toId), initialToUsername);

        // Attempt to force a transfer of the username
        vm.expectRevert(UsernameTooLong.selector);
        vm.prank(ID_GATEWAY_OWNER);
        idGateway.forceTransferUsername(fromId, toId, newFromUsername);
    }

    function testFuzz_forceTransferUsername_RevertWhenUsernameTooShort(
        address from,
        address to,
        uint8 initialFromUsernameLength_,
        uint8 initialToUsernameLength_
    ) public {
        // Bound inputs that need to be bound.
        vm.assume(from != address(0) && to != address(0) && from != to);

        uint256 initialFromUsernameLength = _boundUsernameLength(initialFromUsernameLength_);
        string memory initialFromUsername = _getRandomValidUniqueUsername(initialFromUsernameLength);
        uint256 initialToUsernameLength = _boundUsernameLength(initialToUsernameLength_);
        string memory initialToUsername = _getRandomValidUniqueUsername(initialToUsernameLength);
        // Currently, usernames of a single character are acceptable, so the only invalid length is 0.
        string memory newFromUsername = "";

        // Register the from and to addresses with their initial usernames.
        _register(from, initialFromUsername);
        _register(to, initialToUsername);
        uint256 fromId = idRegistry.idOf(from);
        uint256 toId = idRegistry.idOf(to);

        // Verify that the usernames were registered.
        assertEq(idRegistry.usernameOf(fromId), initialFromUsername);
        assertEq(idRegistry.usernameOf(toId), initialToUsername);

        // Attempt to force a transfer of the username
        vm.expectRevert(UsernameTooShort.selector);
        vm.prank(ID_GATEWAY_OWNER);
        idGateway.forceTransferUsername(fromId, toId, newFromUsername);
    }

    function testFuzz_forceTransferUsername_RevertWhenUsernameContainsInvalidChar(
        address from,
        address to,
        uint8 initialFromUsernameLength_,
        uint8 initialToUsernameLength_,
        bytes16 newFromUsernameBytes_
    ) public {
        // Bound inputs that need to be bound.
        vm.assume(from != address(0) && to != address(0) && from != to);

        uint256 initialFromUsernameLength = _boundUsernameLength(initialFromUsernameLength_);
        string memory initialFromUsername = _getRandomValidUniqueUsername(initialFromUsernameLength);
        uint256 initialToUsernameLength = _boundUsernameLength(initialToUsernameLength_);
        string memory initialToUsername = _getRandomValidUniqueUsername(initialToUsernameLength);
        string memory newFromUsername = string(abi.encodePacked(newFromUsernameBytes_));
        vm.assume(!_validateUsernameCharacters(newFromUsername));

        // Register the from and to addresses with their initial usernames.
        _register(from, initialFromUsername);
        _register(to, initialToUsername);
        uint256 fromId = idRegistry.idOf(from);
        uint256 toId = idRegistry.idOf(to);

        // Verify that the usernames were registered.
        assertEq(idRegistry.usernameOf(fromId), initialFromUsername);
        assertEq(idRegistry.usernameOf(toId), initialToUsername);

        // Attempt to force a transfer of the username
        vm.expectRevert(UsernameContainsInvalidChar.selector);
        vm.prank(ID_GATEWAY_OWNER);
        idGateway.forceTransferUsername(fromId, toId, newFromUsername);
    }

    // =============================================================
    //                        forceChangeUsername()
    // =============================================================

    function testFuzz_forceChangeUsername(address custody, uint8 initialUsernameLength_, uint8 newUsernameLength_)
        public
    {
        // Bound inputs that need to be bound.
        vm.assume(custody != address(0));

        uint256 initialUsernameLength = _boundUsernameLength(initialUsernameLength_);
        string memory initialUsername = _getRandomValidUniqueUsername(initialUsernameLength);
        uint256 newUsernameLength = _boundUsernameLength(newUsernameLength_);
        string memory newUsername = _getRandomValidUniqueUsername(newUsernameLength);

        // Register the custody address with its initial username.
        _register(custody, initialUsername);
        uint256 id = idRegistry.idOf(custody);

        // Verify that the username was registered.
        assertEq(idRegistry.usernameOf(id), initialUsername);

        // Change the username.
        vm.expectEmit();
        emit UsernameChanged(id, newUsername);
        vm.prank(ID_GATEWAY_OWNER);
        idGateway.forceChangeUsername(id, newUsername);

        // Assert that the username was updated.
        assertEq(idRegistry.usernameOf(id), newUsername);
    }

    function testFuzz_forceChangeUsername_WhenIdGatewayPaused(
        address custody,
        uint8 initialUsernameLength_,
        uint8 newUsernameLength_
    ) public {
        // Bound inputs that need to be bound.
        vm.assume(custody != address(0));

        uint256 initialUsernameLength = _boundUsernameLength(initialUsernameLength_);
        string memory initialUsername = _getRandomValidUniqueUsername(initialUsernameLength);
        uint256 newUsernameLength = _boundUsernameLength(newUsernameLength_);
        string memory newUsername = _getRandomValidUniqueUsername(newUsernameLength);

        // Register the custody address with its initial username.
        _register(custody, initialUsername);
        uint256 id = idRegistry.idOf(custody);

        // Verify that the username was registered.
        assertEq(idRegistry.usernameOf(id), initialUsername);

        // Pause IdGateway
        vm.prank(ID_GATEWAY_OWNER);
        idGateway.pause();

        // Change the username.
        vm.expectEmit();
        emit UsernameChanged(id, newUsername);
        vm.prank(ID_GATEWAY_OWNER);
        idGateway.forceChangeUsername(id, newUsername);

        // Assert that the username was updated.
        assertEq(idRegistry.usernameOf(id), newUsername);
    }

    function testFuzz_forceChangeUsername_RevertWhenIdRegistryPaused(
        address custody,
        uint8 initialUsernameLength_,
        uint8 newUsernameLength_
    ) public {
        // Bound inputs that need to be bound.
        vm.assume(custody != address(0));

        uint256 initialUsernameLength = _boundUsernameLength(initialUsernameLength_);
        string memory initialUsername = _getRandomValidUniqueUsername(initialUsernameLength);
        uint256 newUsernameLength = _boundUsernameLength(newUsernameLength_);
        string memory newUsername = _getRandomValidUniqueUsername(newUsernameLength);

        // Register the custody address with its initial username.
        _register(custody, initialUsername);
        uint256 id = idRegistry.idOf(custody);

        // Verify that the username was registered.
        assertEq(idRegistry.usernameOf(id), initialUsername);

        // Pause IdRegistry
        vm.prank(ID_REGISTRY_OWNER);
        idRegistry.pause();

        // Attempt to change the username.
        vm.expectRevert(EnforcedPause.selector);
        vm.prank(ID_GATEWAY_OWNER);
        idGateway.forceChangeUsername(id, newUsername);

        // Assert that the username was NOT updated.
        assertEq(idRegistry.usernameOf(id), initialUsername);
    }

    function testFuzz_forceChangeUsername_RevertWhenCalledByNonOwner(
        address caller,
        address custody,
        uint8 initialUsernameLength_,
        uint8 newUsernameLength_
    ) public {
        // Bound inputs that need to be bound.
        vm.assume(caller != ID_GATEWAY_OWNER);
        vm.assume(custody != address(0));

        uint256 initialUsernameLength = _boundUsernameLength(initialUsernameLength_);
        string memory initialUsername = _getRandomValidUniqueUsername(initialUsernameLength);
        uint256 newUsernameLength = _boundUsernameLength(newUsernameLength_);
        string memory newUsername = _getRandomValidUniqueUsername(newUsernameLength);

        // Register the custody address with its initial username.
        _register(custody, initialUsername);
        uint256 id = idRegistry.idOf(custody);

        // Verify that the username was registered.
        assertEq(idRegistry.usernameOf(id), initialUsername);

        // Change the username.
        vm.expectRevert(Unauthorized.selector);
        vm.prank(caller);
        idGateway.forceChangeUsername(id, newUsername);
    }

    function testFuzz_forceChangeUsername_RevertWhenUsernameAlreadyRegistered(
        address custody,
        address charlie,
        uint8 initialUsernameLength_,
        uint8 newUsernameLength_
    ) public {
        // Bound inputs that need to be bound.
        vm.assume(custody != address(0));
        vm.assume(charlie != address(0) && charlie != custody);

        uint256 initialUsernameLength = _boundUsernameLength(initialUsernameLength_);
        string memory initialUsername = _getRandomValidUniqueUsername(initialUsernameLength);
        uint256 newUsernameLength = _boundUsernameLength(newUsernameLength_);
        string memory newUsername = _getRandomValidUniqueUsername(newUsernameLength);

        // Register the custody address with its initial username.
        _register(custody, initialUsername);
        uint256 id = idRegistry.idOf(custody);

        // Register a random 3rd person (charlie) with the desired newUsername,
        // before `custody` has a chance to register it.
        _register(charlie, newUsername);

        // Verify that the username was registered.
        assertEq(idRegistry.usernameOf(id), initialUsername);
        assertEq(idRegistry.usernameOf(idRegistry.idOf(charlie)), newUsername);

        // Change the username.
        vm.expectRevert(UsernameAlreadyRegistered.selector);
        vm.prank(ID_GATEWAY_OWNER);
        idGateway.forceChangeUsername(id, newUsername);
    }

    function testFuzz_forceChangeUsername_RevertWhenUsernameTooLong(
        address custody,
        uint8 initialUsernameLength_,
        uint8 newUsernameLength_
    ) public {
        // Bound inputs that need to be bound.
        vm.assume(custody != address(0));

        uint256 initialUsernameLength = _boundUsernameLength(initialUsernameLength_);
        string memory initialUsername = _getRandomValidUniqueUsername(initialUsernameLength);
        uint256 invalidUsernameLength = _boundUsernameLengthTooLong(newUsernameLength_);
        string memory newUsername = _getRandomValidUniqueUsername(invalidUsernameLength);

        // Register the custody address with its initial username.
        _register(custody, initialUsername);
        uint256 id = idRegistry.idOf(custody);

        // Verify that the username was registered.
        assertEq(idRegistry.usernameOf(id), initialUsername);

        // Change the username.
        vm.expectRevert(UsernameTooLong.selector);
        vm.prank(ID_GATEWAY_OWNER);
        idGateway.forceChangeUsername(id, newUsername);
    }

    function testFuzz_forceChangeUsername_RevertWhenUsernameTooShort(address custody, uint8 initialUsernameLength_)
        public
    {
        // Bound inputs that need to be bound.
        vm.assume(custody != address(0));

        uint256 initialUsernameLength = _boundUsernameLength(initialUsernameLength_);
        string memory initialUsername = _getRandomValidUniqueUsername(initialUsernameLength);
        // Currently, usernames of a single character are acceptable, so the only invalid length is 0.
        string memory newUsername = "";

        // Register the custody address with its initial username.
        _register(custody, initialUsername);
        uint256 id = idRegistry.idOf(custody);

        // Verify that the username was registered.
        assertEq(idRegistry.usernameOf(id), initialUsername);

        // Change the username.
        vm.expectRevert(UsernameTooShort.selector);
        vm.prank(ID_GATEWAY_OWNER);
        idGateway.forceChangeUsername(id, newUsername);
    }

    function testFuzz_forceChangeUsername_RevertWhenUsernameContainsInvalidChar(
        address custody,
        uint8 initialUsernameLength_,
        bytes16 newUsernameBytes_
    ) public {
        // Bound inputs that need to be bound.
        vm.assume(custody != address(0));

        uint256 initialUsernameLength = _boundUsernameLength(initialUsernameLength_);
        string memory initialUsername = _getRandomValidUniqueUsername(initialUsernameLength);
        string memory newUsername = string(abi.encodePacked(newUsernameBytes_));
        vm.assume(!_validateUsernameCharacters(newUsername));

        // Register the custody address with its initial username.
        _register(custody, initialUsername);
        uint256 id = idRegistry.idOf(custody);

        // Verify that the username was registered.
        assertEq(idRegistry.usernameOf(id), initialUsername);

        // Change the username.
        vm.expectRevert(UsernameContainsInvalidChar.selector);
        vm.prank(ID_GATEWAY_OWNER);
        idGateway.forceChangeUsername(id, newUsername);
    }

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
        idGateway.recover(id, to, deadline, sig);

        // Check that the ID was transferred.
        _assertTransferPostconditions(id, from, to, username, recovery);
    }

    // TODO:
    // =============================================================
    //                      recoverFor()
    // =============================================================

    // =============================================================
    //                        checkUsername()
    // =============================================================

    function testFuzz_checkUsername(uint8 usernameLength_) public {
        // Bound inputs that need to be bound.
        uint256 usernameLength = _boundUsernameLength(usernameLength_);
        string memory username = _getRandomValidUniqueUsername(usernameLength);

        // Check the username.
        bool isValid = idGateway.checkUsername(username);
        assertEq(isValid, true);
    }

    function testFuzz_checkUsername_RevertWhenUsernameAlreadyRegistered(uint8 usernameLength_, address charlie)
        public
    {
        // Bound inputs that need to be bound.
        uint256 usernameLength = _boundUsernameLength(usernameLength_);
        string memory username = _getRandomValidUniqueUsername(usernameLength);

        vm.assume(charlie != address(0));

        // Register a random 3rd person (charlie) with the desired username.
        _register(charlie, username);
        assertEq(idRegistry.usernameOf(idRegistry.idOf(charlie)), username);

        // Check the username.
        vm.expectRevert(UsernameAlreadyRegistered.selector);
        idGateway.checkUsername(username);
    }

    function testFuzz_checkUsername_RevertWhenUsernameTooLong(uint8 usernameLength_) public {
        // Bound inputs that need to be bound.
        uint256 invalidUsernameLength = _boundUsernameLengthTooLong(usernameLength_);
        string memory username = _getRandomValidUniqueUsername(invalidUsernameLength);

        // Check the username.
        vm.expectRevert(UsernameTooLong.selector);
        idGateway.checkUsername(username);
    }

    function test_checkUsername_RevertWhenUsernameTooShort() public {
        // Currently, usernames of a single character are acceptable, so the only invalid length is 0.
        string memory username = "";

        // Check the username.
        vm.expectRevert(UsernameTooShort.selector);
        idGateway.checkUsername(username);
    }

    function test_checkUsername_RevertWhenUsernameIsEmpty() public {
        // Check the username.
        vm.expectRevert(UsernameTooShort.selector);
        idGateway.checkUsername("");
    }

    function testFuzz_checkUsername_RevertWhenUsernameContainsInvalidChar(bytes16 usernameBytes_) public {
        // Bound inputs that need to be bound.
        string memory username = string(abi.encodePacked(usernameBytes_));
        vm.assume(!_validateUsernameCharacters(username));

        // Check the username.
        vm.expectRevert(UsernameContainsInvalidChar.selector);
        idGateway.checkUsername(username);
    }

    // =============================================================
    //                        ASSERTION HELPERS
    // =============================================================

    /// @dev Assert that all the state for all provided parameters are the defaults/zero.
    function _assertRegisterPreconditions(uint256 id, address custody) internal view {
        assertEq(idRegistry.idCounter(), 0);

        assertEq(idRegistry.idOf(custody), 0);
        assertEq(idRegistry.custodyOf(id), address(0));
        assertEq(idRegistry.usernameOf(id), "");
        assertEq(idRegistry.recoveryOf(id), address(0));
    }

    /// @dev Assert that all the state for all provided parameters is set as expected.
    function _assertRegisterPostconditions(uint256 id, address custody, string memory username, address recovery)
        internal
        view
    {
        assertEq(idRegistry.idCounter(), id);

        assertEq(idRegistry.idOf(custody), id);
        assertEq(idRegistry.custodyOf(id), custody);
        assertEq(idRegistry.usernameOf(id), username);
        assertEq(idRegistry.getIdByUsername(username), id);
        assertEq(idRegistry.recoveryOf(id), recovery);
    }

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

    /// @dev Sign the EIP712 message for a registerFor transaction.
    function _signRegister(uint256 pk, address custody, string memory username, address recovery, uint256 deadline)
        internal
        view
        returns (bytes memory signature)
    {
        bytes32 digest = idGateway.hashTypedData(
            keccak256(
                abi.encode(
                    idGateway.REGISTER_TYPEHASH(),
                    custody,
                    keccak256(bytes(username)),
                    recovery,
                    idGateway.nonces(custody),
                    deadline
                )
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, digest);
        signature = abi.encodePacked(r, s, v);
        assertEq(signature.length, 65);
    }

    /// @dev Sign the EIP712 message for a transfer transaction.
    function _signTransfer(uint256 pk, uint256 id, address to, uint256 deadline)
        internal
        view
        returns (bytes memory signature)
    {
        bytes32 digest = idGateway.hashTypedData(
            keccak256(abi.encode(idGateway.TRANSFER_TYPEHASH(), id, to, idGateway.nonces(to), deadline))
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, digest);
        signature = abi.encodePacked(r, s, v);
        assertEq(signature.length, 65);
    }

    /// @dev Sign the EIP712 message for a transferUsername transaction.
    function _signTransferUsername(
        uint256 pk,
        address signer,
        uint256 fromId,
        uint256 toId,
        string memory newFromUsername,
        uint256 deadline
    ) internal view returns (bytes memory signature) {
        bytes32 digest = idGateway.hashTypedData(
            keccak256(
                abi.encode(
                    idGateway.TRANSFER_USERNAME_TYPEHASH(),
                    fromId,
                    toId,
                    keccak256(bytes(newFromUsername)),
                    idGateway.nonces(signer),
                    deadline
                )
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, digest);
        signature = abi.encodePacked(r, s, v);
        assertEq(signature.length, 65);
    }

    /// @dev Sign the EIP712 message for a changeUsername transaction.
    function _signChangeUsername(uint256 pk, address signer, uint256 id, string memory username, uint256 deadline)
        internal
        view
        returns (bytes memory signature)
    {
        bytes32 digest = idGateway.hashTypedData(
            keccak256(
                abi.encode(
                    idGateway.CHANGE_USERNAME_TYPEHASH(),
                    id,
                    keccak256(bytes(username)),
                    idGateway.nonces(signer),
                    deadline
                )
            )
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
        bytes32 digest = idGateway.hashTypedData(
            keccak256(abi.encode(idGateway.RECOVER_TYPEHASH(), id, to, idGateway.nonces(to), deadline))
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, digest);
        signature = abi.encodePacked(r, s, v);
        assertEq(signature.length, 65);
    }
}
