// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {PKMToken} from "./PKMToken.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract AirDrop {
    event Claimed(address to, uint256 amount);
    PKMToken public immutable token;
    bytes32 public immutable root;
    mapping(bytes32 => bool) public claimed;
    constructor(address _token, bytes32 _root) {
        token = PKMToken(_token);
        root = _root;
    }

    function claim(bytes32[] memory proof, address to) external returns (bool) {
        bytes32 leaf = keccak256(abi.encode(to));
        require(!claimed[leaf], "already claimed");
        require(MerkleProof.verify(proof, root, leaf), "invalid merkle proof");

        token.mint(to, 10);
        emit Claimed(to, 10);
        return true;
    }
}
