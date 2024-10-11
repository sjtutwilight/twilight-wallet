// Staking.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Staking is Ownable {
    IERC20 public pkmToken;
    uint256 public rewardRate = 1; // 1% daily reward rate

    struct Stake {
        uint256 amount;
        uint256 lastStakedTime;
    }

    mapping(address => Stake) public stakes;

    constructor(address _pkmToken) Ownable(msg.sender) {
        pkmToken = IERC20(_pkmToken);
    }

    function stake(uint256 amount) external {
        require(amount > 0, "Cannot stake 0");
        pkmToken.transferFrom(msg.sender, address(this), amount);

        Stake storage userStake = stakes[msg.sender];
        userStake.amount += amount;
        userStake.lastStakedTime = block.timestamp;
    }

    function withdraw() external {
        Stake storage userStake = stakes[msg.sender];
        require(userStake.amount > 0, "No tokens staked");

        uint256 reward = calculateReward(msg.sender);
        uint256 totalAmount = userStake.amount + reward;

        userStake.amount = 0; // Reset stake
        pkmToken.transfer(msg.sender, totalAmount);
    }

    function calculateReward(address staker) public view returns (uint256) {
        Stake storage userStake = stakes[staker];
        uint256 stakedDuration = block.timestamp - userStake.lastStakedTime;
        uint256 reward = (userStake.amount * rewardRate * stakedDuration) /
            100 /
            1 days;
        return reward;
    }
}
