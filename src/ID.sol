// SPDX-License-Identifier: MIT
// https://github.com/OpenZeppelin/openzeppelin-contracts/commit/8e0296096449d9b1cd7c5631e917330635244c37
import "openzeppelin-solidity/contracts/cryptography/ECDSA.sol";
import "openzeppelin-solidity/contracts/utils/Strings.sol";
import "./NoSpam721.sol";
import "./IERC2981.sol";
import "./BaseRelayRecipient.sol";
import "./StringParser.sol";

pragma experimental ABIEncoderV2;
pragma solidity 0.6.12;

contract ID is NoSpam721, BaseRelayRecipient, IERC2981 {

    string private constant BATCH_ERROR_INVALID_INPUTS = "Batch method parameters must not have varying lengths";

    struct Royalty {
        address owner;
        uint16 rate;
        bool set;
    }

    mapping(uint256 => Royalty) royalties;

    uint256 private constant _MAX_ROYALTY_100_00 = 10000;
    address private constant _NULL_ADDRESS = 0x0000000000000000000000000000000000000000;
    address private constant _TRUSTED_FORWARDER = 0x86C80a8aa58e0A4fa09A69624c31Ab2a6CAD56b8;
    bytes4 private constant _INTERFACE_ID_ERC2981 = 0x2a55205a;

    constructor() public ERC721("ID", "ID") {
        _registerInterface(_INTERFACE_ID_ERC2981);
        _setTrustedForwarder(_TRUSTED_FORWARDER);
    }

    /* -- BEGIN minting APIs -- */
    function mintFromSignature(
        string memory messageMemo,
        string memory messageRoyaltyRateInteger,
        string memory messageRoyaltyRateDecimal,
        string memory messageRoyaltyOwner,
        string memory messageTokenURI,
        bytes memory minterSignature
    ) external {
        string memory message = string(abi.encodePacked(
            messageMemo,
            "\n\n-------",
            "\n\nRoyalty Rate\n", messageRoyaltyRateInteger, ".", messageRoyaltyRateDecimal, "%",
            "\n\nRoyalty Owner\n", messageRoyaltyOwner,
            "\n\nToken Metadata\n", messageTokenURI
        ));
        bytes32 minterHash = keccak256(abi.encodePacked(
            "\x19Ethereum Signed Message:\n",
            Strings.toString(bytes(message).length),
            message
        ));
        address minter = ECDSA.recover(minterHash, minterSignature);
        uint256 tokenID = _calculateTokenID(minter, messageTokenURI);
        uint256 royaltyRateInteger = StringParser._asciiBase10ToUint(messageRoyaltyRateInteger);
        uint256 royaltyRateDecimal = StringParser._asciiBase10ToUint(messageRoyaltyRateDecimal);
        address royaltyOwner = StringParser._asciiBase16ToAddress(messageRoyaltyOwner);

        _mint(minter, tokenID);
        _setTokenURI(tokenID, messageTokenURI);
        _setTokenRoyalty(tokenID, royaltyOwner, royaltyRateInteger, royaltyRateDecimal);
    }

    function mint(
        uint256 royaltyRateInteger,
        uint256 royaltyRateDecimal,
        address royaltyOwner,
        string memory tokenURI
    ) external {
        address minter = _msgSender();
        uint256 tokenID = _calculateTokenID(minter, tokenURI);

        _mint(minter, tokenID);
        _setTokenURI(tokenID, tokenURI);
        _setTokenRoyalty(tokenID, royaltyOwner, royaltyRateInteger, royaltyRateDecimal);
    }

    // Generate deterministic tokenID for reorg-resistant composability.
    function _calculateTokenID(
        address minter,
        string memory tokenURI
    ) internal pure returns (uint256) {
        return uint256(keccak256(abi.encode(minter, tokenURI))) & 0xFFFFFFFFFFFFFFFF;
    }
    /* -- END minting APIs -- */

    /* -- BEGIN ERC2981 supporting methods */
    function _setTokenRoyalty(
        uint256 tokenID,
        address owner,
        uint256 rateInteger,
        uint256 rateDecimal
    ) internal {
        require(royalties[tokenID].set == false, "Cannot remint token");
        require(rateDecimal <= 99, "Royalty rate decimal must be between 0-99");
        require(
            (rateInteger <= 99 && rateDecimal <= 99) ||
            (rateInteger == 100 && rateDecimal == 0),
            "Royalty rate must be under 100.00"
        );
        uint16 rate = (uint16(rateInteger) * 100) + uint16(rateDecimal);

        royalties[tokenID] = Royalty({
            owner: owner,
            rate: rate,
            set: true
        });
    }

    function royaltyInfo(
        uint256 tokenID,
        uint256 salePrice
    ) external view override returns (address, uint256) {
        Royalty storage royalty = royalties[tokenID];
        return (royalty.owner, salePrice * uint256(royalty.rate) / _MAX_ROYALTY_100_00);
    }

    // Allow the royalty owner of a token to change ownership
    function changeTokenRoyaltyOwner(uint256 tokenID, address newOwner) external {
        Royalty storage royalty = royalties[tokenID];
        require(royalty.owner == _msgSender(), "Not royalty owner");
        royalty.owner = newOwner;
    }
    /* -- END ERC2981 supporting methods */

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
        require(tos.length == tokenIDs.length, BATCH_ERROR_INVALID_INPUTS);
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
            BATCH_ERROR_INVALID_INPUTS
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
            BATCH_ERROR_INVALID_INPUTS
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
            BATCH_ERROR_INVALID_INPUTS
        );
        for (uint256 i = 0; i < froms.length; ++i) {
            safeTransferFrom(froms[i], tos[i], tokenIDs[i], datas[i]);
        }
    }

    function isApprovedOrOwnerBatch(
        address[] memory spenders,
        uint256[] memory tokenIDs
    ) external view returns (bool[] memory) {
        require(spenders.length == tokenIDs.length, BATCH_ERROR_INVALID_INPUTS);
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

    /* -- BEGIN IRelayRecipient overrides -- */
    function _msgSender() internal override(Context, BaseRelayRecipient) view returns (address payable) {
        return BaseRelayRecipient._msgSender();
    }

    string public override versionRecipient = "1";
    /* -- END IRelayRecipient overrides -- */
}
