// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;
contract RockPaperScissors {
    enum Choice {
        None,
        Rock,
        Paper,
        Scissors
    }
    enum GameStatus {
        Created,
        Joined,
        Revealed,
        Finished
    }

    struct Game {
        address payable banker;
        address payable player;
        uint256 stake;
        bytes32 bankerChoiceHash;
        Choice bankerChoice;
        Choice playerChoice;
        GameStatus status;
        address payable winner;
    }

    mapping(uint256 => Game) public games;
    uint256 public gameCounter;

    event GameCreated(uint256 gameId, address banker, uint256 stake);
    event GameJoined(uint256 gameId, address player);
    event ChoiceRevealed(uint256 gameId, address banker, Choice choice);
    event GameFinished(uint256 gameId, address winner, uint256 amount);

    modifier onlyBanker(uint256 gameId) {
        require(
            msg.sender == games[gameId].banker,
            "Only banker can call this"
        );
        _;
    }

    modifier onlyPlayer(uint256 gameId) {
        require(
            msg.sender == games[gameId].player,
            "Only player can call this"
        );
        _;
    }

    function createGame(bytes32 choiceHash) external payable {
        require(msg.value > 0, "Stake must be greater than zero");

        gameCounter++;
        games[gameCounter] = Game({
            banker: payable(msg.sender),
            player: payable(address(0)),
            stake: msg.value,
            bankerChoiceHash: choiceHash,
            bankerChoice: Choice.None,
            playerChoice: Choice.None,
            status: GameStatus.Created,
            winner: payable(address(0))
        });

        emit GameCreated(gameCounter, msg.sender, msg.value);
    }

    function joinGame(uint256 gameId, Choice playerChoice) external payable {
        Game storage game = games[gameId];
        require(game.status == GameStatus.Created, "Game is not available");
        require(msg.value == game.stake, "Stake amount must match");
        require(
            playerChoice == Choice.Rock ||
                playerChoice == Choice.Paper ||
                playerChoice == Choice.Scissors,
            "Invalid choice"
        );

        game.player = payable(msg.sender);
        game.playerChoice = playerChoice;
        game.status = GameStatus.Joined;

        emit GameJoined(gameId, msg.sender);
    }

    function revealChoice(
        uint256 gameId,
        Choice bankerChoice,
        string memory secret
    ) external onlyBanker(gameId) {
        Game storage game = games[gameId];
        require(
            game.status == GameStatus.Joined,
            "Game is not ready for reveal"
        );
        require(
            keccak256(abi.encodePacked(uint8(bankerChoice), secret)) ==
                game.bankerChoiceHash,
            "Invalid reveal"
        );

        game.bankerChoice = bankerChoice;
        game.status = GameStatus.Revealed;

        emit ChoiceRevealed(gameId, msg.sender, bankerChoice);

        finishGame(gameId);
    }

    function finishGame(uint256 gameId) internal {
        Game storage game = games[gameId];
        require(
            game.status == GameStatus.Revealed,
            "Game is not ready to finish"
        );

        address payable winner;
        if (game.bankerChoice == game.playerChoice) {
            // It's a draw, both get their stakes back
            game.banker.transfer(game.stake);
            game.player.transfer(game.stake);
        } else if (
            (game.bankerChoice == Choice.Rock &&
                game.playerChoice == Choice.Scissors) ||
            (game.bankerChoice == Choice.Scissors &&
                game.playerChoice == Choice.Paper) ||
            (game.bankerChoice == Choice.Paper &&
                game.playerChoice == Choice.Rock)
        ) {
            // Banker wins
            game.winner = game.banker;
        } else {
            // Player wins
            game.winner = game.player;
        }

        game.status = GameStatus.Finished;
    }
    function withdrawFunds(uint256 gameId) external {
        Game storage game = games[gameId];
        require(game.winner != address(0), "Game is not concluded yet");
        require(msg.sender == game.winner, "Only winner can withdraw funds");
        uint256 reward = game.stake * 2;
        game.stake = 0; // Prevent re-entrancy
        payable(game.winner).transfer(reward);
    }

    function getActiveGames() external view returns (Game[] memory) {
        uint256 activeGameCount;
        for (uint256 i = 1; i <= gameCounter; i++) {
            if (games[i].winner == address(0)) {
                activeGameCount++;
            }
        }

        Game[] memory activeGames = new Game[](activeGameCount);
        uint256 index;
        for (uint256 i = 1; i <= gameCounter; i++) {
            if (games[i].winner == address(0)) {
                activeGames[index] = games[i];
                index++;
            }
        }

        return activeGames;
    }
}
