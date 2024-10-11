// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Nonces.sol";

contract NFTManager is ERC721, Ownable, Nonces {
    using ECDSA for bytes32;

    struct Pokemon {
        string name;
        uint256 level;
        string trait;
        string imageURL; // IPFS URL for the image
    }

    uint256 private _tokenIdCounter;
    mapping(uint256 => Pokemon) public pokemons;
    mapping(bytes32 => bool) public usedNonces;

    IERC20 public pkmToken;

    event NFTCreated(
        uint256 indexed tokenId,
        address indexed creator,
        string name
    );
    event NFTPurchased(
        uint256 indexed tokenId,
        address indexed buyer,
        address indexed seller,
        uint256 price
    );

    constructor(
        address _pkmToken
    ) ERC721("Pokemon", "PKMN") Ownable(msg.sender) {
        pkmToken = IERC20(_pkmToken);
    }

    function createPokemon(
        string memory name,
        string memory trait,
        string memory imageURL
    ) external onlyOwner {
        uint256 tokenId = _tokenIdCounter;
        pokemons[tokenId] = Pokemon(name, 1, trait, imageURL); // Initial level is 1
        _mint(msg.sender, tokenId);
        _tokenIdCounter++;

        emit NFTCreated(tokenId, msg.sender, name);
    }

    function buyNFTWithSignature(
        uint256 tokenId,
        uint256 price,
        address seller,
        address buyer,
        bytes memory signature
    ) external {
        require(ownerOf(tokenId) == seller, "Seller is not the owner");

        // Recreate the message hash with buyer and nonce
        bytes32 messageHash = keccak256(
            abi.encodePacked(tokenId, price, seller, buyer, _useNonce(seller))
        );
        // require(
        //     messageHash.toEthSignedMessageHash().recover(signature) == seller,
        //     "Invalid signature"
        // );

        require(pkmToken.transferFrom(buyer, seller, price), "Payment failed");

        _transfer(seller, buyer, tokenId);

        emit NFTPurchased(tokenId, buyer, seller, price);
    }

    function setTokenContract(address _pkmToken) external onlyOwner {
        pkmToken = IERC20(_pkmToken);
    }
}
