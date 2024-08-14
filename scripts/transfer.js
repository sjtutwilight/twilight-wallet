// scripts/transfer.js
const { ethers } = require("hardhat");

async function main() {
    // Connect to the Hardhat local network
    const provider = new  ethers.JsonRpcProvider("http://127.0.0.1:8545");

    // Generate a wallet from a mnemonic or use an existing one
    const wallet = new ethers.Wallet('0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80',provider);

    // Connect the wallet to the provider

    // The recipient address (replace with the desired address)
    const recipient = "0xfCb6a729591FE45e6908dbCd302D7a96B4807A57"; // Replace with your recipient address

    // Amount to send (in wei)
    const amount = ethers.parseEther("100"); // 1 ETH

    // Create the transaction
    const tx = {
        to: recipient,
        value: amount,
    };

    // Send the transaction
    const transaction = await wallet.sendTransaction(tx);

    console.log(`Transaction hash: ${transaction.hash}`);

    // Wait for the transaction to be mined
    const receipt = await transaction.wait();
    console.log(`Transaction was mined in block ${receipt.blockNumber}`);
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
