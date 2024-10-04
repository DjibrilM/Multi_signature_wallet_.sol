# Multi-signature wallet

A smart contract-based multi-signature wallet that enhances security by requiring multiple signatures for transactions. The wallet ensures that a transaction is executed only when a predefined number of signatures are collected.

## Features
- **Multiple Owners:** Add multiple wallet owners who can sign transactions.
- **Threshold Signatures:** Define the minimum number of approvals required to execute a transaction.
- **Transaction Proposals:** Propose new transactions that can only be executed after the required approvals are met.
- **Immutable Transactions:** Once proposed, transactions cannot be canceled by any owner.

## Requirements
- Solidity ^0.8.0
- Node.js and npm installed
- Hardhat (for local development)
- Ethers.js (for interacting with the contract)
