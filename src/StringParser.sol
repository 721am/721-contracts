// SPDX-License-Identifier: MIT
import "openzeppelin-solidity/contracts/math/SafeMath.sol";

pragma solidity 0.6.12;

library StringParser {
	using SafeMath for uint256;

	function _asciiBase16ToAddress(
        string memory ascii
    ) internal pure returns (address) {
        uint256 result = 0;
        bytes memory asciiBytes = bytes(ascii);
        require(asciiBytes.length == 42, "Invalid Address");
        for (uint i = 2; i < asciiBytes.length; i++) {
            uint256 char = uint256(uint8(asciiBytes[i]));
            if (char >= 48 && char <= 57) {
                char -= 48; // 0-9
            }
            else if (char >= 65 && char <= 70) {
                char -= 55; // A-F
            }
            else if (char >= 97 && char <= 102) {
                char -= 87; // a-f
            }
            else {
                revert("Invalid address");
            }
            result = result.mul(16).add(char);
        }
        return address(result);
    }

    function _asciiBase10ToUint(
        string memory ascii
    ) internal pure returns (uint256) {
        uint256 result = 0;
        bytes memory asciiBytes = bytes(ascii);
        for (uint i = 0; i < asciiBytes.length; i++) {
            uint256 digit = uint256(uint8(asciiBytes[i])) - 48;
            require(digit >= 0 && digit <= 9, "Token id not formatted correctly");
            result = result.mul(10).add(digit);
        }
        return result;
    }
}
