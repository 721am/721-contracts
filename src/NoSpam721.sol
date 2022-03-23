// SPDX-License-Identifier: MIT
// https://github.com/OpenZeppelin/openzeppelin-contracts/commit/8e0296096449d9b1cd7c5631e917330635244c37
import 'openzeppelin-solidity/contracts/token/ERC721/ERC721Burnable.sol';

pragma solidity 0.6.12;

abstract contract NoSpam721 is ERC721Burnable {
    /**
     * @dev See {IERC721-transferFrom}.
     */
    function transferFrom(address from, address to, uint256 tokenId) public virtual override {
        //solhint-disable-next-line max-line-length
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");
        require(to == _msgSender() || to == tx.origin, "NoSpam721: only approved recipient can complete transfer");

        _transfer(from, to, tokenId);
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory _data) public virtual override {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");
        require(to == _msgSender() || to == tx.origin, "NoSpam721: only approved recipient can complete transfer");
        _safeTransfer(from, to, tokenId, _data);
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(address from, address to, uint256 tokenId) public virtual override {
        safeTransferFrom(from, to, tokenId, "");
    }
}