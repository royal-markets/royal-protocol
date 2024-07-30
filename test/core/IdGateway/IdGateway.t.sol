// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ProvenanceTest} from "../ProvenanceTest.sol";

contract IdGatewayTest is ProvenanceTest {
    // =============================================================
    //                           EVENTS
    // =============================================================

    // NOTE: This event is actually emitted by IdRegistry (which IdGateway wraps).
    event Registered(
        uint256 id, address indexed custody, string username, address indexed operator, address indexed recovery
    );

    // =============================================================
    //                           ERRORS
    // =============================================================

    error CustodyAlreadyRegistered();
    error UsernameAlreadyRegistered();
    error UsernameTooLong();
    error UsernameTooShort();
    error UsernameContainsInvalidChar();
    error OperatorAlreadyRegistered();
    error OperatorCannotBeCustody();

    // =============================================================
    //                   Constants / Immutables
    // =============================================================

    function test_VERSION() public view {
        assertEq(idGateway.VERSION(), "2024-07-29");
    }

    function test_REGISTER_TYPEHASH() public view {
        assertEq(
            idGateway.REGISTER_TYPEHASH(),
            keccak256(
                "Register(address custody,string username,address operator,address recovery,uint256 nonce,uint256 deadline)"
            )
        );
    }

    function test_ID_REGISTRY() public view {
        assertEq(address(idGateway.ID_REGISTRY()), address(idRegistry));
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
    //                        constructor()
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

    function testFuzz_register(address custody, uint8 usernameLength_, address operator, address recovery) public {
        // Bound inputs that need to be bound.
        vm.assume(custody != address(0));
        uint256 usernameLength = _boundUsernameLength(usernameLength_);
        string memory username = _getRandomValidUniqueUsername(usernameLength);
        vm.assume(operator != custody);

        // Assert Preconditions
        uint256 expectedId = 1;
        _assertRegisterPreconditions(expectedId, custody, operator);

        // Call .register() and check the emitted event
        vm.expectEmit();
        emit Registered(expectedId, custody, username, operator, recovery);
        vm.prank(custody);
        idGateway.register(username, operator, recovery);

        // Assert Postconditions
        _assertRegisterPostconditions(expectedId, custody, username, operator, recovery);
    }

    function testFuzz_register_RevertWhenIdGatewayPaused(
        address custody,
        uint8 usernameLength_,
        address operator,
        address recovery
    ) public {
        // Pause the IdGateway
        vm.prank(ID_GATEWAY_OWNER);
        idGateway.pause();

        // Bound inputs that need to be bound.
        vm.assume(custody != address(0));
        vm.assume(operator != custody);
        uint256 usernameLength = _boundUsernameLength(usernameLength_);
        string memory username = _getRandomValidUniqueUsername(usernameLength);

        // Call .register() and check the revert error
        vm.expectRevert(EnforcedPause.selector);
        vm.prank(custody);
        idGateway.register(username, operator, recovery);
    }

    function testFuzz_register_RevertWhenIdRegistryPaused(
        address custody,
        uint8 usernameLength_,
        address operator,
        address recovery
    ) public {
        // Pause the IdRegistry
        vm.prank(ID_REGISTRY_OWNER);
        idRegistry.pause();

        // Bound inputs that need to be bound.
        vm.assume(custody != address(0));
        uint256 usernameLength = _boundUsernameLength(usernameLength_);
        string memory username = _getRandomValidUniqueUsername(usernameLength);
        vm.assume(operator != custody);

        // Call .register() and check the revert error
        vm.expectRevert(EnforcedPause.selector);
        vm.prank(custody);
        idGateway.register(username, operator, recovery);
    }

    function testFuzz_register_RevertWhenCustodyAlreadyRegistered(address custody) public {
        vm.assume(custody != address(0));

        vm.prank(custody);
        idGateway.register("username1", address(0), address(0));

        vm.expectRevert(CustodyAlreadyRegistered.selector);
        vm.prank(custody);
        idGateway.register("username2", address(0), address(0));
    }

    function testFuzz_register_RevertWhenCustodyAlreadyRegisteredAsOperator(address custody1, address custody2)
        public
    {
        vm.assume(custody1 != address(0));
        vm.assume(custody2 != address(0));
        vm.assume(custody1 != custody2);

        vm.prank(custody1);
        idGateway.register("username1", custody2, address(0));

        vm.expectRevert(CustodyAlreadyRegistered.selector);
        vm.prank(custody2);
        idGateway.register("username2", address(0), address(0));
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
        idGateway.register(username, address(0), address(0));

        vm.expectRevert(UsernameAlreadyRegistered.selector);
        vm.prank(custody2);
        idGateway.register(username, address(0), address(0));
    }

    function testFuzz_register_RevertWhenUsernameTooLong(address custody, uint8 usernameLength_) public {
        vm.assume(custody != address(0));

        uint256 invalidUsernameLength = _boundUsernameLengthTooLong(usernameLength_);
        string memory username = _getRandomValidUniqueUsername(invalidUsernameLength);

        vm.expectRevert(UsernameTooLong.selector);
        vm.prank(custody);
        idGateway.register(username, address(0), address(0));
    }

    function testFuzz_register_RevertWhenUsernameTooShort(address custody) public {
        vm.assume(custody != address(0));

        // Currently, usernames of a single character are acceptable, so the only invalid length is 0.
        string memory username = "";

        vm.expectRevert(UsernameTooShort.selector);
        vm.prank(custody);
        idGateway.register(username, address(0), address(0));
    }

    function testFuzz_register_RevertWhenUsernameContainsInvalidChar(address custody, bytes16 usernameBytes) public {
        vm.assume(custody != address(0));

        // Verify the username is invalid.
        string memory username = string(abi.encodePacked(usernameBytes));
        vm.assume(!_validateUsernameCharacters(username));

        vm.expectRevert(UsernameContainsInvalidChar.selector);
        vm.prank(custody);
        idGateway.register(username, address(0), address(0));
    }

    function testFuzz_register_RevertWhenOperatorAlreadyRegistered(address custody1, address custody2, address operator)
        public
    {
        vm.assume(custody1 != address(0));
        vm.assume(custody2 != address(0));
        vm.assume(custody1 != custody2);
        vm.assume(operator != address(0));
        vm.assume(custody1 != operator);
        vm.assume(custody2 != operator);

        vm.prank(custody1);
        idGateway.register("username1", operator, address(0));

        vm.expectRevert(OperatorAlreadyRegistered.selector);
        vm.prank(custody2);
        idGateway.register("username2", operator, address(0));
    }

    function testFuzz_register_RevertWhenOperatorIsCustody(address custody) public {
        vm.assume(custody != address(0));

        vm.expectRevert(OperatorCannotBeCustody.selector);
        vm.prank(custody);
        idGateway.register({username: "username", operator: custody, recovery: address(0)});
    }

    // =============================================================
    //                        registerFor()
    // =============================================================

    function testFuzz_registerFor(
        address caller,
        uint256 custodyPk_,
        uint8 usernameLength_,
        address operator,
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
        _assertRegisterPreconditions(expectedId, custody, operator);

        // Register the ID with an EIP712 signature
        bytes memory sig = _signRegister(custodyPk, custody, username, operator, recovery, deadline);

        // Call .registerFor() and check the emitted event
        vm.expectEmit();
        emit Registered(expectedId, custody, username, operator, recovery);
        vm.prank(caller);
        idGateway.registerFor(custody, username, operator, recovery, deadline, sig);

        // Assert Postconditions
        assertEq(idGateway.nonces(custody), 1);
        _assertRegisterPostconditions(expectedId, custody, username, operator, recovery);
    }

    function testFuzz_registerFor_RevertWhenIdGatewayPaused(
        address caller,
        uint256 custodyPk_,
        uint8 usernameLength_,
        address operator,
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
        bytes memory sig = _signRegister(custodyPk, custody, username, operator, recovery, deadline);

        // Call .registerFor() and check the revert error
        vm.expectRevert(EnforcedPause.selector);
        vm.prank(caller);
        idGateway.registerFor(custody, username, operator, recovery, deadline, sig);
    }

    function testFuzz_registerFor_RevertWhenIdRegistryPaused(
        address caller,
        uint256 custodyPk_,
        uint8 usernameLength_,
        address operator,
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
        bytes memory sig = _signRegister(custodyPk, custody, username, operator, recovery, deadline);

        // Call .registerFor() and check the revert error
        vm.expectRevert(EnforcedPause.selector);
        vm.prank(caller);
        idGateway.registerFor(custody, username, operator, recovery, deadline, sig);
    }

    function testFuzz_registerFor_RevertWhenCustodyAlreadyRegistered(
        address caller,
        uint256 custodyPk_,
        uint40 deadline_
    ) public {
        // Bound inputs that need to be bound.
        uint256 custodyPk = _boundPk(custodyPk_);
        address custody = vm.addr(custodyPk);
        address operator = address(0);
        address recovery = address(0);
        uint256 deadline = _boundDeadline(deadline_);

        // Register the ID with an EIP712 signature
        bytes memory sig1 = _signRegister(custodyPk, custody, "username1", operator, recovery, deadline);
        vm.prank(caller);
        idGateway.registerFor(custody, "username1", operator, recovery, deadline, sig1);

        // Expect the revert error
        bytes memory sig2 = _signRegister(custodyPk, custody, "username2", operator, recovery, deadline);
        vm.expectRevert(CustodyAlreadyRegistered.selector);
        vm.prank(caller);
        idGateway.registerFor(custody, "username2", operator, recovery, deadline, sig2);
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

        address operator = address(0);
        address recovery = address(0);
        uint256 deadline = _boundDeadline(deadline_);

        // Register the ID with an EIP712 signature
        bytes memory sig1 = _signRegister(custodyPk1, custody1, username, operator, recovery, deadline);
        vm.prank(caller);
        idGateway.registerFor(custody1, username, operator, recovery, deadline, sig1);

        // Expect the revert error
        bytes memory sig2 = _signRegister(custodyPk2, custody2, username, operator, recovery, deadline);
        vm.expectRevert(UsernameAlreadyRegistered.selector);
        vm.prank(caller);
        idGateway.registerFor(custody2, username, operator, recovery, deadline, sig2);
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
        address operator = address(0);
        address recovery = address(0);
        uint256 deadline = _boundDeadline(deadline_);

        uint256 invalidUsernameLength = _boundUsernameLengthTooLong(usernameLength_);
        string memory username = _getRandomValidUniqueUsername(invalidUsernameLength);

        // Expect the revert error
        bytes memory sig = _signRegister(custodyPk, custody, username, operator, recovery, deadline);
        vm.expectRevert(UsernameTooLong.selector);
        vm.prank(caller);
        idGateway.registerFor(custody, username, operator, recovery, deadline, sig);
    }

    function testFuzz_registerFor_RevertWhenUsernameTooShort(address caller, uint256 custodyPk_, uint40 deadline_)
        public
    {
        // Bound inputs that need to be bound.
        uint256 custodyPk = _boundPk(custodyPk_);
        address custody = vm.addr(custodyPk);
        address operator = address(0);
        address recovery = address(0);
        uint256 deadline = _boundDeadline(deadline_);

        // Currently, usernames of a single character are acceptable, so the only invalid length is 0.
        string memory username = "";

        // Expect the revert error
        bytes memory sig = _signRegister(custodyPk, custody, username, operator, recovery, deadline);
        vm.expectRevert(UsernameTooShort.selector);
        vm.prank(caller);
        idGateway.registerFor(custody, username, operator, recovery, deadline, sig);
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

        address operator = address(0);
        address recovery = address(0);
        uint256 deadline = _boundDeadline(deadline_);

        // Register the ID with an EIP712 signature
        bytes memory sig = _signRegister(custodyPk, custody, username, operator, recovery, deadline);
        vm.expectRevert(UsernameContainsInvalidChar.selector);
        vm.prank(caller);
        idGateway.registerFor(custody, username, operator, recovery, deadline, sig);
    }

    function testFuzz_registerFor_RevertWhenOperatorAlreadyRegistered(
        address caller,
        uint256 custodyPk1_,
        uint256 custodyPk2_,
        address operator,
        uint40 deadline_
    ) public {
        // Bound inputs that need to be bound.
        uint256 custodyPk1 = _boundPk(custodyPk1_);
        uint256 custodyPk2 = _boundPk(custodyPk2_);
        vm.assume(custodyPk1 != custodyPk2);
        address custody1 = vm.addr(custodyPk1);
        address custody2 = vm.addr(custodyPk2);

        vm.assume(operator != address(0));
        address recovery = address(0);
        uint256 deadline = _boundDeadline(deadline_);

        // Register the ID with an EIP712 signature
        bytes memory sig1 = _signRegister(custodyPk1, custody1, "username1", operator, recovery, deadline);
        vm.prank(caller);
        idGateway.registerFor(custody1, "username1", operator, recovery, deadline, sig1);

        // Expect the revert error
        bytes memory sig2 = _signRegister(custodyPk2, custody2, "username2", operator, recovery, deadline);
        vm.expectRevert(OperatorAlreadyRegistered.selector);
        vm.prank(caller);
        idGateway.registerFor(custody2, "username2", operator, recovery, deadline, sig2);
    }

    function testFuzz_registerFor_RevertWhenOperatorIsCustody(address caller, uint256 custodyPk_, uint40 deadline_)
        public
    {
        // Bound inputs that need to be bound.
        uint256 custodyPk = _boundPk(custodyPk_);
        address custody = vm.addr(custodyPk);
        address operator = custody;
        address recovery = address(0);
        uint256 deadline = _boundDeadline(deadline_);

        bytes memory sig = _signRegister(custodyPk, custody, "username", operator, recovery, deadline);
        vm.expectRevert(OperatorCannotBeCustody.selector);
        vm.prank(caller);
        idGateway.registerFor(custody, "username", operator, recovery, deadline, sig);
    }

    // =============================================================
    //               registerFor() - Signature Reverts
    // =============================================================

    function testFuzz_registerFor_RevertWhenDeadlineExpired(
        address caller,
        uint256 custodyPk_,
        uint8 usernameLength_,
        address operator,
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
        bytes memory sig = _signRegister(custodyPk, custody, username, operator, recovery, deadline);

        // Fast forward past the deadline
        vm.warp(deadline + 1);

        // Expect the revert error
        vm.expectRevert(SignatureExpired.selector);
        vm.prank(caller);
        idGateway.registerFor(custody, username, operator, recovery, deadline, sig);
    }

    function testFuzz_registerFor_RevertWhenNonceInvalid(
        address caller,
        uint256 custodyPk_,
        uint8 usernameLength_,
        address operator,
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
        bytes memory sig = _signRegister(custodyPk, custody, username, operator, recovery, deadline);

        // Have user invalidate their nonce
        vm.prank(custody);
        idGateway.useNonce();

        // Expect the revert error
        vm.expectRevert(InvalidSignature.selector);
        vm.prank(caller);
        idGateway.registerFor(custody, username, operator, recovery, deadline, sig);
    }

    function testFuzz_registerFor_RevertWhenSignerInvalid(
        address caller,
        uint256 signerPk_,
        address custody,
        uint8 usernameLength_,
        address operator,
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
        bytes memory sig = _signRegister(signerPk, custody, username, operator, recovery, deadline);

        // Expect the revert error since signer != custody
        vm.expectRevert(InvalidSignature.selector);
        vm.prank(caller);
        idGateway.registerFor(custody, username, operator, recovery, deadline, sig);
    }

    // =============================================================
    //                        ASSERTION HELPERS
    // =============================================================

    /// @dev Assert that all the state for all provided parameters are the defaults/zero.
    function _assertRegisterPreconditions(uint256 id, address custody, address operator) internal view {
        assertEq(idRegistry.idCounter(), 0);

        assertEq(idRegistry.idOf(custody), 0);
        assertEq(idRegistry.custodyOf(id), address(0));

        assertEq(idRegistry.usernameOf(id), "");

        assertEq(idRegistry.idOf(operator), 0);
        assertEq(idRegistry.operatorOf(id), address(0));

        assertEq(idRegistry.recoveryOf(id), address(0));
    }

    /// @dev Assert that all the state for all provided parameters is set as expected.
    function _assertRegisterPostconditions(
        uint256 id,
        address custody,
        string memory username,
        address operator,
        address recovery
    ) internal view {
        assertEq(idRegistry.idCounter(), id);

        assertEq(idRegistry.idOf(custody), id);
        assertEq(idRegistry.custodyOf(id), custody);

        assertEq(idRegistry.usernameOf(id), username);
        assertEq(idRegistry.getIdByUsername(username), id);

        if (operator != address(0)) {
            assertEq(idRegistry.idOf(operator), id);
            assertEq(idRegistry.operatorOf(id), operator);
        } else {
            assertEq(idRegistry.idOf(operator), 0);
            assertEq(idRegistry.operatorOf(id), address(0));
        }

        assertEq(idRegistry.recoveryOf(id), recovery);
    }

    // =============================================================
    //                        SIGNATURE HELPERS
    // =============================================================

    /// @dev Sign the EIP712 message for a registerFor transaction.
    function _signRegister(
        uint256 pk,
        address custody,
        string memory username,
        address operator,
        address recovery,
        uint256 deadline
    ) internal view returns (bytes memory signature) {
        bytes32 digest = idGateway.hashTypedData(
            keccak256(
                abi.encode(
                    idGateway.REGISTER_TYPEHASH(),
                    custody,
                    keccak256(bytes(username)),
                    operator,
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
}
