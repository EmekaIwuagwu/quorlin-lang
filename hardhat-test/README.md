# Quorlin Token - Hardhat Deployment

This directory contains scripts to deploy and interact with Quorlin-compiled smart contracts on Hardhat.

## Setup

The dependencies are already installed. If you need to reinstall:

```bash
npm install
```

## Quick Start

### 1. Start Hardhat Node (Terminal 1)

Open a terminal and start a local Hardhat node:

```cmd
npx hardhat node
```

Keep this running. You'll see:
- 20 test accounts with 10,000 ETH each
- The node listening on http://127.0.0.1:8545

### 2. Deploy the Token Contract (Terminal 2)

In a **new terminal**, deploy the Quorlin token:

```cmd
npx hardhat run scripts/deploy-token.js --network localhost
```

This will:
- Deploy the token contract with 1,000,000 initial supply
- Print the contract address (save this!)
- Verify the deployment

**Example output:**
```
╔════════════════════════════════════════════════════════════╗
║           🚀 Deploying Quorlin Token Contract 🚀          ║
╚════════════════════════════════════════════════════════════╝

  📦 Contract address: 0x5FbDB2315678afecb367f032d93F642f64180aa3
  ⛽ Gas used: 156789
```

### 3. Interact with the Token

Use the interaction script to test all token functions:

```cmd
npx hardhat run scripts/interact-token.js --network localhost 0x5FbDB2315678afecb367f032d93F642f64180aa3
```

Replace `0x5FbDB2315678afecb367f032d93F642f64180aa3` with your actual contract address.

This will demonstrate:
1. ✅ Reading total supply
2. ✅ Checking balances
3. ✅ Transferring tokens
4. ✅ Approving spenders
5. ✅ Checking allowances
6. ✅ Transferring from approved accounts

## Contract Functions

The deployed Quorlin token supports:

- `transfer(to, amount)` - Transfer tokens to another address
- `approve(spender, amount)` - Approve spender to use your tokens
- `transfer_from(from, to, amount)` - Transfer tokens on behalf of someone
- `balance_of(owner)` - Get token balance of an address
- `allowance(owner, spender)` - Get approved allowance
- `get_total_supply()` - Get total token supply

## Network Configuration

The Hardhat network is configured with:
- Chain ID: 1337
- Block time: Instant (for testing)
- Optimizer: Enabled
- Solidity version: 0.8.27

## Troubleshooting

**Error: "Cannot connect to localhost:8545"**
- Make sure `npx hardhat node` is running in another terminal

**Error: "Invalid contract address"**
- Copy the exact contract address from the deployment output
- Make sure to use it in the interact script

**Error: "Transaction reverted"**
- Check that you have sufficient balance
- Ensure addresses are not zero addresses
- Verify allowances for transfer_from

## Files

- `hardhat.config.js` - Hardhat configuration
- `scripts/deploy-token.js` - Deploy Quorlin token bytecode
- `scripts/interact-token.js` - Interact with deployed token
- `README.md` - This file

## Next Steps

After successfully testing locally:

1. **Compile to different targets**: Try compiling to Solana or Polkadot
2. **Deploy to testnet**: Configure Sepolia or Goerli in hardhat.config.js
3. **Add more contracts**: Compile other `.ql` examples and deploy them
4. **Build a frontend**: Use ethers.js to interact from a web UI

Enjoy your Quorlin smart contracts! 🚀
