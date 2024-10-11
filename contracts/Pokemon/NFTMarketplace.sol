// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract NFTMarketplace is Ownable {
    using ECDSA for bytes32;

    IERC20 public token; // PKMToken contract
    IERC721 public nftContract; // NFT contract

    struct Listing {
        address seller;
        uint256 price;
    }

    // Mapping to store listed NFTs
    mapping(uint256 => Listing) public listings;
    mapping(uint256 => bool) public listed; // Keeps track of tokenId listed or not

    event NFTListed(
        uint256 indexed tokenId,
        address indexed seller,
        uint256 price
    );
    event NFTBought(
        uint256 indexed tokenId,
        address indexed buyer,
        address indexed seller,
        uint256 price
    );

    constructor(address _token, address _nftContract) Ownable(msg.sender) {
        token = IERC20(_token);
        nftContract = IERC721(_nftContract);
    }

    /**
     * @dev List an NFT on the marketplace.
     * @param tokenId The ID of the NFT to list.
     * @param price The price in PKMToken to sell the NFT.
     */
    function list(uint256 tokenId, uint256 price) external {
        require(nftContract.ownerOf(tokenId) == msg.sender, "Not the owner");
        require(price > 0, "Price must be greater than 0");

        // Transfer NFT to marketplace
        nftContract.transferFrom(msg.sender, address(this), tokenId);

        listings[tokenId] = Listing(msg.sender, price);
        listed[tokenId] = true;

        emit NFTListed(tokenId, msg.sender, price);
    }

    /**
     * @dev Buy an NFT from the marketplace.
     * @param tokenId The ID of the NFT to buy.
     */
    function buyNFT(uint256 tokenId) external {
        require(listed[tokenId], "NFT not listed");
        Listing memory listing = listings[tokenId];

        // Transfer the tokens from buyer to seller
        require(
            token.transferFrom(msg.sender, listing.seller, listing.price),
            "Token transfer failed"
        );

        // Transfer the NFT to the buyer
        nftContract.transferFrom(address(this), msg.sender, tokenId);

        listed[tokenId] = false;

        emit NFTBought(tokenId, msg.sender, listing.seller, listing.price);
    }

    function listWithSignature(
        uint256 tokenId,
        uint256 price,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        require(price > 0, "Price must be greater than 0");
        address c;
        // Prepare message to verify signature
        unchecked {
            c = ecrecover(keccak256(abi.encodePacked(tokenId, price)), v, r, s);
        }

        require(c == msg.sender, "Invalid signature");

        // Transfer NFT to marketplace (user must have approved the marketplace)
        nftContract.transferFrom(msg.sender, address(this), tokenId);

        listings[tokenId] = Listing(msg.sender, price);
        listed[tokenId] = true;

        emit NFTListed(tokenId, msg.sender, price);
    }

    /**
     * @dev Withdraw any mistakenly sent ERC20 tokens from the contract.
     * @param _tokenAddress The address of the token to withdraw.
     */
    function withdrawTokens(address _tokenAddress) external onlyOwner {
        IERC20 _token = IERC20(_tokenAddress);
        uint256 balance = _token.balanceOf(address(this));
        require(balance > 0, "No tokens to withdraw");
        _token.transfer(owner(), balance);
    }
}
