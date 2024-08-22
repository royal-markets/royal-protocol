// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ProvenanceTest} from "../ProvenanceTest.sol";

contract UsernameGatewayTest is ProvenanceTest {
    // =============================================================
    //                           EVENTS
    // =============================================================

    event UsernameChanged(uint256 indexed id, string username);
    event UsernameTransferred(uint256 indexed fromId, uint256 indexed toId, string username);

    // =============================================================
    //                           ERRORS
    // =============================================================

    error OnlyCustody();
    error OnlyIdRegistry();

    error UsernameAlreadyRegistered();
    error UsernameTooLong();
    error UsernameTooShort();
    error UsernameContainsInvalidChar();

    // =============================================================
    //                   Constants / Immutables
    // =============================================================

    function test_VERSION() public view {
        assertEq(usernameGateway.VERSION(), "2024-08-22");
    }

    function test_TRANSFER_USERNAME_TYPEHASH() public view {
        assertEq(
            usernameGateway.TRANSFER_USERNAME_TYPEHASH(),
            keccak256(
                "TransferUsername(uint256 fromId,uint256 toId,string newFromUsername,uint256 nonce,uint256 deadline)"
            )
        );
    }

    function test_CHANGE_USERNAME_TYPEHASH() public view {
        assertEq(
            usernameGateway.CHANGE_USERNAME_TYPEHASH(),
            keccak256("ChangeUsername(uint256 id,string newUsername,uint256 nonce,uint256 deadline)")
        );
    }

    function test_ID_REGISTRY() public view {
        assertEq(address(usernameGateway.ID_REGISTRY()), address(idRegistry));
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
        ) = usernameGateway.eip712Domain();

        assertEq(fields, hex"0f");
        assertEq(name, "RoyalProtocol_UsernameGateway");
        assertEq(version, "1");
        assertEq(chainId, block.chainid);
        assertEq(verifyingContract, address(usernameGateway));
        assertEq(salt, bytes32(0));
        assertEq(extensions.length, 0);
    }

    // =============================================================
    //                        constructor()
    // =============================================================

    function test_UnpausedWhenDeployed() public view {
        assertEq(usernameGateway.paused(), false);
    }

    function test_OwnerSetWhenDeployed() public view {
        assertEq(usernameGateway.owner(), USERNAME_GATEWAY_OWNER);
    }

    // =============================================================
    //                        Receiving ETH
    // =============================================================

    function testFuzz_RevertWhenReceivingDirectPayment(address sender, uint256 amount) public {
        vm.deal(sender, amount);
        vm.expectRevert();
        vm.prank(sender);
        payable(address(usernameGateway)).transfer(amount);
    }

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
        usernameGateway.transferUsername(toId, newFromUsername, toDeadline, toSig);

        // Assert that the username was transferred,
        // and that the `from` address has the `newFromUsername`.
        assertEq(idRegistry.usernameOf(fromId), newFromUsername);
        assertEq(idRegistry.usernameOf(toId), initialFromUsername);
    }

    /// @dev Test that transferUsername() still works when the IdRegistry is paused.
    function testFuzz_transferUsername_WhenIdRegistryPaused(
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

        vm.expectEmit();
        emit UsernameChanged(fromId, newFromUsername);
        vm.expectEmit();
        emit UsernameChanged(toId, initialFromUsername);
        vm.expectEmit();
        emit UsernameTransferred(fromId, toId, initialFromUsername);
        vm.prank(from);
        usernameGateway.transferUsername(toId, newFromUsername, toDeadline, toSig);

        // Assert that the username was transferred,
        // and that the `from` address has the `newFromUsername`.
        assertEq(idRegistry.usernameOf(fromId), newFromUsername);
        assertEq(idRegistry.usernameOf(toId), initialFromUsername);
    }

    function testFuzz_transferUsername_RevertWhenUsernameGatewayPaused(
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

        // Pause UsernameGateway
        vm.prank(USERNAME_GATEWAY_OWNER);
        usernameGateway.pause();

        // Attempt to transfer the username, but expect a revert.
        bytes memory toSig = _signChangeUsername(toPk, to, toId, initialFromUsername, toDeadline);
        vm.expectRevert(EnforcedPause.selector);
        vm.prank(from);
        usernameGateway.transferUsername(toId, newFromUsername, toDeadline, toSig);
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
        usernameGateway.transferUsername(toId, newFromUsername, toDeadline, toSig);
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
        usernameGateway.transferUsername(toId, newFromUsername, toDeadline, toSig);
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
        usernameGateway.transferUsername(toId, newFromUsername, toDeadline, toSig);
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
        usernameGateway.transferUsername(toId, newFromUsername, toDeadline, toSig);
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
        usernameGateway.transferUsernameFor(fromId, toId, newFromUsername, fromDeadline, fromSig, toDeadline, toSig);

        // Assert that the username was transferred,
        // and that the `from` address has the `newFromUsername`.
        assertEq(idRegistry.usernameOf(fromId), newFromUsername);
        assertEq(idRegistry.usernameOf(toId), initialFromUsername);
    }

    /// @dev Test that transferUsernameFor() still works when the IdRegistry is paused.
    function testFuzz_transferUsernameFor_WhenIdRegistryPaused(
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

        vm.expectEmit();
        emit UsernameChanged(fromId, newFromUsername);
        vm.expectEmit();
        emit UsernameChanged(toId, initialFromUsername);
        vm.expectEmit();
        emit UsernameTransferred(fromId, toId, initialFromUsername);
        vm.prank(registrar);
        usernameGateway.transferUsernameFor(fromId, toId, newFromUsername, fromDeadline, fromSig, toDeadline, toSig);

        // Assert that the username was transferred,
        // and that the `from` address has the `newFromUsername`.
        assertEq(idRegistry.usernameOf(fromId), newFromUsername);
        assertEq(idRegistry.usernameOf(toId), initialFromUsername);
    }

    function testFuzz_transferUsernameFor_RevertWhenUsernameGatewayPaused(
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

        // Pause UsernameGateway
        vm.prank(USERNAME_GATEWAY_OWNER);
        usernameGateway.pause();

        // Verify that the usernames were registered.
        assertEq(idRegistry.usernameOf(fromId), initialFromUsername);
        assertEq(idRegistry.usernameOf(toId), initialToUsername);

        // Transfer the username, with signature from `to` address accepting the new username.
        bytes memory fromSig = _signTransferUsername(fromPk, from, fromId, toId, newFromUsername, fromDeadline);
        bytes memory toSig = _signChangeUsername(toPk, to, toId, initialFromUsername, toDeadline);
        vm.expectRevert(EnforcedPause.selector);
        vm.prank(registrar);
        usernameGateway.transferUsernameFor(fromId, toId, newFromUsername, fromDeadline, fromSig, toDeadline, toSig);
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
        usernameGateway.transferUsernameFor(fromId, toId, newFromUsername, fromDeadline, fromSig, toDeadline, toSig);
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
        usernameGateway.transferUsernameFor(fromId, toId, newFromUsername, fromDeadline, fromSig, toDeadline, toSig);
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
        usernameGateway.transferUsernameFor(fromId, toId, newFromUsername, fromDeadline, fromSig, toDeadline, toSig);
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
        usernameGateway.transferUsernameFor(fromId, toId, newFromUsername, fromDeadline, fromSig, toDeadline, toSig);
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
        usernameGateway.changeUsername(newUsername);

        // Assert that the username was updated.
        assertEq(idRegistry.usernameOf(id), newUsername);
    }

    function testFuzz_changeUsername_WhenIdRegistryPaused(
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
        vm.expectEmit();
        emit UsernameChanged(id, newUsername);
        vm.prank(custody);
        usernameGateway.changeUsername(newUsername);

        // Assert that the username was updated.
        assertEq(idRegistry.usernameOf(id), newUsername);
    }

    function testFuzz_changeUsername_RevertWhenUsernameGatewayPaused(
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

        // Pause UsernameGateway
        vm.prank(USERNAME_GATEWAY_OWNER);
        usernameGateway.pause();

        // Change the username.
        vm.expectRevert(EnforcedPause.selector);
        vm.prank(custody);
        usernameGateway.changeUsername(newUsername);
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
        usernameGateway.changeUsername(newUsername);
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
        usernameGateway.changeUsername(newUsername);
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
        usernameGateway.changeUsername(newUsername);
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
        usernameGateway.changeUsername(newUsername);
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
        usernameGateway.changeUsernameFor(id, newUsername, deadline, sig);

        // Assert that the username was updated.
        assertEq(idRegistry.usernameOf(id), newUsername);
    }

    function testFuzz_changeUsernameFor_WhenIdRegistryPaused(
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
        vm.expectEmit();
        emit UsernameChanged(id, newUsername);
        vm.prank(registrar);
        usernameGateway.changeUsernameFor(id, newUsername, deadline, sig);

        // Assert that the username was updated.
        assertEq(idRegistry.usernameOf(id), newUsername);
    }

    function testFuzz_changeUsernameFor_RevertWhenUsernameGatewayPaused(
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

        // Pause UsernameGateway
        vm.prank(USERNAME_GATEWAY_OWNER);
        usernameGateway.pause();

        // Attempt to change the username.
        bytes memory sig = _signChangeUsername(custodyPk, custody, id, newUsername, deadline);

        vm.expectRevert(EnforcedPause.selector);
        vm.prank(registrar);
        usernameGateway.changeUsernameFor(id, newUsername, deadline, sig);
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
        usernameGateway.changeUsernameFor(id, newUsername, deadline, sig);
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
        usernameGateway.changeUsernameFor(id, newUsername, deadline, sig);
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
        usernameGateway.changeUsernameFor(id, newUsername, deadline, sig);
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
        usernameGateway.changeUsernameFor(id, newUsername, deadline, sig);
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

        vm.prank(USERNAME_GATEWAY_OWNER);
        usernameGateway.forceTransferUsername(fromId, toId, newFromUsername);

        // Assert that the username was transferred,
        // and that the `from` address has the `newFromUsername`.
        assertEq(idRegistry.usernameOf(fromId), newFromUsername);
        assertEq(idRegistry.usernameOf(toId), initialFromUsername);
    }

    function testFuzz_forceTransferUsername_WhenIdRegistryPaused(
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

        // Force a transfer of the username
        vm.expectEmit();
        emit UsernameChanged(fromId, newFromUsername);
        vm.expectEmit();
        emit UsernameChanged(toId, initialFromUsername);
        vm.expectEmit();
        emit UsernameTransferred(fromId, toId, initialFromUsername);

        vm.prank(USERNAME_GATEWAY_OWNER);
        usernameGateway.forceTransferUsername(fromId, toId, newFromUsername);

        // Assert that the username was transferred,
        // and that the `from` address has the `newFromUsername`.
        assertEq(idRegistry.usernameOf(fromId), newFromUsername);
        assertEq(idRegistry.usernameOf(toId), initialFromUsername);
    }

    /// @dev Test `forceTransferUsername()` still works even when the UsernameGateway is paused.
    function testFuzz_forceTransferUsername_WhenUsernameGatewayPaused(
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

        // Pause UsernameGateway
        vm.prank(USERNAME_GATEWAY_OWNER);
        usernameGateway.pause();

        // Force a transfer of the username
        vm.expectEmit();
        emit UsernameChanged(fromId, newFromUsername);
        vm.expectEmit();
        emit UsernameChanged(toId, initialFromUsername);
        vm.expectEmit();
        emit UsernameTransferred(fromId, toId, initialFromUsername);

        vm.prank(USERNAME_GATEWAY_OWNER);
        usernameGateway.forceTransferUsername(fromId, toId, newFromUsername);

        // Assert that the username was transferred,
        // and that the `from` address has the `newFromUsername`.
        assertEq(idRegistry.usernameOf(fromId), newFromUsername);
        assertEq(idRegistry.usernameOf(toId), initialFromUsername);
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
        vm.assume(caller != USERNAME_GATEWAY_OWNER);
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
        usernameGateway.forceTransferUsername(fromId, toId, newFromUsername);
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
        vm.prank(USERNAME_GATEWAY_OWNER);
        usernameGateway.forceTransferUsername(fromId, toId, newFromUsername);
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
        vm.prank(USERNAME_GATEWAY_OWNER);
        usernameGateway.forceTransferUsername(fromId, toId, newFromUsername);
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
        vm.prank(USERNAME_GATEWAY_OWNER);
        usernameGateway.forceTransferUsername(fromId, toId, newFromUsername);
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
        vm.prank(USERNAME_GATEWAY_OWNER);
        usernameGateway.forceTransferUsername(fromId, toId, newFromUsername);
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
        vm.prank(USERNAME_GATEWAY_OWNER);
        usernameGateway.forceChangeUsername(id, newUsername);

        // Assert that the username was updated.
        assertEq(idRegistry.usernameOf(id), newUsername);
    }

    function testFuzz_forceChangeUsername_WhenIdRegistryPaused(
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
        vm.expectEmit();
        emit UsernameChanged(id, newUsername);
        vm.prank(USERNAME_GATEWAY_OWNER);
        usernameGateway.forceChangeUsername(id, newUsername);

        // Assert that the username was updated.
        assertEq(idRegistry.usernameOf(id), newUsername);
    }

    function testFuzz_forceChangeUsername_WhenUsernameGatewayPaused(
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

        // Pause UsernameGateway
        vm.prank(USERNAME_GATEWAY_OWNER);
        usernameGateway.pause();

        // Change the username.
        vm.expectEmit();
        emit UsernameChanged(id, newUsername);
        vm.prank(USERNAME_GATEWAY_OWNER);
        usernameGateway.forceChangeUsername(id, newUsername);

        // Assert that the username was updated.
        assertEq(idRegistry.usernameOf(id), newUsername);
    }

    function testFuzz_forceChangeUsername_RevertWhenCalledByNonOwner(
        address caller,
        address custody,
        uint8 initialUsernameLength_,
        uint8 newUsernameLength_
    ) public {
        // Bound inputs that need to be bound.
        vm.assume(caller != USERNAME_GATEWAY_OWNER);
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
        usernameGateway.forceChangeUsername(id, newUsername);
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
        vm.prank(USERNAME_GATEWAY_OWNER);
        usernameGateway.forceChangeUsername(id, newUsername);
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
        vm.prank(USERNAME_GATEWAY_OWNER);
        usernameGateway.forceChangeUsername(id, newUsername);
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
        vm.prank(USERNAME_GATEWAY_OWNER);
        usernameGateway.forceChangeUsername(id, newUsername);
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
        vm.prank(USERNAME_GATEWAY_OWNER);
        usernameGateway.forceChangeUsername(id, newUsername);
    }

    // =============================================================
    //                        checkUsername()
    // =============================================================

    function testFuzz_checkUsername(uint8 usernameLength_) public {
        // Bound inputs that need to be bound.
        uint256 usernameLength = _boundUsernameLength(usernameLength_);
        string memory username = _getRandomValidUniqueUsername(usernameLength);

        // Check the username.
        bool isValid = usernameGateway.checkUsername(username);
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
        usernameGateway.checkUsername(username);
    }

    function testFuzz_checkUsername_RevertWhenUsernameTooLong(uint8 usernameLength_) public {
        // Bound inputs that need to be bound.
        uint256 invalidUsernameLength = _boundUsernameLengthTooLong(usernameLength_);
        string memory username = _getRandomValidUniqueUsername(invalidUsernameLength);

        // Check the username.
        vm.expectRevert(UsernameTooLong.selector);
        usernameGateway.checkUsername(username);
    }

    function test_checkUsername_RevertWhenUsernameTooShort() public {
        // Currently, usernames of a single character are acceptable, so the only invalid length is 0.
        string memory username = "";

        // Check the username.
        vm.expectRevert(UsernameTooShort.selector);
        usernameGateway.checkUsername(username);
    }

    function test_checkUsername_RevertWhenUsernameIsEmpty() public {
        // Check the username.
        vm.expectRevert(UsernameTooShort.selector);
        usernameGateway.checkUsername("");
    }

    function testFuzz_checkUsername_RevertWhenUsernameContainsInvalidChar(bytes16 usernameBytes_) public {
        // Bound inputs that need to be bound.
        string memory username = string(abi.encodePacked(usernameBytes_));
        vm.assume(!_validateUsernameCharacters(username));

        // Check the username.
        vm.expectRevert(UsernameContainsInvalidChar.selector);
        usernameGateway.checkUsername(username);
    }

    // =============================================================
    //                        SIGNATURE HELPERS
    // =============================================================

    /// @dev Sign the EIP712 message for a transferUsername transaction.
    function _signTransferUsername(
        uint256 pk,
        address signer,
        uint256 fromId,
        uint256 toId,
        string memory newFromUsername,
        uint256 deadline
    ) internal view returns (bytes memory signature) {
        bytes32 digest = usernameGateway.hashTypedData(
            keccak256(
                abi.encode(
                    usernameGateway.TRANSFER_USERNAME_TYPEHASH(),
                    fromId,
                    toId,
                    keccak256(bytes(newFromUsername)),
                    usernameGateway.nonces(signer),
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
        bytes32 digest = usernameGateway.hashTypedData(
            keccak256(
                abi.encode(
                    usernameGateway.CHANGE_USERNAME_TYPEHASH(),
                    id,
                    keccak256(bytes(username)),
                    usernameGateway.nonces(signer),
                    deadline
                )
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, digest);
        signature = abi.encodePacked(r, s, v);
        assertEq(signature.length, 65);
    }
}
