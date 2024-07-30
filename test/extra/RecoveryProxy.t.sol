// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ProvenanceTest} from "../core/ProvenanceTest.sol";
import {RecoveryProxy} from "../../src/extra/RecoveryProxy.sol";
import {IIdRegistry} from "../../src/core/interfaces/IIdRegistry.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract RecoveryProxyTest is ProvenanceTest {
    RecoveryProxy public recoveryProxy;
    address public proxy;
    address public immutable RECOVERY_ENTRYPOINT_OWNER;

    uint256 internal _fromPrivateKey;
    uint256 internal _toPrivateKey;
    uint256 internal _recoveryProxyOwnerPrivateKey;

    event Recovered(uint256 indexed id, address indexed to);

    function setUp() public override {
        super.setUp();

        _fromPrivateKey = 0xA11CE;
        _toPrivateKey = 0xB0B;
        _recoveryProxyOwnerPrivateKey = 0x0A1CE;

        recoveryProxy = new RecoveryProxy();
        bytes memory data = abi.encodeWithSelector(
            RecoveryProxy.initialize.selector, idRegistry, vm.addr(_recoveryProxyOwnerPrivateKey)
        );

        proxy = address(new ERC1967Proxy(address(recoveryProxy), data));
        recoveryProxy = RecoveryProxy(proxy);

        vm.prank(vm.addr(_recoveryProxyOwnerPrivateKey));
        recoveryProxy.addRecoverCaller(proxy);

        vm.startPrank(address(idGateway));
        idRegistry.register(vm.addr(_fromPrivateKey), "username", address(0x12), proxy);
        vm.stopPrank();
    }

    function test_recover() public {
        uint256 id = 1;
        IIdRegistry.User memory originalUser = idRegistry.getUserById(id);
        address proxyAddress = address(proxy);
        assertEq(originalUser.recovery, proxyAddress);
        address to = vm.addr(_toPrivateKey);
        assertNotEq(to, originalUser.custody);
        uint256 deadline = block.timestamp + 1 days;

        bytes32 domainSeparator = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes("RoyalProtocol_IdRegistry")),
                keccak256(bytes("1")),
                block.chainid,
                address(idRegistry)
            )
        );

        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator,
                keccak256(abi.encode(idRegistry.TRANSFER_TYPEHASH(), id, to, idRegistry.nonces(to), deadline))
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_toPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.prank(proxyAddress);
        vm.expectEmit();
        emit Recovered(id, to);
        recoveryProxy.recover(id, to, deadline, signature);

        IIdRegistry.User memory updatedUser = idRegistry.getUserById(id);
        assertEq(updatedUser.custody, to);
    }
}
