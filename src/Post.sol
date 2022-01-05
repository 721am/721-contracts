// SPDX-License-Identifier: MIT
// https://github.com/OpenZeppelin/openzeppelin-contracts/commit/8e0296096449d9b1cd7c5631e917330635244c37
import 'openzeppelin-solidity/contracts/cryptography/ECDSA.sol';
import 'openzeppelin-solidity/contracts/math/SafeMath.sol';
import './UserData.sol';
import './IERC2981.sol';
import './BaseRelayRecipient.sol';

pragma experimental ABIEncoderV2;
pragma solidity 0.6.12;

contract Post is UserData, BaseRelayRecipient, IERC2981 {

    string private constant ERROR_INVALID_INPUTS = "Each field must have the same number of values";

    mapping(uint256 => address) tokenCreator;
    mapping(address => address) royaltyReceiver;

    address private constant _NULL_ADDRESS = 0x0000000000000000000000000000000000000000;

    bytes4 private constant _INTERFACE_ID_ERC2981 = 0x2a55205a;

    constructor() public ERC721("Posts", "POST") {
        _registerInterface(_INTERFACE_ID_ERC2981);

        // hardcode the trusted forwarded for EIP2771 metatransactions
        _setTrustedForwarder(0x86C80a8aa58e0A4fa09A69624c31Ab2a6CAD56b8);
    }

    /* -- BEGIN minting APIs -- */
    function mintFromSignature(
        string memory messageTokenURI,
        string memory messageSuffix,
        bytes memory minterSignature
    ) external {
        bytes32 minterHash = keccak256(abi.encodePacked(
            "POST\n\n",
            "Metadata: ", messageTokenURI, "\n\n",
            messageSuffix
        ));
        address minter = ECDSA.recover(minterHash, minterSignature);

        uint256 tokenID = _calculateTokenID(minter, messageTokenURI);
        // Prevent signature reuse
        require(getTokenCreator(tokenID) == _NULL_ADDRESS, "Token previously minted");

        _mint(minter, tokenID);
        _setTokenURI(tokenID, messageTokenURI);
        _setTokenCreator(tokenID, minter);
    }

    function mint(
        string memory tokenURI
    ) external {
        address minter = _msgSender();
        uint256 tokenID = _calculateTokenID(minter, tokenURI);

        _mint(minter, tokenID);
        _setTokenURI(tokenID, tokenURI);
        _setTokenCreator(tokenID, minter);
    }

    // Generate deterministic tokenID for reorg-resistant composability.
    function _calculateTokenID(
        address minter,
        string memory tokenURI
    ) internal pure returns (uint256) {
        return uint256(keccak256(abi.encode(minter, tokenURI))) & 0xFFFFFFFFFFFFFFFF;
    }
    /* -- END minting APIs -- */

    function isApprovedOrOwner(
        address spender,
        uint256 tokenID
    ) external view returns (bool) {
        return _isApprovedOrOwner(spender, tokenID);
    }

    /* -- BEGIN batch methods */
    function burnBatch(
        uint256[] memory tokenIDs
    ) external {
        for (uint256 i = 0; i < tokenIDs.length; ++i) {
            burn(tokenIDs[i]);
        }
    }

    function approveBatch(
        address[] memory tos,
        uint256[] memory tokenIDs
    ) external {
        require(tos.length == tokenIDs.length, ERROR_INVALID_INPUTS);
        for (uint256 i = 0; i < tos.length; ++i) {
            approve(tos[i], tokenIDs[i]);
        }
    }

    function transferFromBatch(
        address[] memory froms,
        address[] memory tos,
        uint256[] memory tokenIDs
    ) external {
        require(
            froms.length == tos.length &&
            froms.length == tokenIDs.length,
            ERROR_INVALID_INPUTS
        );
        for (uint256 i = 0; i < froms.length; ++i) {
            transferFrom(froms[i], tos[i], tokenIDs[i]);
        }
    }

    function safeTransferFromBatch(
        address[] memory froms,
        address[] memory tos,
        uint256[] memory tokenIDs
    ) external {
        require(
            froms.length == tos.length &&
            froms.length == tokenIDs.length,
            ERROR_INVALID_INPUTS
        );
        for (uint256 i = 0; i < froms.length; ++i) {
            safeTransferFrom(froms[i], tos[i], tokenIDs[i], "");
        }
    }

    function safeTransferFromWithDataBatch(
        address[] memory froms,
        address[] memory tos,
        uint256[] memory tokenIDs,
        bytes[] memory datas
    ) external {
        require(
            froms.length == tos.length &&
            froms.length == tokenIDs.length &&
            froms.length == datas.length,
            ERROR_INVALID_INPUTS
        );
        for (uint256 i = 0; i < froms.length; ++i) {
            safeTransferFrom(froms[i], tos[i], tokenIDs[i], datas[i]);
        }
    }

    function isApprovedOrOwnerBatch(
        address[] memory spenders,
        uint256[] memory tokenIDs
    ) external view returns (bool[] memory) {
        require(spenders.length == tokenIDs.length, ERROR_INVALID_INPUTS);
        bool[] memory approvals = new bool[](spenders.length);
        for (uint256 i = 0; i < spenders.length; ++i) {
            approvals[i] = _isApprovedOrOwner(spenders[i], tokenIDs[i]);
        }
        return approvals;
    }

    function existsBatch(
        uint256[] memory tokenIDs
    ) external view returns (bool[] memory) {
        bool[] memory exists = new bool[](tokenIDs.length);
        for (uint256 i = 0; i < tokenIDs.length; ++i) {
            exists[i] = _exists(tokenIDs[i]);
        }
        return exists;
    }
    /* -- END batch methods */

    /* -- BEGIN ERC2981 supporting methods */
    function _setTokenCreator(
        uint256 tokenID,
        address creator
    ) internal {
        tokenCreator[tokenID] = creator;
    }

    function getTokenCreator(
        uint256 tokenID
    ) public view returns (address) {
        return tokenCreator[tokenID];
    }

    function royaltyInfo(
        uint256 tokenID,
        uint256 salePrice
    ) external view override returns (address, uint256) {
        address creator = getTokenCreator(tokenID);
        address receiver = royaltyReceiver[creator];
        if (receiver == _NULL_ADDRESS) {
            receiver = creator;
        }
        return (receiver, salePrice / 10);
    }

    // Allow the creator to change the recipient of their address's royalties
    function changeRoyaltyReceiver(address newReceiver) external {
        royaltyReceiver[_msgSender()] = newReceiver;
    }
    /* -- END ERC2981 supporting methods */

    /* -- BEGIN IRelayRecipient overrides -- */
    function _msgSender() internal override(Context, BaseRelayRecipient) view returns (address payable) {
        return BaseRelayRecipient._msgSender();
    }

    string public override versionRecipient = "1";
    /* -- END IRelayRecipient overrides -- */
}
