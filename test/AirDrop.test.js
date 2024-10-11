const { expect } = require("chai");
const { ethers } = require("hardhat");
const { MerkleTree } = require("merkletreejs");
const keccak256 = require("keccak256");

describe("AirDrop", function () {
  let AirDrop, airDrop;
  let PKMToken, token;
  let owner, addr1, addr2, addr3;
  let merkleTree, rootHash;

  before(async function () {
    [owner, addr1, addr2, addr3] = await ethers.getSigners();

    // Deploy PKMToken contract
    // PKMToken = await ethers.getContractFactory("PKMToken");
    // token = await PKMToken.deploy(100);
    // await token.deployed();
    const token=await hre.ethers.deployContract("PKMToken",[100]);
    // Create Merkle tree
    const leaves = [addr1.address, addr2.address, addr3.address].map((addr) =>
      keccak256(ethers.AbiCoder.defaultAbiCoder.encode(["address"], [addr]))
    );
    merkleTree = new MerkleTree(leaves, keccak256, { sortPairs: true });
    rootHash = merkleTree.getHexRoot();

    // Deploy AirDrop contract
    AirDrop = await ethers.getContractFactory("AirDrop");
    airDrop = await AirDrop.deploy(token.address, rootHash);
    await airDrop.deployed();

    // Transfer ownership of token to AirDrop contract
    await token.transferOwnership(airDrop.address);
  });

  describe("claim", function () {
    it("should allow eligible addresses to claim tokens", async function () {
      const leaf = keccak256(ethers.utils.defaultAbiCoder.encode(["address"], [addr1.address]));
      const proof = merkleTree.getHexProof(leaf);

      // Claim tokens
      await expect(airDrop.connect(addr1).claim(proof, addr1.address))
        .to.emit(airDrop, "Claimed")
        .withArgs(addr1.address, ethers.utils.parseEther("1"));

      const balance = await token.balanceOf(addr1.address);
      expect(balance).to.equal(ethers.utils.parseEther("1"));
    });

    it("should not allow double claiming", async function () {
      const leaf = keccak256(ethers.utils.defaultAbiCoder.encode(["address"], [addr1.address]));
      const proof = merkleTree.getHexProof(leaf);

      // Attempt to claim again
      await expect(airDrop.connect(addr1).claim(proof, addr1.address)).to.be.revertedWith("already claimed");
    });

    it("should reject invalid merkle proofs", async function () {
      const leaf = keccak256(ethers.utils.defaultAbiCoder.encode(["address"], [addr2.address]));
      const invalidProof = []; // Invalid proof

      await expect(airDrop.connect(addr2).claim(invalidProof, addr2.address)).to.be.revertedWith("invalid merkle proof");
    });

    it("should not allow non-eligible addresses to claim tokens", async function () {
      const leaf = keccak256(ethers.utils.defaultAbiCoder.encode(["address"], [owner.address]));
      const proof = merkleTree.getHexProof(leaf);

      await expect(airDrop.connect(owner).claim(proof, owner.address)).to.be.revertedWith("invalid merkle proof");
    });
  });
});
