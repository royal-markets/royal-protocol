// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ProvenanceTest} from "../ProvenanceTest.sol";

import {IdRegistry} from "../../../src/core/IdRegistry.sol";

import {LibClone} from "solady/utils/LibClone.sol";

contract IdRegistryTest is ProvenanceTest {
    // =============================================================
    //                           EVENTS
    // =============================================================

    event IdGatewaySet(address oldIdGateway, address newIdGateway);
    event DelegateRegistrySet(address oldDelegateRegistry, address newDelegateRegistry);

    // =============================================================
    //                          ERRORS
    // =============================================================

    error OnlyIdGateway();

    error CustodyAlreadyRegistered();

    error OnlyCustody();
    error OnlyRecovery();

    error HasNoId();

    // =============================================================
    //                    Constants / Immutables
    // =============================================================

    function test_name() public view {
        assertEq(idRegistry.name(), "RoyalProtocol ID");
    }

    function test_VERSION() public view {
        assertEq(idRegistry.VERSION(), "2024-09-07");
    }

    function test_gracePeriod() public view {
        assertEq(idRegistry.gracePeriod(), 24 hours);
    }

    // TODO: Where are the mappings tested? In the IdGateway tests?

    // =============================================================
    //                        constructor()
    // =============================================================

    function test_PausedWhenInitialized() public {
        address idRegistryImplementation = address(new IdRegistry());
        idRegistry = IdRegistry(LibClone.deployERC1967(idRegistryImplementation));
        idRegistry.initialize(ID_REGISTRY_MIGRATOR, ID_REGISTRY_OWNER);
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

    // TODO: Tested by IdGateway?
    // =============================================================
    //                        transfer()
    // =============================================================

    // TODO: Tested by IdGateway?
    // =============================================================
    //                        transferFor()
    // =============================================================

    // TODO: Tested by IdGateway?
    // =============================================================
    //              transferAndClearRecovery()
    // =============================================================

    // TODO:
    // =============================================================
    //              transferAndClearRecoveryFor()
    // =============================================================

    // TODO: Tested sufficiently by IdGateway?
    // =============================================================
    //                      transferUsername()
    // =============================================================

    function testFuzz_transferUsername_RevertWhenCalledByNonIdGateway(
        address caller,
        address from,
        address to,
        uint8 initialFromUsernameLength_,
        uint8 newFromUsernameLength_,
        uint8 initialToUsernameLength_
    ) public {
        // Bound inputs that need to be bound.
        vm.assume(caller != address(idGateway));
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

        vm.expectRevert(OnlyIdGateway.selector);
        vm.prank(caller);
        idRegistry.transferUsername(fromId, toId, newFromUsername);
    }

    // TODO: Tested sufficiently by IdGateway?
    // =============================================================
    //                      changeUsername()
    // =============================================================

    function testFuzz_changeUsername_RevertWhenCalledByNonIdGateway(
        address caller,
        address custody,
        uint8 initialUsernameLength_,
        uint8 newUsernameLength_
    ) public {
        // Bound inputs that need to be bound.
        vm.assume(caller != address(idGateway));
        vm.assume(custody != address(0));

        uint256 initialUsernameLength = _boundUsernameLength(initialUsernameLength_);
        string memory initialUsername = _getRandomValidUniqueUsername(initialUsernameLength);
        uint256 newUsernameLength = _boundUsernameLength(newUsernameLength_);
        string memory newUsername = _getRandomValidUniqueUsername(newUsernameLength);

        // Register the IDs that we're going to transfer usernames between
        uint256 id = _register(custody, initialUsername);

        vm.expectRevert(OnlyIdGateway.selector);
        vm.prank(caller);
        idRegistry.changeUsername(id, newUsername);
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

    // TODO: Way more recover tests, not just the golden path.
    // TODO:
    // =============================================================
    //                      recoverFor()
    // =============================================================

    // =============================================================
    //                      Permissioned Actions
    // =============================================================
    // TODO: setDelegateRegistry()

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
}
