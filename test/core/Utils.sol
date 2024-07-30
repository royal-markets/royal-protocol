// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC721} from "solady/tokens/ERC721.sol";

contract ERC721Mock is ERC721 {
    // solhint-disable-next-line no-empty-blocks
    constructor() {}

    function mint(address to, uint256 tokenId) external {
        _mint(to, tokenId);
    }

    function name() public pure override returns (string memory) {
        return "ERC721Mock";
    }

    function symbol() public pure override returns (string memory) {
        return "ERC721Mock";
    }

    function tokenURI(uint256 tokenId) public pure override returns (string memory) {
        return string(abi.encodePacked("https://example.com/", tokenId));
    }
}