// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {LibClone} from "solady/utils/LibClone.sol";

import {IRoleData} from "./utils/IRoleData.sol";
import {RegistrarRoles} from "./utils/RegistrarRoles.sol";
import {Initializable} from "solady/utils/Initializable.sol";
import {UUPSUpgradeable} from "solady/utils/UUPSUpgradeable.sol";

import {ProvenanceToken} from "./ProvenanceToken.sol";

interface IProvenanceRegistrar is IRoleData {
    function initialize(
        string calldata username,
        address recovery,
        address initialOwner_,
        address nftContract_,
        RoleData[] calldata roles
    ) external payable returns (uint256 accountId);
}

/* solhint-disable comprehensive-interface */
contract RegistrarFactory is RegistrarRoles, Initializable, UUPSUpgradeable {
    // =============================================================
    //                         EVENTS
    // =============================================================

    /// @dev Emitted when a new ProvenanceRegistrar is deployed.
    event RegistrarDeployed(uint256 accountId, address provenanceRegistrar, address provenanceToken);

    /// @dev Emitted when the ProvenanceRegistrar implementation is updated.
    event SetProvenanceRegistrarImplementation(address oldImplementation, address newImplementation);

    // =============================================================
    //                         STORAGE
    // =============================================================

    /// @notice The address of the ProvenanceRegistrar implementation contract.
    address public provenanceRegistrarImplementation;

    // =============================================================
    //                          CONSTRUCTOR
    // =============================================================

    constructor() {
        _disableInitializers();
    }

    function initialize(address initialOwner_, address provenanceRegistrarImplementation_) external {
        _initializeOwner(initialOwner_);

        emit SetProvenanceRegistrarImplementation(address(0), provenanceRegistrarImplementation_);

        provenanceRegistrarImplementation = provenanceRegistrarImplementation_;
    }

    // =============================================================
    //                      CREATION/CLONING
    // =============================================================

    function deployRegistrarAndTokenContracts(
        address initialOwner_,
        string calldata username,
        address recovery,
        string calldata name_,
        string calldata symbol_,
        string calldata metadataUrl_,
        string calldata contractURI_,
        RoleData[] calldata roles
    )
        external
        payable
        whenNotPaused
        onlyRolesOrOwner(DEPLOY_CALLER)
        returns (uint256 id, address payable provenanceRegistrar, address provenanceToken)
    {
        if (initialOwner_ == address(0)) revert AddressZero();

        // Deploy the ProvenanceToken
        provenanceToken = address(
            new ProvenanceToken({
                initialOwner_: address(this),
                name_: name_,
                symbol_: symbol_,
                metadataUrl_: metadataUrl_,
                contractURI_: contractURI_,
                roles: roles
            })
        );

        // Deploy the ProvenanceRegistrar
        provenanceRegistrar = payable(LibClone.deployERC1967(provenanceRegistrarImplementation));

        // Emit the RegistrarDeployed event. (Emit early to avoid slither yelling about reentry nonsense).
        emit RegistrarDeployed(id, provenanceRegistrar, provenanceToken);

        // Initialize the ProvenanceRegistrar
        id = IProvenanceRegistrar(provenanceRegistrar).initialize{value: msg.value}({
            username: username,
            recovery: recovery,
            initialOwner_: initialOwner_,
            nftContract_: provenanceToken,
            roles: roles
        });

        // Set up the Registrar contract as an AIRDROPPER on the NFT contract,
        // then transfer ownership of the NFT contract to the initial owner.
        ProvenanceToken(provenanceToken).addAirdropper(provenanceRegistrar);
        ProvenanceToken(provenanceToken).transferOwnership(initialOwner_);

        // Return the ID, registrar, and NFT contract address
        return (id, provenanceRegistrar, provenanceToken);
    }

    // =============================================================
    //                          ADMIN FNs
    // =============================================================

    function setProvenanceRegistrarImplementation(address newImplementation) external onlyRolesOrOwner(ADMIN) {
        emit SetProvenanceRegistrarImplementation(provenanceRegistrarImplementation, newImplementation);

        provenanceRegistrarImplementation = newImplementation;
    }

    // =============================================================
    //                       ROLE HELPERS
    // =============================================================

    /// @notice Check if an address has the DEPLOY_CALLER role.
    function isDeployCaller(address account) external view returns (bool) {
        return hasAnyRole(account, DEPLOY_CALLER);
    }

    /// @notice Add the DEPLOY_CALLER role to an address.
    function addDeployCaller(address account) external onlyRolesOrOwner(ADMIN) {
        _grantRoles(account, DEPLOY_CALLER);
    }

    /// @notice Remove the DEPLOY_CALLER role from an address.
    function removeDeployCaller(address account) external onlyRolesOrOwner(ADMIN) {
        _removeRoles(account, DEPLOY_CALLER);
    }

    // =============================================================
    //                          UUPS
    // =============================================================

    // solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address newImplementation) internal override onlyRolesOrOwner(ADMIN) {}
}
/* solhint-enable comprehensive-interface */
