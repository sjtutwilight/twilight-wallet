// server.js
const express = require('express');
const bodyParser = require('body-parser');
const { Kafka } = require('kafkajs');
const { ethers } = require('ethers');
const { Pool } = require('pg');

const app = express();
app.use(bodyParser.json());

const pool = new Pool({
  user: 'user',
  host: 'localhost',
  database: 'nftdb',
  password: 'password',
  port: 5432,
});

const kafka = new Kafka({
  clientId: 'nft-marketplace',
  brokers: ['localhost:9092'],
});

const producer = kafka.producer();
const consumer = kafka.consumer({ groupId: 'nft-group' });

async function initKafka() {
  await producer.connect();
  await consumer.connect();
}

const provider = new ethers.providers.JsonRpcProvider('http://localhost:8545');
const nftManagerAddress = 'NFT_CONTRACT_ADDRESS';
const nftManagerAbi = require('./NftManagerABI.json');
const nftManager = new ethers.Contract(nftManagerAddress, nftManagerAbi, provider);

app.get('/api/nfts', async (req, res) => {
  try {
    const nfts = await pool.query('SELECT * FROM nfts');
    res.json(nfts.rows);
  } catch (error) {
    console.error('Error fetching NFTs:', error);
    res.status(500).json({ error: 'Internal Server Error' });
  }
});

app.post('/api/generate-signature', async (req, res) => {
  const { tokenId, price, buyer } = req.body;
  const seller = await nftManager.ownerOf(tokenId);
  const nonce = ethers.utils.randomBytes(32);

  try {
    const signature = await nftManager.generateSignature(tokenId, price, buyer, nonce);
    res.json({ signature, nonce });
  } catch (error) {
    console.error('Error generating signature:', error);
    res.status(500).json({ error: 'Internal Server Error' });
  }
});

app.post('/api/buy', async (req, res) => {
  const { tokenId, price, seller, signature, nonce } = req.body;
  const buyer = await provider.getSigner().getAddress();

  try {
    const tx = await nftManager.buyNFTWithSignature(tokenId, price, seller, buyer, nonce, signature);
    await tx.wait();

    res.json({ success: true, txHash: tx.hash });

    await producer.send({
      topic: 'nft-transactions',
      messages: [{ value: JSON.stringify({ type: 'transfer', tokenId, buyer }) }],
    });
  } catch (error) {
    console.error('Error buying NFT:', error);
    res.status(500).json({ error: 'Internal Server Error' });
  }
});

async function consumeKafkaMessages() {
  await consumer.subscribe({ topic: 'nft-transactions', fromBeginning: true });

  await consumer.run({
    eachMessage: async ({ topic, partition, message }) => {
      const event = JSON.parse(message.value.toString());

      if (event.type === 'transfer') {
        const { tokenId, buyer } = event;

        await pool.query(
          'UPDATE nfts SET owner = $1 WHERE token_id = $2',
          [buyer, tokenId]
        );
      } else if (event.type === 'create') {
        const { tokenId, name, level, trait, imageURL, owner } = event;

        await pool.query(
          'INSERT INTO nfts (token_id, name, level, trait, image_url, owner) VALUES ($1, $2, $3, $4, $5, $6)',
          [tokenId, name, level, trait, imageURL, owner]
        );
      }
    },
  });
}

app.listen(4000, async () => {
  console.log('Server running on port 4000');
  await initKafka();
  consumeKafkaMessages();
});
