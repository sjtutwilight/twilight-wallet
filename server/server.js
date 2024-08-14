// server/server.js
const express = require('express');
const { KafkaClient, Producer, Consumer } = require('kafka-node');
const { Client } = require('pg');
const { ethers } = require('ethers');
const cors = require('cors');

const app = express();
const port = 3000;
app.use(cors()); // Allow all origins by default

app.use(express.json());

// PostgreSQL client setup
const pgClient = new Client({
    connectionString: process.env.DATABASE_URL,
});

pgClient.connect();

// Kafka client setup
const kafkaClient = new KafkaClient({ kafkaHost: 'kafka:9092' });
const producer = new Producer(kafkaClient);

// Listen to Ethereum blocks and send transactions to Kafka
const provider = new ethers.providers.JsonRpcProvider("http://127.0.0.1:8545");
const consumer = new Consumer(
    kafkaClient,
    [{ topic: 'transactions', partition: 0 }],
    { autoCommit: true }
);
provider.on('block', async (blockNumber) => {
    const block = await provider.getBlockWithTransactions(blockNumber);
    block.transactions.forEach((tx) => {
        const transaction = {
            txHash: tx.hash,
            from: tx.from,
            to: tx.to,
            value: ethers.utils.formatEther(tx.value),
            blockNumber: tx.blockNumber,
            timestamp: block.timestamp,
        };

        const payloads = [
            {
                topic: 'transactions',
                messages: JSON.stringify(transaction),
            },
        ];

        producer.send(payloads, (err, data) => {
            if (err) {
                console.error('Error sending transaction to Kafka:', err);
            } else {
                console.log('Transaction sent to Kafka:', data);
            }
        });
    });
});

consumer.on('error', (err) => {
    console.error('Error in Kafka consumer:', err);
});

// Kafka consumer that listens to the transactions topic and stores messages in PostgreSQL


consumer.on('message', async (message) => {
    const transaction = JSON.parse(message.value);

    const query = `
        INSERT INTO transactions (tx_hash, from_address, to_address, value, block_number, timestamp)
        VALUES ($1, $2, $3, $4, $5, $6)
    `;
    const values = [
        transaction.txHash,
        transaction.from,
        transaction.to,
        transaction.value,
        transaction.blockNumber,
        new Date(transaction.timestamp * 1000), // Convert Unix timestamp to JS Date
    ];

    try {
        await pgClient.query(query, values);
        console.log(`Transaction ${transaction.txHash} inserted into the database`);
    } catch (error) {
        console.error('Failed to insert transaction:', error);
    }
});

// API to fetch transactions from PostgreSQL
app.get('/api/transactions', async (req, res) => {
    const { address, fromBlock, toBlock } = req.query;

    let query = 'SELECT * FROM transactions WHERE 1=1';
    const values = [];
    let paramIndex = 1; // Initialize the index for placeholders

    if (address) {
        query += ` AND (from_address = $${paramIndex} OR to_address = $${paramIndex})`;
        values.push(address);
        paramIndex++;
    }
    if (fromBlock) {
        query += ` AND block_number >= $${paramIndex}`;
        values.push(parseInt(fromBlock));
        paramIndex++;
    }
    if (toBlock) {
        query += ` AND block_number <= $${paramIndex}`;
        values.push(parseInt(toBlock));
    }

    console.log('Generated SQL:', query);
    console.log('Query Values:', values);

    try {
        const result = await pgClient.query(query, values);
        res.json(result.rows);
    } catch (error) {
        console.error('Error fetching transactions:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});


app.listen(port, () => {
    console.log(`Server running on http://localhost:${port}`);
});
