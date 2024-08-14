# Twilight-wallet
This project is a continuously developed HD (Hierarchical Deterministic) wallet that provides various functionalities, from managing cryptocurrencies to interacting with decentralized applications (DApps) like Uniswap and a custom RockPaperScissors game.

**Features**
**1. Signup**
Mnemonic Generation: A mnemonic is generated from a seed upon user signup.
Keystore File: A keystore file is created and stored in the browser's local storage to facilitate password-based logins.

**2. Login**
Wallet Reconstruction: During login, the user’s wallet object list is recreated from the derived paths.

**3. Top Bar**
Wallet Connection: Supports connecting to an internal wallet or MetaMask.
Network Support: Compatible with local Hardhat nodes, the Sepolia testnet, and Ethereum mainnet.
Multiple Accounts: Enables the creation of multiple accounts on the same chain.

**4. Dashboard**
Account Management: Displays selected account information.
Token Management: Allows users to add and manage tokens.
Transactions: Supports transferring funds and displays the transaction history of the account.
**5. Uniswap Integration**
SDK: Integrates the Uniswap V3 SDK to facilitate interactions with the Uniswap protocol.

**6. SimpleGame - RockPaperScissors**
Game Mechanics: Bankers can create games by staking an ETH amount along with a secret value to secure the banker’s choice, preventing it from being observed in the memory pool before the result is revealed.
Player Interaction: Players can join the game by staking the same amount of ETH through the game list.
Deployment: The game is currently deployed on the Sepolia testnet but not on the mainnet.

**7. Backend**
Technologies Used: Utilizes Node.js, Kafka, and PostgreSQL.
Functionality: Listens to on-chain information and stores it in PostgreSQL.
Considerations: The current implementation is simplistic and does not account for issues such as block rollbacks.
![461723640721_ pic](https://github.com/user-attachments/assets/1e55745b-01cd-4882-8d98-3e7934058858)
![471723640721_ pic](https://github.com/user-attachments/assets/24a13757-c4e7-4b27-ac60-e044f04bd63f)
