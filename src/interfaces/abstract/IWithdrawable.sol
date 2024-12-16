// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IWithdrawable {
    // =============================================================
    //                           EVENTS
    // =============================================================

    /// @dev Emitted when ETH is withdrawn from the contract.
    event Withdrawn(address receiver, uint256 amount);

    /// @dev Emitted when an ERC20 token is withdrawn from the contract.
    event WithdrawnERC20(address receiver, address token, uint256 amount);

    /// @dev Emitted when an ERC721 token is withdrawn from the contract.
    event WithdrawnERC721(address receiver, address token, uint256 tokenId);

    /// @dev Emitted when an ERC1155 token is withdrawn from the contract.
    event WithdrawnERC1155(address receiver, address token, uint256 tokenId, uint256 amount);

    // =============================================================
    //                          ERRORS
    // =============================================================

    /// @dev Error emitted when the provided address is the zero address.
    error AddressZero();

    /// @dev Error emitted when the provided amount to withdraw is less than the contract's balance.
    error InsufficientBalance();

    /// @dev Error emitted when the withdrawal fails.
    error WithdrawalFailed();

    // =============================================================
    //                          WITHDRAW ETH
    // =============================================================

    /**
     * @notice Withdraws ETH from the contract.
     *
     * @param receiver The address to receive the ETH.
     *
     * @dev Only the contract owner can call this function.
     */
    function withdraw(address receiver) external;

    // =============================================================
    //                          WITHDRAW ERC20
    // =============================================================

    /**
     * @notice Withdraws `amount` of an ERC20 token from the contract.
     *
     * @param receiver The address to receive the ERC20 tokens.
     * @param token The ERC20 token address.
     * @param amount The amount of ERC20 tokens to withdraw.
     *
     * @dev Only the contract owner can call this function.
     */
    function withdrawERC20(address receiver, address token, uint256 amount) external;

    /**
     * @notice Withdraws all of a given ERC20 token from the contract.
     *
     * @param receiver The address to receive the ERC20 tokens.
     * @param token The ERC20 token address.
     *
     * @dev Only the contract owner can call this function.
     */
    function withdrawAllERC20(address receiver, address token) external;

    // =============================================================
    //                          WITHDRAW ERC721
    // =============================================================

    /**
     * @notice Withdraws an ERC721 token from the contract.
     *
     * @param receiver The address to receive the ERC721 token.
     * @param token The ERC721 token address.
     * @param tokenId The ERC721 token ID.
     *
     * @dev Only the contract owner can call this function.
     */
    function withdrawERC721(address receiver, address token, uint256 tokenId) external;

    // =============================================================
    //                          WITHDRAW ERC1155
    // =============================================================

    /**
     * @notice Withdraws an ERC1155 token from the contract.
     *
     * @param receiver The address to receive the ERC1155 token.
     * @param token The ERC1155 token address.
     * @param tokenId The ERC1155 token ID.
     * @param amount The amount of ERC1155 tokens to withdraw.
     * @param data Additional data with no specified format.
     *
     * @dev Only the contract owner can call this function.
     */
    function withdrawERC1155(address receiver, address token, uint256 tokenId, uint256 amount, bytes calldata data)
        external;

    /**
     * @notice Withdraws all of a given ERC1155 token from the contract.
     *
     * @param receiver The address to receive the ERC1155 tokens.
     * @param token The ERC1155 token address.
     * @param tokenId The ERC1155 token ID.
     * @param data Additional data with no specified format.
     *
     * @dev Only the contract owner can call this function.
     */
    function withdrawAllERC1155(address receiver, address token, uint256 tokenId, bytes calldata data) external;
}
