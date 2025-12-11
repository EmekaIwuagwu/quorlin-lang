# 🚀 Quorlin Test Network Deployment Guide

**Complete guide for deploying Quorlin contracts to all supported test networks**

---

## 📋 Table of Contents

1. [Prerequisites](#prerequisites)
2. [Digital Ocean Setup](#digital-ocean-setup)
3. [EVM Test Networks (Ethereum, Polygon, BSC)](#evm-test-networks)
4. [Solana Devnet](#solana-devnet)
5. [Polkadot Test Networks](#polkadot-test-networks)
6. [Aptos Testnet](#aptos-testnet)
7. [Automated Deployment](#automated-deployment)

---

## Prerequisites

### Required Tools

```bash
# Node.js and npm
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# Rust and Cargo
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source $HOME/.cargo/env

# Solana CLI
sh -c "$(curl -sSfL https://release.solana.com/stable/install)"

# Anchor (Solana)
cargo install --git https://github.com/coral-xyz/anchor avm --locked --force
avm install latest
avm use latest

# ink! CLI (Polkadot)
cargo install cargo-contract --force

# Aptos CLI
curl -fsSL "https://aptos.dev/scripts/install_cli.py" | python3

# Foundry (EVM)
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

---

## Digital Ocean Setup

### 1. Create Droplet

```bash
# Create Ubuntu 22.04 droplet (minimum 4GB RAM, 2 vCPUs)
# Choose datacenter region closest to you
# Add SSH key for access
```

### 2. Initial Server Setup

```bash
# SSH into server
ssh root@your_droplet_ip

# Update system
apt update && apt upgrade -y

# Create non-root user
adduser quorlin
usermod -aG sudo quorlin
su - quorlin

# Install basic tools
sudo apt install -y build-essential git curl wget vim
```

### 3. Install Desktop Environment (Optional)

```bash
# Install XFCE desktop
sudo apt install -y xfce4 xfce4-goodies

# Install VNC server
sudo apt install -y tightvncserver

# Start VNC server
vncserver

# Set password when prompted

# Configure VNC
vncserver -kill :1
nano ~/.vnc/xstartup

# Add this content:
#!/bin/bash
xrdb $HOME/.Xresources
startxfce4 &

# Make executable
chmod +x ~/.vnc/xstartup

# Restart VNC
vncserver -geometry 1920x1080 -depth 24
```

### 4. SSH Tunnel for VNC

```bash
# On your local machine (Windows)
# Using PuTTY or PowerShell:
ssh -L 5901:localhost:5901 quorlin@your_droplet_ip

# Then connect VNC viewer to: localhost:5901
```

---

## EVM Test Networks

### 1. Setup Hardhat Project

```bash
# Create project directory
mkdir quorlin-evm-deploy
cd quorlin-evm-deploy

# Initialize npm project
npm init -y

# Install dependencies
npm install --save-dev hardhat @nomicfoundation/hardhat-toolbox
npm install dotenv

# Initialize Hardhat
npx hardhat init
# Choose "Create a JavaScript project"
```

### 2. Configure Networks

Create `.env`:
```bash
PRIVATE_KEY=your_private_key_here
ETHERSCAN_API_KEY=your_etherscan_api_key
POLYGONSCAN_API_KEY=your_polygonscan_api_key
```

Edit `hardhat.config.js`:
```javascript
require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();

module.exports = {
  solidity: "0.8.19",
  networks: {
    // Ethereum Sepolia
    sepolia: {
      url: "https://rpc.sepolia.org",
      accounts: [process.env.PRIVATE_KEY],
      chainId: 11155111
    },
    
    // Polygon Mumbai
    mumbai: {
      url: "https://rpc-mumbai.maticvigil.com",
      accounts: [process.env.PRIVATE_KEY],
      chainId: 80001
    },
    
    // BSC Testnet
    bscTestnet: {
      url: "https://data-seed-prebsc-1-s1.binance.org:8545",
      accounts: [process.env.PRIVATE_KEY],
      chainId: 97
    }
  },
  etherscan: {
    apiKey: {
      sepolia: process.env.ETHERSCAN_API_KEY,
      polygonMumbai: process.env.POLYGONSCAN_API_KEY
    }
  }
};
```

### 3. Compile Quorlin to Yul

```bash
# Compile Quorlin contract
qlc compile examples/simple_counter.ql --target evm --optimize 3 -o counter.yul

# Convert Yul to Solidity (for Hardhat)
# Create contracts/Counter.sol with Yul assembly
```

### 4. Deploy Script

Create `scripts/deploy.js`:
```javascript
const hre = require("hardhat");

async function main() {
  console.log("Deploying Counter contract...");
  
  const Counter = await hre.ethers.getContractFactory("Counter");
  const counter = await Counter.deploy();
  
  await counter.deployed();
  
  console.log(`Counter deployed to: ${counter.address}`);
  
  // Verify on Etherscan
  if (hre.network.name !== "hardhat") {
    console.log("Waiting for block confirmations...");
    await counter.deployTransaction.wait(6);
    
    await hre.run("verify:verify", {
      address: counter.address,
      constructorArguments: [],
    });
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
```

### 5. Deploy

```bash
# Get testnet ETH from faucets:
# Sepolia: https://sepoliafaucet.com/
# Mumbai: https://faucet.polygon.technology/
# BSC: https://testnet.binance.org/faucet-smart

# Deploy to Sepolia
npx hardhat run scripts/deploy.js --network sepolia

# Deploy to Mumbai
npx hardhat run scripts/deploy.js --network mumbai

# Deploy to BSC Testnet
npx hardhat run scripts/deploy.js --network bscTestnet
```

---

## Solana Devnet

### 1. Setup Anchor Project

```bash
# Create project
anchor init quorlin-solana-deploy
cd quorlin-solana-deploy

# Configure for devnet
solana config set --url https://api.devnet.solana.com

# Create wallet
solana-keygen new --outfile ~/.config/solana/id.json

# Get airdrop
solana airdrop 2
```

### 2. Compile Quorlin to Anchor

```bash
# Compile Quorlin contract
qlc compile examples/simple_counter.ql --target solana --optimize 3 -o programs/quorlin-solana-deploy/src/lib.rs

# Update Anchor.toml with your program ID
anchor keys list
```

### 3. Build and Deploy

```bash
# Build
anchor build

# Deploy
anchor deploy

# Get program ID
anchor keys list

# Test
anchor test --skip-local-validator
```

### 4. Interact with Contract

Create `tests/counter.ts`:
```typescript
import * as anchor from "@coral-xyz/anchor";
import { Program } from "@coral-xyz/anchor";
import { QuorlinSolanaDeploy } from "../target/types/quorlin_solana_deploy";

describe("counter", () => {
  const provider = anchor.AnchorProvider.env();
  anchor.setProvider(provider);

  const program = anchor.workspace.QuorlinSolanaDeploy as Program<QuorlinSolanaDeploy>;

  it("Initializes counter", async () => {
    const tx = await program.methods.initialize().rpc();
    console.log("Transaction signature", tx);
  });

  it("Increments counter", async () => {
    const tx = await program.methods.increment().rpc();
    console.log("Transaction signature", tx);
  });
});
```

---

## Polkadot Test Networks

### 1. Setup ink! Project

```bash
# Create project
cargo contract new quorlin-ink-deploy
cd quorlin-ink-deploy

# Compile Quorlin to ink!
qlc compile examples/simple_counter.ql --target ink --optimize 3 -o lib.rs

# Copy to src/
cp lib.rs src/lib.rs
```

### 2. Build Contract

```bash
# Build
cargo contract build --release

# This creates:
# - target/ink/quorlin_ink_deploy.contract (deployable)
# - target/ink/quorlin_ink_deploy.wasm
# - target/ink/metadata.json
```

### 3. Deploy to Contracts UI

```bash
# Option 1: Use Contracts UI
# Visit: https://contracts-ui.substrate.io/
# Connect to: Contracts (Rococo)
# Upload & Deploy: target/ink/quorlin_ink_deploy.contract

# Option 2: Use cargo-contract
cargo contract instantiate \
  --constructor new \
  --args 0 \
  --suri //Alice \
  --url wss://rococo-contracts-rpc.polkadot.io
```

### 4. Interact

```bash
# Call function
cargo contract call \
  --contract <CONTRACT_ADDRESS> \
  --message increment \
  --suri //Alice \
  --url wss://rococo-contracts-rpc.polkadot.io

# Query state
cargo contract call \
  --contract <CONTRACT_ADDRESS> \
  --message get_count \
  --suri //Alice \
  --url wss://rococo-contracts-rpc.polkadot.io \
  --dry-run
```

---

## Aptos Testnet

### 1. Setup Aptos Project

```bash
# Initialize Aptos account
aptos init --network testnet

# This creates .aptos/config.yaml with your account

# Fund account
# Visit: https://aptoslabs.com/testnet-faucet
# Or use CLI:
aptos account fund-with-faucet --account default
```

### 2. Create Move Project

```bash
# Create project
mkdir quorlin-aptos-deploy
cd quorlin-aptos-deploy

# Create Move.toml
cat > Move.toml << EOF
[package]
name = "QuorlinContract"
version = "1.0.0"

[addresses]
quorlin = "_"

[dependencies.AptosFramework]
git = "https://github.com/aptos-labs/aptos-core.git"
rev = "main"
subdir = "aptos-move/framework/aptos-framework"
EOF

# Create sources directory
mkdir -p sources
```

### 3. Compile Quorlin to Move

```bash
# Compile
qlc compile examples/simple_counter.ql --target move --optimize 3 -o sources/counter.move
```

### 4. Deploy

```bash
# Compile Move
aptos move compile

# Test
aptos move test

# Publish
aptos move publish --named-addresses quorlin=default

# This will output the module address
```

### 5. Interact

```bash
# Call initialize function
aptos move run \
  --function-id 'default::contract::initialize' \
  --args u64:0

# Call increment
aptos move run \
  --function-id 'default::contract::increment'

# View resources
aptos account list --account default
```

---

## Automated Deployment

### Multi-Chain Deploy Script

Create `scripts/deploy-all.sh`:
```bash
#!/bin/bash

echo "🚀 Quorlin Multi-Chain Deployment"
echo "=================================="
echo ""

# Compile contracts
echo "📦 Compiling contracts..."
qlc compile examples/simple_counter.ql --target evm --optimize 3 -o output/counter.yul
qlc compile examples/simple_counter.ql --target solana --optimize 3 -o output/counter_solana.rs
qlc compile examples/simple_counter.ql --target ink --optimize 3 -o output/counter_ink.rs
qlc compile examples/simple_counter.ql --target move --optimize 3 -o output/counter.move

echo "✓ Compilation complete"
echo ""

# Deploy to EVM
echo "🔷 Deploying to Ethereum Sepolia..."
cd evm-deploy
npx hardhat run scripts/deploy.js --network sepolia
cd ..

# Deploy to Solana
echo "🟣 Deploying to Solana Devnet..."
cd solana-deploy
anchor deploy
cd ..

# Deploy to Polkadot
echo "🔴 Deploying to Polkadot Rococo..."
cd ink-deploy
cargo contract instantiate --constructor new --suri //Alice
cd ..

# Deploy to Aptos
echo "🟢 Deploying to Aptos Testnet..."
cd aptos-deploy
aptos move publish --named-addresses quorlin=default
cd ..

echo ""
echo "✅ All deployments complete!"
```

Make executable:
```bash
chmod +x scripts/deploy-all.sh
./scripts/deploy-all.sh
```

---

## 🔧 Troubleshooting

### Common Issues

**1. "Insufficient funds"**
```bash
# Get testnet tokens from faucets
# Ethereum Sepolia: https://sepoliafaucet.com/
# Polygon Mumbai: https://faucet.polygon.technology/
# Solana: solana airdrop 2
# Aptos: aptos account fund-with-faucet --account default
```

**2. "RPC connection failed"**
```bash
# Use alternative RPC endpoints
# Check network status pages
# Increase timeout in config
```

**3. "Contract verification failed"**
```bash
# Wait for more block confirmations
# Check API key is correct
# Ensure contract source matches deployed bytecode
```

---

## 📊 Deployment Checklist

- [ ] Install all required tools
- [ ] Setup Digital Ocean droplet (optional)
- [ ] Configure VNC for remote desktop (optional)
- [ ] Get testnet funds for all chains
- [ ] Compile contracts for all targets
- [ ] Deploy to Ethereum Sepolia
- [ ] Deploy to Polygon Mumbai
- [ ] Deploy to Solana Devnet
- [ ] Deploy to Polkadot Rococo
- [ ] Deploy to Aptos Testnet
- [ ] Verify all deployments
- [ ] Test contract interactions
- [ ] Document contract addresses

---

## 📝 Contract Addresses Template

Save your deployed addresses:

```markdown
# Deployed Contracts

## Simple Counter

### Ethereum Sepolia
- Address: 0x...
- Explorer: https://sepolia.etherscan.io/address/0x...

### Polygon Mumbai
- Address: 0x...
- Explorer: https://mumbai.polygonscan.com/address/0x...

### Solana Devnet
- Program ID: ...
- Explorer: https://explorer.solana.com/address/...?cluster=devnet

### Polkadot Rococo
- Contract: ...
- Explorer: https://rococo.subscan.io/account/...

### Aptos Testnet
- Module: 0x...::contract
- Explorer: https://explorer.aptoslabs.com/account/0x...?network=testnet
```

---

## 🎯 Next Steps

1. **Monitor Deployments**: Use block explorers to verify transactions
2. **Test Interactions**: Call functions and verify state changes
3. **Performance Testing**: Measure gas costs and execution time
4. **Security Audit**: Review generated code for vulnerabilities
5. **Documentation**: Document deployment process and contract interfaces

---

**Last Updated**: 2025-12-11  
**Quorlin Version**: 1.0.0  
**Status**: Production Ready
