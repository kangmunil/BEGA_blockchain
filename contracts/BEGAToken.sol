// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title BEGAToken
 * @dev BEGA Token for use as native gas token on BEGA L2
 *
 * CRITICAL: This token MUST have 18 decimals for compatibility with EVM gas calculations
 *
 * Deploy this to Ethereum Sepolia testnet (or mainnet for production)
 * The deployed address will be used in deploy-config.json as customGasTokenAddress
 */
contract BEGAToken is ERC20, Ownable {
    /**
     * @dev Constructor that mints initial supply to deployer
     * @param initialSupply Total supply to mint (in whole tokens, will be multiplied by 10^18)
     *
     * Example: BEGAToken(1000000) will create 1,000,000 BEGA tokens
     */
    constructor(uint256 initialSupply) ERC20("BEGA", "BEGA") Ownable(msg.sender) {
        // Mint initial supply to contract deployer
        // initialSupply is in whole tokens, automatically gets 18 decimals
        _mint(msg.sender, initialSupply * 10 ** decimals());
    }

    /**
     * @dev Function to mint additional tokens (only owner can call)
     * @param to Address to receive the minted tokens
     * @param amount Amount to mint (in whole tokens)
     */
    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount * 10 ** decimals());
    }

    /**
     * @dev Burns tokens from caller's balance
     * @param amount Amount to burn (in whole tokens)
     */
    function burn(uint256 amount) public {
        _burn(msg.sender, amount * 10 ** decimals());
    }
}
