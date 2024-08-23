// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ProvenanceTest} from "../core/ProvenanceTest.sol";
import {RecoveryProxy} from "../../src/extra/RecoveryProxy.sol";
import {IIdRegistry} from "../../src/core/interfaces/IIdRegistry.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {SignatureCheckerLib} from "solady/utils/SignatureCheckerLib.sol";

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

        address custody = vm.addr(_fromPrivateKey);
        idRegistry.register(custody, "username", proxy);
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
                keccak256(abi.encode(idRegistry.RECOVER_TYPEHASH(), id, to, idRegistry.nonces(to), deadline))
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

    function test_isValidERC6492SignatureNow() public {
        // Test setup
        uint256 id = 1;
        address to = 0xc99b000C0821DCCd93baC44D02f240594d9B27d6;
        uint256 deadline = 4724445746;

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
                keccak256(abi.encode(idRegistry.RECOVER_TYPEHASH(), id, to, idRegistry.nonces(to), deadline))
            )
        );

        // ERC-6492 signature (predeployed smart contract wallet)
        bytes memory signature =
            hex"000000000000000000000000ca11bde05977b3631167028862be2a173976ca110000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000028000000000000000000000000000000000000000000000000000000000000001e482ad56cb0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000200000000000000000000000000ba5ed0c6aa8c49038f819e587e2633c4a9f428a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000e43ffba36f0000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000004068642b9df16985b30ede0da733b21eb420e2793ba4658eba53a4a2de0517c7e58bb9c6da3a654e42526039c2c7d219e57a34923248f2b390dbee770c0c1bdbd5000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002800000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000c0000000000000000000000000000000000000000000000000000000000000012000000000000000000000000000000000000000000000000000000000000000170000000000000000000000000000000000000000000000000000000000000001c1c581089567cc878f1a9d389f4d0ea969074e2fd378f4c37ef1551d04fbe1e2157c44a3b1c0a37ac397c43e1ec0cfc0ac1a4956f6032aa2f9b235d5460a94040000000000000000000000000000000000000000000000000000000000000025f198086b2db17256731bc456673b96bcef23f51d1fbacdd7c4379ef65465572f1d00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000008a7b2274797065223a22776562617574686e2e676574222c226368616c6c656e6765223a22494c4c6778577a37326e6c5375653679683064375466464c5733446874726e7170746c5a5838332d6b6145222c226f726967696e223a2268747470733a2f2f6b6579732e636f696e626173652e636f6d222c2263726f73734f726967696e223a66616c73657d000000000000000000000000000000000000000000006492649264926492649264926492649264926492649264926492649264926492";

        // Mock the behavior of SignatureCheckerLib

        bool isValid = SignatureCheckerLib.isValidERC6492SignatureNow(to, digest, signature);
        assertEq(isValid, true);
    }
}
