// SPDX-License-Identifier: MIT
// https://github.com/OpenZeppelin/openzeppelin-contracts/commit/8e0296096449d9b1cd7c5631e917330635244c37
import 'openzeppelin-solidity/contracts/cryptography/ECDSA.sol';
import './NoSpam721.sol';
import './IERC2981.sol';
import './BaseRelayRecipient.sol';
import './StringParser.sol';

pragma experimental ABIEncoderV2;
pragma solidity 0.6.12;

contract Like is NoSpam721, IERC2981, BaseRelayRecipient {

    string private constant ERROR_INVALID_INPUTS = "Each field must have the same number of values";

    address private constant _NULL_ADDRESS = 0x0000000000000000000000000000000000000000;

    bytes4 private constant _INTERFACE_ID_ERC2981 = 0x2a55205a;

    struct Token {
        address collection;
        uint256 id;
        string uri;
    }

    mapping(uint256 => bytes32) tokenRefs;
    mapping(bytes32 => Token) tokens;

    constructor() public ERC721("Likes", "LIKE") {
        _registerInterface(_INTERFACE_ID_ERC2981);

        // hardcode the trusted forwarded for EIP2771 metatransactions
        _setTrustedForwarder(0x86C80a8aa58e0A4fa09A69624c31Ab2a6CAD56b8);
    }
    /* -- BEGIN minting APIs -- */
    function mintFromSignature(
        string memory encodedTokenID,
        string memory encodedContract,
        string memory messageSuffix,
        bytes memory minterSignature
    ) external {
        bytes32 minterHash = keccak256(abi.encodePacked(
            "LIKE\n\n",
            "Token ID: ", encodedTokenID, "\n\n",
            "Contract: ", encodedContract, "\n\n",
            messageSuffix
        ));
        address minter = ECDSA.recover(minterHash, minterSignature);

        uint256 tokenID = StringParser._asciiBase10ToUint(encodedTokenID);
        address tokenContract = StringParser._asciiBase16ToAddress(encodedContract);

        string memory tokenURI = ERC721(tokenContract).tokenURI(tokenID);

        bytes32 tokenRef = _calculateTokenRef(tokenID, tokenContract);
        Token storage token = tokens[tokenRef];
        if (token.collection == _NULL_ADDRESS) {
            // Save on first like
            token.collection = tokenContract;
            token.id = tokenID;
            token.uri = tokenURI;
        }

        uint256 likeTokenID = _calculateTokenID(minter, tokenRef);
        tokenRefs[likeTokenID] = tokenRef;
        _mint(minter, likeTokenID);
    }


    function mint(
        uint256 tokenID,
        address tokenContract
    ) external {
        address minter = _msgSender();

        // URI lookup also ensures the referenced token still exists
        string memory tokenURI = ERC721(tokenContract).tokenURI(tokenID);

        bytes32 tokenRef = _calculateTokenRef(tokenID, tokenContract);
        Token storage token = tokens[tokenRef];
        if (token.collection == _NULL_ADDRESS) {
            // Save on first like
            token.collection = tokenContract;
            token.id = tokenID;
            token.uri = tokenURI;
        }

        uint256 likeTokenID = _calculateTokenID(minter, tokenRef);
        tokenRefs[likeTokenID] = tokenRef;
        _mint(minter, likeTokenID);
    }
    /* -- END minting APIs -- */

    /* -- BEGIN minting helpers -- */
    function _calculateTokenRef(
        uint256 tokenID,
        address collection
    ) internal pure returns (bytes32) {
        return keccak256(abi.encode(tokenID, collection));
    }

    // Generate tokenID from the hash of the creator and uri content.
    // We do this to enable tamper-resistant reminting.
    function _calculateTokenID(
        address minter,
        bytes32 tokenRef
    ) internal pure returns (uint256) {
        return uint256(keccak256(abi.encode(minter, tokenRef)));
    }
    /* -- END minting helpers -- */

    function isApprovedOrOwner(
        address spender,
        uint256 tokenID
    ) external view returns (bool) {
        return _isApprovedOrOwner(spender, tokenID);
    }

    function tokenURI(uint256 tokenID) public view override returns (string memory) {
        require(_exists(tokenID), "ERC721Metadata: URI query for nonexistent token");
        return tokens[tokenRefs[tokenID]].uri;
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
    function royaltyInfo(
        uint256 likeTokenID,
        uint256 salePrice
    ) external view override returns (address, uint256) {
        require(_exists(likeTokenID), "Token does not exist or has been burned");
        Token memory token = tokens[tokenRefs[likeTokenID]];
        return IERC2981(token.collection).royaltyInfo(token.id, salePrice);
    }
    /* -- END ERC2981 supporting methods */


    /* -- BEGIN IRelayRecipient overrides -- */
    function _msgSender() internal override(Context, BaseRelayRecipient) view returns (address payable) {
        return BaseRelayRecipient._msgSender();
    }

    string public override versionRecipient = "1";
    /* -- END IRelayRecipient overrides -- */
}
