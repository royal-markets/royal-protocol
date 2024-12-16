// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IWithdrawable} from "../interfaces/abstract/IWithdrawable.sol";
import {Guardians} from "../abstract/Guardians.sol";

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/interfaces/IERC721.sol";
import {IERC1155} from "@openzeppelin/contracts/interfaces/IERC1155.sol";

/// @notice Abstract contract that provides the ability to withdraw ETH, ERC20, ERC721, and ERC1155 tokens.
///
/// @dev - The implementing contract will need to call _initializeOwner() in either the constructor or an initializer,
///        since all the withdrawal functions are restricted to the owner.
abstract contract Withdrawable is IWithdrawable, Guardians {
    // =============================================================
    //                          WITHDRAW ETH
    // =============================================================

    /// @inheritdoc IWithdrawable
    function withdraw(address receiver) external onlyOwner {
        if (receiver == address(0)) revert AddressZero();

        emit Withdrawn(receiver, address(this).balance);

        (bool sent,) = payable(receiver).call{value: address(this).balance}("");
        if (!sent) revert WithdrawalFailed();
    }

    // =============================================================
    //                          WITHDRAW ERC20
    // =============================================================

    /// @inheritdoc IWithdrawable
    function withdrawERC20(address receiver, address token, uint256 amount) external onlyOwner {
        _withdrawERC20(receiver, token, amount);
    }

    /// @inheritdoc IWithdrawable
    function withdrawAllERC20(address receiver, address token) external onlyOwner {
        uint256 totalBalance = IERC20(token).balanceOf(address(this));

        _withdrawERC20(receiver, token, totalBalance);
    }

    /// @dev Withdraws `amount` of an ERC20 token from the contract.
    function _withdrawERC20(address receiver, address token, uint256 amount) internal {
        if (receiver == address(0)) revert AddressZero();
        if (token == address(0)) revert AddressZero();

        IERC20 erc20 = IERC20(token);
        if (erc20.balanceOf(address(this)) < amount) revert InsufficientBalance();

        emit WithdrawnERC20(receiver, token, amount);

        bool success = erc20.transfer(receiver, amount);
        if (!success) revert WithdrawalFailed();
    }

    // =============================================================
    //                          WITHDRAW ERC721
    // =============================================================

    /// @inheritdoc IWithdrawable
    function withdrawERC721(address receiver, address token, uint256 tokenId) external onlyOwner {
        if (receiver == address(0)) revert AddressZero();
        if (token == address(0)) revert AddressZero();

        emit WithdrawnERC721(receiver, token, tokenId);

        IERC721 erc721 = IERC721(token);
        erc721.transferFrom(address(this), receiver, tokenId);
    }

    // =============================================================
    //                          WITHDRAW ERC1155
    // =============================================================

    /// @inheritdoc IWithdrawable
    function withdrawERC1155(address receiver, address token, uint256 tokenId, uint256 amount, bytes calldata data)
        external
        onlyOwner
    {
        _withdrawERC1155({receiver: receiver, token: token, tokenId: tokenId, amount: amount, data: data});
    }

    /// @inheritdoc IWithdrawable
    function withdrawAllERC1155(address receiver, address token, uint256 tokenId, bytes calldata data)
        external
        onlyOwner
    {
        uint256 totalBalance = IERC1155(token).balanceOf(address(this), tokenId);

        _withdrawERC1155({receiver: receiver, token: token, tokenId: tokenId, amount: totalBalance, data: data});
    }

    /// @dev Withdraws `amount` of an ERC1155 token from the contract.
    function _withdrawERC1155(address receiver, address token, uint256 tokenId, uint256 amount, bytes calldata data)
        internal
    {
        if (receiver == address(0)) revert AddressZero();
        if (token == address(0)) revert AddressZero();

        IERC1155 erc1155 = IERC1155(token);
        if (erc1155.balanceOf(address(this), tokenId) < amount) revert InsufficientBalance();

        emit WithdrawnERC1155(receiver, token, tokenId, amount);

        erc1155.safeTransferFrom({from: address(this), to: receiver, id: tokenId, value: amount, data: data});
    }
}
