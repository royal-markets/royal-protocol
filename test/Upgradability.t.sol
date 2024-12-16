// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ProvenanceTest} from "./ProvenanceTest.sol";
import {UpgradeMock} from "./Utils.sol";

contract UpgradabilityTest is ProvenanceTest {
    event Upgraded(address indexed implementation);

    function test_idGateway_upgradeToAndCall() public {
        address mock = address(new UpgradeMock());

        assertEq(idGateway.VERSION(), "2024-09-07");

        // Upgrade the contract
        vm.expectEmit();
        emit Upgraded(mock);
        vm.prank(ID_GATEWAY_OWNER);
        idGateway.upgradeToAndCall(address(mock), "");

        // Check the implementation
        assertEq(idGateway.VERSION(), "9999-99-99");
    }

    function testFuzz_idGateway_upgradeToAndCall_RevertWhenNotOwner(address caller) public {
        vm.assume(caller != ID_GATEWAY_OWNER);

        address mock = address(new UpgradeMock());

        assertEq(idGateway.VERSION(), "2024-09-07");

        // Upgrade the contract
        vm.expectRevert(Unauthorized.selector);
        vm.prank(caller);
        idGateway.upgradeToAndCall(address(mock), "");

        // Check the implementation did NOT change
        assertEq(idGateway.VERSION(), "2024-09-07");
    }

    function test_idRegistry_upgradeToAndCall() public {
        address mock = address(new UpgradeMock());

        assertEq(idRegistry.VERSION(), "2024-09-07");

        // Upgrade the contract
        vm.expectEmit();
        emit Upgraded(mock);
        vm.prank(ID_REGISTRY_OWNER);
        idRegistry.upgradeToAndCall(address(mock), "");

        // Check the implementation
        assertEq(idRegistry.VERSION(), "9999-99-99");
    }

    function testFuzz_idRegistry_upgradeToAndCall_RevertWhenNotOwner(address caller) public {
        vm.assume(caller != ID_REGISTRY_OWNER);

        address mock = address(new UpgradeMock());

        assertEq(idRegistry.VERSION(), "2024-09-07");

        // Upgrade the contract
        vm.expectRevert(Unauthorized.selector);
        vm.prank(caller);
        idRegistry.upgradeToAndCall(address(mock), "");

        // Check the implementation did NOT change
        assertEq(idRegistry.VERSION(), "2024-09-07");
    }

    function test_provenanceGateway_upgradeToAndCall() public {
        address mock = address(new UpgradeMock());

        assertEq(provenanceGateway.VERSION(), "2024-09-07");

        // Upgrade the contract
        vm.expectEmit();
        emit Upgraded(mock);
        vm.prank(PROVENANCE_GATEWAY_OWNER);
        provenanceGateway.upgradeToAndCall(address(mock), "");

        // Check the implementation
        assertEq(provenanceGateway.VERSION(), "9999-99-99");
    }

    function testFuzz_provenanceGateway_upgradeToAndCall_RevertWhenNotOwner(address caller) public {
        vm.assume(caller != PROVENANCE_GATEWAY_OWNER);

        address mock = address(new UpgradeMock());

        assertEq(provenanceGateway.VERSION(), "2024-09-07");

        // Upgrade the contract
        vm.expectRevert(Unauthorized.selector);
        vm.prank(caller);
        provenanceGateway.upgradeToAndCall(address(mock), "");

        // Check the implementation did NOT change
        assertEq(provenanceGateway.VERSION(), "2024-09-07");
    }

    function test_provenanceRegistry_upgradeToAndCall() public {
        address mock = address(new UpgradeMock());

        assertEq(provenanceRegistry.VERSION(), "2024-09-07");

        // Upgrade the contract
        vm.expectEmit();
        emit Upgraded(mock);
        vm.prank(PROVENANCE_REGISTRY_OWNER);
        provenanceRegistry.upgradeToAndCall(address(mock), "");

        // Check the implementation
        assertEq(provenanceRegistry.VERSION(), "9999-99-99");
    }

    function testFuzz_provenanceRegistry_upgradeToAndCall_RevertWhenNotOwner(address caller) public {
        vm.assume(caller != PROVENANCE_REGISTRY_OWNER);

        address mock = address(new UpgradeMock());

        assertEq(provenanceRegistry.VERSION(), "2024-09-07");

        // Upgrade the contract
        vm.expectRevert(Unauthorized.selector);
        vm.prank(caller);
        provenanceRegistry.upgradeToAndCall(address(mock), "");

        // Check the implementation did NOT change
        assertEq(provenanceRegistry.VERSION(), "2024-09-07");
    }
}
