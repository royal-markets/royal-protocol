// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.0;

import {IDelegateRegistry as IDelegateRegistry} from "./IDelegateRegistry.sol";
import {RegistryHashes as Hashes} from "./libraries/RegistryHashes.sol";
import {RegistryStorage as Storage} from "./libraries/RegistryStorage.sol";
import {RegistryOps as Ops} from "./libraries/RegistryOps.sol";

import {Withdrawable} from "../abstract/Withdrawable.sol";
import {Signatures} from "../abstract/Signatures.sol";
import {EIP712} from "../abstract/EIP712.sol";
import {Nonces} from "../abstract/Nonces.sol";
import {Initializable} from "solady/utils/Initializable.sol";
import {UUPSUpgradeable} from "solady/utils/UUPSUpgradeable.sol";

/**
 * @title DelegateRegistry
 * @notice A standalone immutable registry storing delegated permissions from one account ID to another
 *
 * @custom:note Adapted from delegate.xyz's v2 DelegateRegistry.
 */
interface IIdRegistry {
    function custodyOf(uint256 id) external view returns (address account);
    function idOf(address account) external view returns (uint256 id);
}

/* solhint-disable func-named-parameters, comprehensive-interface */

contract DelegateRegistry is
    IDelegateRegistry,
    Withdrawable,
    Signatures,
    EIP712,
    Nonces,
    Initializable,
    UUPSUpgradeable
{
    /// @notice The RoyalProtocol IdRegistry contract
    IIdRegistry public idRegistry;

    /// @notice The RoyalProtocol IdGateway contract
    address public idGateway;

    /* solhint-disable gas-small-strings */

    /// @notice EIP712 typehash for the delegation of all rights
    bytes32 public constant DELEGATE_ALL_TYPEHASH =
        keccak256("DelegateAll(uint256 fromId,uint256 toId,bytes32 rights,bool enable,uint256 nonce,uint256 deadline)");

    /// @notice EIP712 typehash for the delegation of contract rights
    bytes32 public constant DELEGATE_CONTRACT_TYPEHASH = keccak256(
        "DelegateContract(uint256 fromId,uint256 toId,address contract_,bytes32 rights,bool enable,uint256 nonce,uint256 deadline)"
    );

    /// @notice EIP712 typehash for the delegation of ERC721 rights
    bytes32 public constant DELEGATE_ERC721_TYPEHASH = keccak256(
        "DelegateERC721(uint256 fromId,uint256 toId,address contract_,uint256 tokenId,bytes32 rights,bool enable,uint256 nonce,uint256 deadline)"
    );

    /// @notice EIP712 typehash for the delegation of ERC20 rights
    bytes32 public constant DELEGATE_ERC20 = keccak256(
        "DelegateERC20(uint256 fromId,uint256 toId,address contract_,bytes32 rights,uint256 amount,bool enable,uint256 nonce,uint256 deadline)"
    );

    /// @notice EIP712 typehash for the delegation of ERC1155 rights
    bytes32 public constant DELEGATE_ERC1155 = keccak256(
        "DelegateERC1155(uint256 fromId,uint256 toId,address contract_,uint256 tokenId,bytes32 rights,uint256 amount,bool enable,uint256 nonce,uint256 deadline)"
    );

    /* solhint-enable gas-small-strings */

    /// @dev Vault delegation enumeration outbox, for pushing new hashes only
    mapping(uint256 fromId => bytes32[] delegationHashes) internal _outgoingDelegationHashes;

    /// @dev Delegate enumeration inbox, for pushing new hashes only
    mapping(uint256 toId => bytes32[] delegationHashes) internal _incomingDelegationHashes;

    modifier onlyIdGateway() {
        if (msg.sender != address(idGateway)) revert Unauthorized();
        _;
    }

    /**
     * ----------- EIP712 -----------
     */

    /// @dev Configure the EIP712 name and version for the domain separator.
    function _domainNameAndVersion() internal pure override returns (string memory name, string memory version) {
        name = "RoyalProtocol_DelegateRegistry";
        version = "1";
    }

    /**
     * --------- INITIALIZE ---------
     */
    constructor() {
        _disableInitializers();
    }

    /// @inheritdoc IDelegateRegistry
    function initialize(address idRegistry_, address initialOwner_) external override initializer {
        _initializeOwner(initialOwner_);

        idRegistry = IIdRegistry(idRegistry_);
        emit IdRegistrySet(address(0), idRegistry_);
    }

    /**
     * ----------- WRITE -----------
     */

    /// @inheritdoc IDelegateRegistry
    function multicall(bytes[] calldata data) external payable override returns (bytes[] memory results) {
        uint256 length = data.length;
        results = new bytes[](length);
        bool success;
        unchecked {
            for (uint256 i = 0; i < length; ++i) {
                /* solhint-disable avoid-low-level-calls */
                //slither-disable-next-line calls-loop,delegatecall-loop
                (success, results[i]) = address(this).delegatecall(data[i]);
                if (!success) revert MulticallFailed();
                /* solhint-enable avoid-low-level-calls */
            }
        }
    }

    /// @inheritdoc IDelegateRegistry
    function delegateAllDuringRegistration(uint256 fromId, uint256 toId)
        external
        payable
        override
        onlyIdGateway
        returns (bytes32 hash)
    {
        _validateDelegatee(toId);
        return _delegateAll({fromId: fromId, toId: toId, rights: "", enable: true});
    }

    /// @inheritdoc IDelegateRegistry
    function delegateAll(uint256 toId, bytes32 rights, bool enable) external payable override returns (bytes32 hash) {
        uint256 fromId = _validateAccounts(msg.sender, toId);
        return _delegateAll(fromId, toId, rights, enable);
    }

    /// @inheritdoc IDelegateRegistry
    function delegateAllFor(
        uint256 fromId,
        uint256 toId,
        bytes32 rights,
        bool enable,
        uint256 deadline,
        bytes calldata sig
    ) external payable override returns (bytes32 hash) {
        _validateDelegatee(toId);

        _verifyDelegateAllSig({fromId: fromId, toId: toId, rights: rights, enable: enable, deadline: deadline, sig: sig});

        return _delegateAll(fromId, toId, rights, enable);
    }

    function _delegateAll(uint256 fromId, uint256 toId, bytes32 rights, bool enable) internal returns (bytes32 hash) {
        hash = Hashes.allHash(fromId, rights, toId);
        bytes32 location = Hashes.location(hash);
        uint256 loadedFromId = _loadFromId(location);

        if (enable) {
            if (loadedFromId == Storage.DELEGATION_EMPTY) {
                _pushDelegationHashes(fromId, toId, hash);
                _writeDelegationCoreData(location, fromId, toId, address(0));
                if (rights != "") _writeDelegation(location, Storage.POSITIONS_RIGHTS, rights);
            } else if (loadedFromId == Storage.DELEGATION_REVOKED) {
                _updateFromId(location, fromId);
            }
        } else if (loadedFromId == fromId) {
            _updateFromId(location, Storage.DELEGATION_REVOKED);
        }

        emit DelegateAll(fromId, toId, rights, enable);
    }

    /// @inheritdoc IDelegateRegistry
    function delegateContract(uint256 toId, address contract_, bytes32 rights, bool enable)
        external
        payable
        override
        returns (bytes32 hash)
    {
        uint256 fromId = _validateAccounts(msg.sender, toId);
        return _delegateContract(fromId, toId, contract_, rights, enable);
    }

    /// @inheritdoc IDelegateRegistry
    function delegateContractFor(
        uint256 fromId,
        uint256 toId,
        address contract_,
        bytes32 rights,
        bool enable,
        uint256 deadline,
        bytes calldata sig
    ) external payable override returns (bytes32 hash) {
        _validateDelegatee(toId);

        _verifyDelegateContractSig({
            fromId: fromId,
            toId: toId,
            contract_: contract_,
            rights: rights,
            enable: enable,
            deadline: deadline,
            sig: sig
        });

        return _delegateContract(fromId, toId, contract_, rights, enable);
    }

    function _delegateContract(uint256 fromId, uint256 toId, address contract_, bytes32 rights, bool enable)
        internal
        returns (bytes32 hash)
    {
        hash = Hashes.contractHash(fromId, rights, toId, contract_);
        bytes32 location = Hashes.location(hash);
        uint256 loadedFromId = _loadFromId(location);
        if (enable) {
            if (loadedFromId == Storage.DELEGATION_EMPTY) {
                _pushDelegationHashes(fromId, toId, hash);
                _writeDelegationCoreData(location, fromId, toId, contract_);
                if (rights != "") _writeDelegation(location, Storage.POSITIONS_RIGHTS, rights);
            } else if (loadedFromId == Storage.DELEGATION_REVOKED) {
                _updateFromId(location, fromId);
            }
        } else if (loadedFromId == fromId) {
            _updateFromId(location, Storage.DELEGATION_REVOKED);
        }
        emit DelegateContract(fromId, toId, contract_, rights, enable);
    }

    /// @inheritdoc IDelegateRegistry
    function delegateERC721(uint256 toId, address contract_, uint256 tokenId, bytes32 rights, bool enable)
        external
        payable
        override
        returns (bytes32 hash)
    {
        uint256 fromId = _validateAccounts(msg.sender, toId);
        return _delegateERC721(fromId, toId, contract_, tokenId, rights, enable);
    }

    /// @inheritdoc IDelegateRegistry
    function delegateERC721For(
        uint256 fromId,
        uint256 toId,
        address contract_,
        uint256 tokenId,
        bytes32 rights,
        bool enable,
        uint256 deadline,
        bytes calldata sig
    ) external payable override returns (bytes32 hash) {
        _validateDelegatee(toId);

        _verifyDelegateERC721Sig({
            fromId: fromId,
            toId: toId,
            contract_: contract_,
            tokenId: tokenId,
            rights: rights,
            enable: enable,
            deadline: deadline,
            sig: sig
        });

        return _delegateERC721(fromId, toId, contract_, tokenId, rights, enable);
    }

    function _delegateERC721(
        uint256 fromId,
        uint256 toId,
        address contract_,
        uint256 tokenId,
        bytes32 rights,
        bool enable
    ) internal returns (bytes32 hash) {
        hash = Hashes.erc721Hash(fromId, rights, toId, tokenId, contract_);
        bytes32 location = Hashes.location(hash);
        uint256 loadedFromId = _loadFromId(location);
        if (enable) {
            if (loadedFromId == Storage.DELEGATION_EMPTY) {
                _pushDelegationHashes(fromId, toId, hash);
                _writeDelegationCoreData(location, fromId, toId, contract_);
                _writeDelegation(location, Storage.POSITIONS_TOKEN_ID, tokenId);
                if (rights != "") _writeDelegation(location, Storage.POSITIONS_RIGHTS, rights);
            } else if (loadedFromId == Storage.DELEGATION_REVOKED) {
                _updateFromId(location, fromId);
            }
        } else if (loadedFromId == fromId) {
            _updateFromId(location, Storage.DELEGATION_REVOKED);
        }
        emit DelegateERC721(fromId, toId, contract_, tokenId, rights, enable);
    }

    // @inheritdoc IDelegateRegistry
    function delegateERC20(uint256 toId, address contract_, bytes32 rights, uint256 amount)
        external
        payable
        override
        returns (bytes32 hash)
    {
        uint256 fromId = _validateAccounts(msg.sender, toId);
        return _delegateERC20(fromId, toId, contract_, rights, amount);
    }

    /// @inheritdoc IDelegateRegistry
    function delegateERC20For(
        uint256 fromId,
        uint256 toId,
        address contract_,
        bytes32 rights,
        uint256 amount,
        uint256 deadline,
        bytes calldata sig
    ) external payable override returns (bytes32 hash) {
        _validateDelegatee(toId);

        _verifyDelegateERC20Sig({
            fromId: fromId,
            toId: toId,
            contract_: contract_,
            rights: rights,
            amount: amount,
            deadline: deadline,
            sig: sig
        });

        return _delegateERC20(fromId, toId, contract_, rights, amount);
    }

    function _delegateERC20(uint256 fromId, uint256 toId, address contract_, bytes32 rights, uint256 amount)
        internal
        returns (bytes32 hash)
    {
        hash = Hashes.erc20Hash(fromId, rights, toId, contract_);
        bytes32 location = Hashes.location(hash);
        uint256 loadedFromId = _loadFromId(location);
        if (amount != 0) {
            if (loadedFromId == Storage.DELEGATION_EMPTY) {
                _pushDelegationHashes(fromId, toId, hash);
                _writeDelegationCoreData(location, fromId, toId, contract_);
                _writeDelegation(location, Storage.POSITIONS_AMOUNT, amount);
                if (rights != "") _writeDelegation(location, Storage.POSITIONS_RIGHTS, rights);
            } else if (loadedFromId == Storage.DELEGATION_REVOKED) {
                _updateFromId(location, fromId);
                _writeDelegation(location, Storage.POSITIONS_AMOUNT, amount);
            } else if (loadedFromId == fromId) {
                _writeDelegation(location, Storage.POSITIONS_AMOUNT, amount);
            }
        } else if (loadedFromId == fromId) {
            _updateFromId(location, Storage.DELEGATION_REVOKED);
            _writeDelegation(location, Storage.POSITIONS_AMOUNT, uint256(0));
        }
        emit DelegateERC20(fromId, toId, contract_, rights, amount);
    }

    /// @inheritdoc IDelegateRegistry
    function delegateERC1155(uint256 toId, address contract_, uint256 tokenId, bytes32 rights, uint256 amount)
        external
        payable
        override
        returns (bytes32 hash)
    {
        uint256 fromId = _validateAccounts(msg.sender, toId);
        return _delegateERC1155(fromId, toId, contract_, tokenId, rights, amount);
    }

    function delegateERC1155For(
        uint256 fromId,
        uint256 toId,
        address contract_,
        uint256 tokenId,
        bytes32 rights,
        uint256 amount,
        uint256 deadline,
        bytes calldata sig
    ) external payable override returns (bytes32 hash) {
        _validateDelegatee(toId);

        _verifyDelegateERC1155Sig({
            fromId: fromId,
            toId: toId,
            contract_: contract_,
            tokenId: tokenId,
            rights: rights,
            amount: amount,
            deadline: deadline,
            sig: sig
        });

        return _delegateERC1155(fromId, toId, contract_, tokenId, rights, amount);
    }

    function _delegateERC1155(
        uint256 fromId,
        uint256 toId,
        address contract_,
        uint256 tokenId,
        bytes32 rights,
        uint256 amount
    ) internal returns (bytes32 hash) {
        hash = Hashes.erc1155Hash(fromId, rights, toId, tokenId, contract_);
        bytes32 location = Hashes.location(hash);
        uint256 loadedFromId = _loadFromId(location);
        if (amount != 0) {
            if (loadedFromId == Storage.DELEGATION_EMPTY) {
                _pushDelegationHashes(fromId, toId, hash);
                _writeDelegationCoreData(location, fromId, toId, contract_);
                _writeDelegation(location, Storage.POSITIONS_TOKEN_ID, tokenId);
                _writeDelegation(location, Storage.POSITIONS_AMOUNT, amount);
                if (rights != "") _writeDelegation(location, Storage.POSITIONS_RIGHTS, rights);
            } else if (loadedFromId == Storage.DELEGATION_REVOKED) {
                _updateFromId(location, fromId);
                _writeDelegation(location, Storage.POSITIONS_AMOUNT, amount);
            } else if (loadedFromId == fromId) {
                _writeDelegation(location, Storage.POSITIONS_AMOUNT, amount);
            }
        } else if (loadedFromId == fromId) {
            _updateFromId(location, Storage.DELEGATION_REVOKED);
            _writeDelegation(location, Storage.POSITIONS_AMOUNT, uint256(0));
        }
        emit DelegateERC1155(fromId, toId, contract_, tokenId, rights, amount);
    }

    /**
     * ----------- CHECKS -----------
     */

    /// @inheritdoc IDelegateRegistry
    function checkDelegateForAll(uint256 toId, uint256 fromId, bytes32 rights)
        external
        view
        override
        returns (bool valid)
    {
        if (!_invalidFromId(fromId)) {
            valid = _validateFromId(Hashes.allLocation(fromId, "", toId), fromId);
            if (!Ops.or(rights == "", valid)) valid = _validateFromId(Hashes.allLocation(fromId, rights, toId), fromId);
        }
        assembly ("memory-safe") {
            // Only first 32 bytes of scratch space is accessed
            mstore(0, iszero(iszero(valid))) // Compiler cleans dirty booleans on the stack to 1, so do the same here
            return(0, 32) // Direct return, skips Solidity's redundant copying to save gas
        }
    }

    /// @inheritdoc IDelegateRegistry
    function checkDelegateForContract(uint256 toId, uint256 fromId, address contract_, bytes32 rights)
        external
        view
        override
        returns (bool valid)
    {
        if (!_invalidFromId(fromId)) {
            valid = _validateFromId(Hashes.allLocation(fromId, "", toId), fromId)
                || _validateFromId(Hashes.contractLocation(fromId, "", toId, contract_), fromId);
            if (!Ops.or(rights == "", valid)) {
                valid = _validateFromId(Hashes.allLocation(fromId, rights, toId), fromId)
                    || _validateFromId(Hashes.contractLocation(fromId, rights, toId, contract_), fromId);
            }
        }
        assembly ("memory-safe") {
            // Only first 32 bytes of scratch space is accessed
            mstore(0, iszero(iszero(valid))) // Compiler cleans dirty booleans on the stack to 1, so do the same here
            return(0, 32) // Direct return, skips Solidity's redundant copying to save gas
        }
    }

    /// @inheritdoc IDelegateRegistry
    function checkDelegateForERC721(uint256 toId, uint256 fromId, address contract_, uint256 tokenId, bytes32 rights)
        external
        view
        override
        returns (bool valid)
    {
        if (!_invalidFromId(fromId)) {
            valid = _validateFromId(Hashes.allLocation(fromId, "", toId), fromId)
                || _validateFromId(Hashes.contractLocation(fromId, "", toId, contract_), fromId)
                || _validateFromId(Hashes.erc721Location(fromId, "", toId, tokenId, contract_), fromId);
            if (!Ops.or(rights == "", valid)) {
                valid = _validateFromId(Hashes.allLocation(fromId, rights, toId), fromId)
                    || _validateFromId(Hashes.contractLocation(fromId, rights, toId, contract_), fromId)
                    || _validateFromId(Hashes.erc721Location(fromId, rights, toId, tokenId, contract_), fromId);
            }
        }
        assembly ("memory-safe") {
            // Only first 32 bytes of scratch space is accessed
            mstore(0, iszero(iszero(valid))) // Compiler cleans dirty booleans on the stack to 1, so do the same here
            return(0, 32) // Direct return, skips Solidity's redundant copying to save gas
        }
    }

    /// @inheritdoc IDelegateRegistry
    function checkDelegateForERC20(uint256 toId, uint256 fromId, address contract_, bytes32 rights)
        external
        view
        override
        returns (uint256 amount)
    {
        if (!_invalidFromId(fromId)) {
            amount = (
                _validateFromId(Hashes.allLocation(fromId, "", toId), fromId)
                    || _validateFromId(Hashes.contractLocation(fromId, "", toId, contract_), fromId)
            )
                ? type(uint256).max
                : _loadDelegationUint(Hashes.erc20Location(fromId, "", toId, contract_), Storage.POSITIONS_AMOUNT);
            if (!Ops.or(rights == "", amount == type(uint256).max)) {
                uint256 rightsBalance = (
                    _validateFromId(Hashes.allLocation(fromId, rights, toId), fromId)
                        || _validateFromId(Hashes.contractLocation(fromId, rights, toId, contract_), fromId)
                )
                    ? type(uint256).max
                    : _loadDelegationUint(Hashes.erc20Location(fromId, rights, toId, contract_), Storage.POSITIONS_AMOUNT);
                amount = Ops.max(rightsBalance, amount);
            }
        }
        assembly ("memory-safe") {
            mstore(0, amount) // Only first 32 bytes of scratch space being accessed
            return(0, 32) // Direct return, skips Solidity's redundant copying to save gas
        }
    }

    /// @inheritdoc IDelegateRegistry
    function checkDelegateForERC1155(uint256 toId, uint256 fromId, address contract_, uint256 tokenId, bytes32 rights)
        external
        view
        override
        returns (uint256 amount)
    {
        if (!_invalidFromId(fromId)) {
            amount = (
                _validateFromId(Hashes.allLocation(fromId, "", toId), fromId)
                    || _validateFromId(Hashes.contractLocation(fromId, "", toId, contract_), fromId)
            )
                ? type(uint256).max
                : _loadDelegationUint(
                    Hashes.erc1155Location(fromId, "", toId, tokenId, contract_), Storage.POSITIONS_AMOUNT
                );
            if (!Ops.or(rights == "", amount == type(uint256).max)) {
                uint256 rightsBalance = (
                    _validateFromId(Hashes.allLocation(fromId, rights, toId), fromId)
                        || _validateFromId(Hashes.contractLocation(fromId, rights, toId, contract_), fromId)
                )
                    ? type(uint256).max
                    : _loadDelegationUint(
                        Hashes.erc1155Location(fromId, rights, toId, tokenId, contract_), Storage.POSITIONS_AMOUNT
                    );
                amount = Ops.max(rightsBalance, amount);
            }
        }
        assembly ("memory-safe") {
            mstore(0, amount) // Only first 32 bytes of scratch space is accessed
            return(0, 32) // Direct return, skips Solidity's redundant copying to save gas
        }
    }

    /**
     * ----------- ENUMERATIONS -----------
     */

    /// @inheritdoc IDelegateRegistry
    function getIncomingDelegations(uint256 toId) external view override returns (Delegation[] memory delegations_) {
        delegations_ = _getValidDelegationsFromHashes(_incomingDelegationHashes[toId]);
    }

    /// @inheritdoc IDelegateRegistry
    function getOutgoingDelegations(uint256 fromId) external view override returns (Delegation[] memory delegations_) {
        delegations_ = _getValidDelegationsFromHashes(_outgoingDelegationHashes[fromId]);
    }

    /// @inheritdoc IDelegateRegistry
    function getIncomingDelegationHashes(uint256 toId)
        external
        view
        override
        returns (bytes32[] memory delegationHashes)
    {
        delegationHashes = _getValidDelegationHashesFromHashes(_incomingDelegationHashes[toId]);
    }

    /// @inheritdoc IDelegateRegistry
    function getOutgoingDelegationHashes(uint256 fromId)
        external
        view
        override
        returns (bytes32[] memory delegationHashes)
    {
        delegationHashes = _getValidDelegationHashesFromHashes(_outgoingDelegationHashes[fromId]);
    }

    /// @inheritdoc IDelegateRegistry
    function getDelegationsFromHashes(bytes32[] calldata hashes)
        external
        view
        override
        returns (Delegation[] memory delegations_)
    {
        uint256 length = hashes.length;
        delegations_ = new Delegation[](length);
        unchecked {
            for (uint256 i = 0; i < length; ++i) {
                bytes32 location = Hashes.location(hashes[i]);
                uint256 fromId = _loadFromId(location);
                if (_invalidFromId(fromId)) {
                    delegations_[i] = Delegation({
                        type_: DelegationType.NONE,
                        toId: 0,
                        fromId: 0,
                        rights: "",
                        amount: 0,
                        contract_: address(0),
                        tokenId: 0
                    });
                } else {
                    delegations_[i] = Delegation({
                        type_: Hashes.decodeType(hashes[i]),
                        toId: _loadDelegationUint(location, Storage.POSITIONS_TO),
                        fromId: fromId,
                        rights: _loadDelegationBytes32(location, Storage.POSITIONS_RIGHTS),
                        amount: _loadDelegationUint(location, Storage.POSITIONS_AMOUNT),
                        contract_: _loadDelegationAddress(location, Storage.POSITIONS_CONTRACT),
                        tokenId: _loadDelegationUint(location, Storage.POSITIONS_TOKEN_ID)
                    });
                }
            }
        }
    }

    /**
     * ----------- EXTERNAL STORAGE ACCESS -----------
     */
    function readSlot(bytes32 location) external view override returns (bytes32 contents) {
        assembly {
            contents := sload(location)
        }
    }

    function readSlots(bytes32[] calldata locations) external view override returns (bytes32[] memory contents) {
        uint256 length = locations.length;
        contents = new bytes32[](length);
        bytes32 tempLocation;
        bytes32 tempValue;
        unchecked {
            for (uint256 i = 0; i < length; ++i) {
                tempLocation = locations[i];
                assembly {
                    tempValue := sload(tempLocation)
                }
                contents[i] = tempValue;
            }
        }
    }

    /**
     * ----------- ERC165 -----------
     */

    /// @notice Query if a contract implements an ERC-165 interface
    /// @param interfaceId The interface identifier
    /// @return valid Whether the queried interface is supported
    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return Ops.or(interfaceId == type(IDelegateRegistry).interfaceId, interfaceId == 0x01ffc9a7);
    }

    /**
     * ----------- INTERNAL -----------
     */

    /// @dev Helper function to push new delegation hashes to the incoming and outgoing hashes mappings
    function _pushDelegationHashes(uint256 fromId, uint256 toId, bytes32 delegationHash) internal {
        _outgoingDelegationHashes[fromId].push(delegationHash);
        _incomingDelegationHashes[toId].push(delegationHash);
    }

    /// @dev Helper function that writes bytes32 data to delegation data location at array position
    function _writeDelegation(bytes32 location, uint256 position, bytes32 data) internal {
        assembly {
            sstore(add(location, position), data)
        }
    }

    /// @dev Helper function that writes uint256 data to delegation data location at array position
    function _writeDelegation(bytes32 location, uint256 position, uint256 data) internal {
        assembly {
            sstore(add(location, position), data)
        }
    }

    /// @dev Helper function that writes core delegation data according to the packing rule for delegation storage
    function _writeDelegationCoreData(bytes32 location, uint256 fromId, uint256 toId, address contract_) internal {
        uint256 fromPos = Storage.POSITIONS_FROM;
        uint256 toPos = Storage.POSITIONS_TO;
        uint256 contractPos = Storage.POSITIONS_CONTRACT;
        assembly {
            // Clean the upper 96 bits.
            contract_ := shr(96, shl(96, contract_))

            sstore(add(location, fromPos), fromId)
            sstore(add(location, toPos), toId)
            sstore(add(location, contractPos), contract_)
        }
    }

    /// @dev Helper function that writes `fromId`
    function _updateFromId(bytes32 location, uint256 fromId) internal {
        uint256 fromPos = Storage.POSITIONS_FROM;
        assembly {
            sstore(add(location, fromPos), fromId)
        }
    }

    /// @dev Helper function that takes an array of delegation hashes and returns an array of Delegation structs with their onchain information
    function _getValidDelegationsFromHashes(bytes32[] storage hashes)
        internal
        view
        returns (Delegation[] memory delegations_)
    {
        uint256 count = 0;
        uint256 hashesLength = hashes.length;
        bytes32 hash;
        bytes32[] memory filteredHashes = new bytes32[](hashesLength);
        unchecked {
            for (uint256 i = 0; i < hashesLength; ++i) {
                hash = hashes[i];
                if (_invalidFromId(_loadFromId(Hashes.location(hash)))) continue;
                filteredHashes[count++] = hash;
            }
            delegations_ = new Delegation[](count);
            bytes32 location;
            for (uint256 i = 0; i < count; ++i) {
                hash = filteredHashes[i];
                location = Hashes.location(hash);
                delegations_[i] = Delegation({
                    type_: Hashes.decodeType(hash),
                    toId: _loadDelegationUint(location, Storage.POSITIONS_TO),
                    fromId: _loadDelegationUint(location, Storage.POSITIONS_FROM),
                    rights: _loadDelegationBytes32(location, Storage.POSITIONS_RIGHTS),
                    amount: _loadDelegationUint(location, Storage.POSITIONS_AMOUNT),
                    contract_: _loadDelegationAddress(location, Storage.POSITIONS_CONTRACT),
                    tokenId: _loadDelegationUint(location, Storage.POSITIONS_TOKEN_ID)
                });
            }
        }
    }

    /// @dev Helper function that takes an array of delegation hashes and returns an array of valid delegation hashes
    function _getValidDelegationHashesFromHashes(bytes32[] storage hashes)
        internal
        view
        returns (bytes32[] memory validHashes)
    {
        uint256 count = 0;
        uint256 hashesLength = hashes.length;
        bytes32 hash;
        bytes32[] memory filteredHashes = new bytes32[](hashesLength);
        unchecked {
            for (uint256 i = 0; i < hashesLength; ++i) {
                hash = hashes[i];
                if (_invalidFromId(_loadFromId(Hashes.location(hash)))) continue;
                filteredHashes[count++] = hash;
            }
            validHashes = new bytes32[](count);
            for (uint256 i = 0; i < count; ++i) {
                validHashes[i] = filteredHashes[i];
            }
        }
    }

    /// @dev Helper function that loads delegation data from a particular array position and returns as bytes32
    function _loadDelegationBytes32(bytes32 location, uint256 position) internal view returns (bytes32 data) {
        assembly {
            data := sload(add(location, position))
        }
    }

    /// @dev Helper function that loads delegation data from a particular array position and returns as uint256
    function _loadDelegationUint(bytes32 location, uint256 position) internal view returns (uint256 data) {
        assembly {
            data := sload(add(location, position))
        }
    }

    /// @dev Helper function that loads delegation data from a particular array position and returns as address
    function _loadDelegationAddress(bytes32 location, uint256 position) internal view returns (address data) {
        assembly {
            data := sload(add(location, position))
        }
    }

    // @dev Helper function that loads the fromId from storage according to delegation storage
    function _loadFromId(bytes32 location) internal view returns (uint256 fromId) {
        uint256 fromPos = Storage.POSITIONS_FROM;

        assembly {
            fromId := sload(add(location, fromPos))
        }
    }

    /// @dev Helper function to establish whether a delegation is enabled
    function _validateFromId(bytes32 location, uint256 fromId) internal view returns (bool) {
        return (fromId == _loadFromId(location));
    }

    /// @dev Helper function to verify that both the msg.sender and the toId are valid protocol accounts
    function _validateAccounts(address from, uint256 toId) internal view returns (uint256 fromId) {
        _validateDelegatee(toId);

        // Check that the `from` address is actually registered in the idRegistry
        fromId = idRegistry.idOf(from);
        if (fromId == 0) revert DelegatorDoesNotExist();
    }

    /// @dev Helper function to verify that the toId is a valid protocol account
    function _validateDelegatee(uint256 toId) internal view {
        // Check that the toId is actually registered in the idRegistry
        if (idRegistry.custodyOf(toId) == address(0)) revert DelegateeDoesNotExist();
    }

    function _invalidFromId(uint256 fromId) internal pure returns (bool isInvalid) {
        return Ops.or(fromId == Storage.DELEGATION_EMPTY, fromId == Storage.DELEGATION_REVOKED);
    }

    /**
     * ----------- SIGNATURES -----------
     */
    function _verifyDelegateAllSig(
        uint256 fromId,
        uint256 toId,
        bytes32 rights,
        bool enable,
        uint256 deadline,
        bytes calldata sig
    ) internal {
        address from = idRegistry.custodyOf(fromId);

        bytes32 digest = _hashTypedData(
            keccak256(abi.encode(DELEGATE_ALL_TYPEHASH, fromId, toId, rights, enable, _useNonce(from), deadline))
        );

        _verifySig(digest, from, deadline, sig);
    }

    function _verifyDelegateContractSig(
        uint256 fromId,
        uint256 toId,
        address contract_,
        bytes32 rights,
        bool enable,
        uint256 deadline,
        bytes calldata sig
    ) internal {
        address from = idRegistry.custodyOf(fromId);

        bytes32 digest = _hashTypedData(
            keccak256(
                abi.encode(
                    DELEGATE_CONTRACT_TYPEHASH, fromId, toId, contract_, rights, enable, _useNonce(from), deadline
                )
            )
        );

        _verifySig(digest, from, deadline, sig);
    }

    function _verifyDelegateERC721Sig(
        uint256 fromId,
        uint256 toId,
        address contract_,
        uint256 tokenId,
        bytes32 rights,
        bool enable,
        uint256 deadline,
        bytes calldata sig
    ) internal {
        address from = idRegistry.custodyOf(fromId);

        bytes32 digest = _hashTypedData(
            keccak256(
                abi.encode(
                    DELEGATE_ERC721_TYPEHASH,
                    fromId,
                    toId,
                    contract_,
                    tokenId,
                    rights,
                    enable,
                    _useNonce(from),
                    deadline
                )
            )
        );

        _verifySig(digest, from, deadline, sig);
    }

    function _verifyDelegateERC20Sig(
        uint256 fromId,
        uint256 toId,
        address contract_,
        bytes32 rights,
        uint256 amount,
        uint256 deadline,
        bytes calldata sig
    ) internal {
        address from = idRegistry.custodyOf(fromId);

        bytes32 digest = _hashTypedData(
            keccak256(abi.encode(DELEGATE_ERC20, fromId, toId, contract_, rights, amount, _useNonce(from), deadline))
        );

        _verifySig(digest, from, deadline, sig);
    }

    function _verifyDelegateERC1155Sig(
        uint256 fromId,
        uint256 toId,
        address contract_,
        uint256 tokenId,
        bytes32 rights,
        uint256 amount,
        uint256 deadline,
        bytes calldata sig
    ) internal {
        address from = idRegistry.custodyOf(fromId);

        bytes32 digest = _hashTypedData(
            keccak256(
                abi.encode(
                    DELEGATE_ERC1155, fromId, toId, contract_, tokenId, rights, amount, _useNonce(from), deadline
                )
            )
        );

        _verifySig(digest, from, deadline, sig);
    }

    /**
     * ----------- SETTERS -----------
     */

    /// @notice Set the address of the IdRegistry contract.
    function setIdRegistry(address idRegistry_) external onlyOwner {
        emit IdRegistrySet(address(idRegistry), idRegistry_);
        idRegistry = IIdRegistry(idRegistry_);
    }

    /// @notice Set the address of the IdGateway contract.
    function setIdGateway(address idGateway_) external onlyOwner {
        emit IdGatewaySet(idGateway, idGateway_);
        idGateway = idGateway_;
    }

    /**
     * ------------ UUPS ------------
     */

    // solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}

/* solhint-enable func-named-parameters, comprehensive-interface */
