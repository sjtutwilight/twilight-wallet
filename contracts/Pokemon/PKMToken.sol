// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
contract PKMToken is ERC20, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    constructor(uint256 initialSupply) ERC20("Pokemon Token", "PKM") {
        _mint(msg.sender, initialSupply);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }
    // Grant minter role to a specified account
    function grantMinterRole(address account) external {
        _grantRole(MINTER_ROLE, account);
    }
}
