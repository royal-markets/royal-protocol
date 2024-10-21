// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ProvenanceTest} from "../core/ProvenanceTest.sol";
import {IRoleData} from "../../src/extra/utils/IRoleData.sol";

import {RegistrarFactory} from "../../src/extra/RegistrarFactory.sol";
import {ProvenanceRegistrar} from "../../src/extra/ProvenanceRegistrar.sol";
import {ProvenanceToken} from "../../src/extra/ProvenanceToken.sol";

import {LibClone} from "solady/utils/LibClone.sol";

interface IHasRoles {
    function hasAllRoles(address account, uint256 roles) external view returns (bool);
}

contract RegistrarFactoryTest is ProvenanceTest, IRoleData {
    // =============================================================
    //                          CONSTANTS
    // =============================================================

    /// @notice The bitmask for the ADMIN role.
    uint256 public constant ADMIN = 1 << 0;

    /// @notice The bitmask for the REGISTER_CALLER role (ProvenanceRegistrar).
    uint256 public constant REGISTER_CALLER = 1 << 1;

    /// @notice The bitmask for the AIRDROPPER role (ProvenanceToken).
    uint256 public constant AIRDROPPER = 1 << 2;

    /// @notice The bitmask for the DEPLOY_CALLER role (RegistrarFactory).
    uint256 public constant DEPLOY_CALLER = 1 << 3;

    // =============================================================
    //                         IMMUTABLES
    // =============================================================

    address public immutable FACTORY_OWNER;
    address public immutable FACTORY_CALLER;

    // =============================================================
    //                         STORAGE
    // =============================================================

    RegistrarFactory public registrarFactory;
    ProvenanceRegistrar public provenanceRegistrar;
    ProvenanceToken public provenanceToken;

    constructor() {
        FACTORY_OWNER = vm.addr(0x42);
        FACTORY_CALLER = vm.addr(0x99);
    }

    function setUp() public override {
        super.setUp();

        address provenanceTokenImplementation = address(new ProvenanceToken());
        address provenanceRegistrarImplementation = address(new ProvenanceRegistrar());
        address registrarFactoryImplementation = address(new RegistrarFactory());

        registrarFactory = RegistrarFactory(LibClone.deployERC1967(registrarFactoryImplementation));
        registrarFactory.initialize(FACTORY_OWNER, provenanceRegistrarImplementation, provenanceTokenImplementation);

        vm.prank(FACTORY_OWNER);
        registrarFactory.addDeployCaller(FACTORY_CALLER);
    }

    // TODO: Emitted events in all the tests?
    function testFuzz_deployRegistrarAndTokenContracts(
        address initialOwner,
        uint8 usernameLength_,
        address recovery,
        address account1,
        uint256 roles1,
        address account2,
        uint256 roles2,
        address account3,
        uint256 roles3
    ) public {
        vm.assume(initialOwner != address(0));
        vm.assume(account1 != account2 && account1 != account3 && account2 != account3);

        uint256 usernameLength = _boundUsernameLength(usernameLength_);
        string memory username = _getRandomValidUniqueUsername(usernameLength);

        string memory name = "name";
        string memory symbol = "symbol";
        string memory metadataUrl = "metadataUrl";
        string memory contractURI = "contractURI";

        RoleData[] memory roles = new RoleData[](3);
        roles[0] = RoleData({holder: account1, roles: roles1});
        roles[1] = RoleData({holder: account2, roles: roles2});
        roles[2] = RoleData({holder: account3, roles: roles3});

        vm.prank(FACTORY_CALLER);
        (uint256 protocolId, address payable registrar, address token) = registrarFactory
            .deployRegistrarAndTokenContracts(
            initialOwner, username, recovery, name, symbol, metadataUrl, contractURI, roles
        );

        assertEq(protocolId, 1);

        provenanceRegistrar = ProvenanceRegistrar(registrar);
        provenanceToken = ProvenanceToken(token);

        assertEq(provenanceToken.owner(), initialOwner);
        assertEq(provenanceToken.name(), name);
        assertEq(provenanceToken.symbol(), symbol);
        assertEq(provenanceToken.metadataUrl(), metadataUrl);
        assertEq(provenanceToken.contractURI(), contractURI);
        _assertRoles(roles, token);

        assertEq(idRegistry.getIdByUsername(username), protocolId);
        assertEq(idRegistry.getUserById(protocolId).recovery, recovery);

        assertEq(provenanceRegistrar.owner(), initialOwner);
        assertEq(provenanceRegistrar.nftContract(), token);
        assertEq(address(provenanceRegistrar.idRegistry()), address(idRegistry));
        assertEq(address(provenanceRegistrar.idGateway()), address(idGateway));
        assertEq(address(provenanceRegistrar.provenanceGateway()), address(provenanceGateway));
        _assertRoles(roles, registrar);
    }

    function _assertRoles(RoleData[] memory roles, address c) internal view {
        uint256 length = roles.length;
        IHasRoles roleableContract = IHasRoles(c);

        unchecked {
            for (uint256 i = 0; i < length; i++) {
                RoleData memory role = roles[i];
                assertEq(roleableContract.hasAllRoles(role.holder, role.roles), true);
            }
        }
    }

    function testFuzz_deployedRegistrarCanRegisterProvenance(
        address owner,
        address registerCaller,
        address custody,
        bytes32 contentHash
    ) public {
        vm.assume(owner != address(0));
        vm.assume(custody != address(0) && custody != address(1));
        address recovery = address(0);

        RoleData[] memory roles = new RoleData[](1);
        roles[0] = RoleData({holder: registerCaller, roles: REGISTER_CALLER});

        // Deploy a new ProvenanceRegistrar and ProvenanceToken
        vm.prank(FACTORY_CALLER);
        (uint256 registrarId, address payable registrar, address token) = registrarFactory
            .deployRegistrarAndTokenContracts(
            owner, "registrar", recovery, "name", "symbol", "metadataUrl", "contractURI", roles
        );

        provenanceRegistrar = ProvenanceRegistrar(registrar);
        provenanceToken = ProvenanceToken(token);

        // Register custody account and set up delegation to registrar contract
        uint256 originatorId = _register(custody, "user");
        vm.prank(custody);
        delegateRegistry.delegateContract(registrarId, address(provenanceGateway), "registerProvenance", true);

        // Attempt to register provenance
        vm.prank(registerCaller);
        provenanceRegistrar.registerProvenanceAndMintNft(originatorId, contentHash);

        // Assert that the provenance was registered
        assertEq(provenanceRegistry.provenanceClaim(1).originatorId, originatorId);
        assertEq(provenanceRegistry.provenanceClaim(1).registrarId, registrarId);
        assertEq(provenanceRegistry.provenanceClaim(1).contentHash, contentHash);
    }
}
