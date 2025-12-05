# Complete Deployment Guide

This guide provides step-by-step instructions for compiling Quorlin contracts and deploying them to Ethereum, Solana, and Polkadot.

## 🎉 Live Deployments

Quorlin has successfully achieved **Write-Once, Deploy-Everywhere** with live deployments across all three major blockchain ecosystems:

| Platform | Status | Network | Details |
|----------|--------|---------|---------|
| **EVM** | ✅ DEPLOYED | Local Hardhat + Testnets | First deployment (Dec 2024) |
| **Solana** | ✅ DEPLOYED | DevNet | Program ID: `m3BqeaAW3JKJK32PnTV9PKjHA3XHpinfaWopwvdXmJz` |
| **Polkadot** | ✅ DEPLOYED | Local Substrate Node | Contract: `5Cmg5TKsLBoeTbU4MkSJekwG6LQ5nt2My98p411sQvJb2eYs` |

**See detailed deployment documentation:**
- [EVM Deployment Guide](../docs/Deployment-EVM.md)
- [Solana Deployment Guide](../docs/Deployment-Solana.md)
- [Polkadot Deployment Guide](../docs/Deployment-Polkadot.md)
- [Deployment Record](../DEPLOYMENT_RECORD.md) - Complete deployment history

---

## Part 1: Building the Quorlin Compiler

### Prerequisites

- Rust 1.70+ (`rustup` recommended)
- Git
- Basic terminal/command line knowledge

### Step 1: Clone the Repository

```bash
git clone https://github.com/yourusername/quorlin-lang.git
cd quorlin-lang
```

### Step 2: Build the Compiler

```bash
# Build in release mode (optimized)
cargo build --release

# The compiler binary will be at: ./target/release/qlc
```

**Expected Output:**
```
Compiling quorlin-lexer v0.1.0
Compiling quorlin-parser v0.1.0
...
Finished `release` profile [optimized] target(s) in ~20s
```

### Step 3: Verify Installation

```bash
./target/release/qlc --version
```

**Expected:** `qlc 0.1.0`

---

## Part 2: Compiling Quorlin Contracts

### Example Contract: Token

The `examples/token.ql` file contains a complete ERC-20 compatible token that works on all three platforms.

### Compile to EVM (Ethereum)

```bash
./target/release/qlc compile examples/token.ql --target evm -o token.yul
```

**Output:** `token.yul` (4,710 bytes of Yul code)

### Compile to Solana

```bash
./target/release/qlc compile examples/token.ql --target solana -o token.rs
```

**Output:** `token.rs` (4,968 bytes of Anchor Rust code)

### Compile to Polkadot

```bash
./target/release/qlc compile examples/token.ql --target ink -o token.rs
```

**Output:** `token.rs` (4,448 bytes of ink! Rust code)

---

## Part 3: Deploying to Ethereum (EVM)

### Prerequisites

- Solidity compiler (`solc`) version 0.8.0+
- Node.js and npm
- Hardhat or Foundry (deployment framework)
- MetaMask or other Web3 wallet

### Step 1: Compile Yul to Bytecode

```bash
# Install solc if not already installed
npm install -g solc

# Compile Yul to bytecode
solc --strict-assembly token.yul --bin --optimize -o build/
```

This generates `token.bin` containing the bytecode.

### Step 2: Set Up Deployment Environment

#### Using Hardhat

```bash
# Create new Hardhat project
npm init -y
npm install --save-dev hardhat

# Initialize Hardhat
npx hardhat

# Create deployment script (deploy.js)
```

**deploy.js:**
```javascript
const hre = require("hardhat");

async function main() {
  const fs = require('fs');
  const bytecode = '0x' + fs.readFileSync('build/token.bin', 'utf8');

  const Token = await hre.ethers.getContractFactory([], bytecode);
  const token = await Token.deploy();

  await token.deployed();
  console.log("Token deployed to:", token.address);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
```

### Step 3: Deploy to Network

```bash
# Deploy to local network
npx hardhat run scripts/deploy.js --network localhost

# Deploy to testnet (e.g., Sepolia)
npx hardhat run scripts/deploy.js --network sepolia

# Deploy to mainnet
npx hardhat run scripts/deploy.js --network mainnet
```

### Step 4: Verify Deployment

```javascript
// Verify the contract is deployed
const tokenAddress = "0x..."; // Address from deployment
const token = await ethers.getContractAt("Token", tokenAddress);

// Check token name
const name = await token.name();
console.log("Token name:", name); // Should output: "Quorlin Token"
```

---

## Part 4: Deploying to Solana

### Prerequisites

- Solana CLI tools
- Anchor framework (version 0.28.0+)
- Solana wallet with SOL for fees
- Rust toolchain for Solana (BPF target)

### Step 1: Install Solana Tools

```bash
# Install Solana CLI
sh -c "$(curl -sSfL https://release.solana.com/stable/install)"

# Add to PATH
export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"

# Verify installation
solana --version
```

### Step 2: Install Anchor

```bash
# Install Anchor CLI
cargo install --git https://github.com/coral-xyz/anchor avm --locked --force
avm install latest
avm use latest

# Verify installation
anchor --version
```

### Step 3: Create Anchor Project

```bash
# Create new Anchor project
anchor init token_program
cd token_program

# Copy generated Rust code
cp ../token.rs programs/token_program/src/lib.rs
```

### Step 4: Configure Anchor.toml

```toml
[programs.localnet]
token_program = "Fg6PaFpoGXkYsidMpWTK6W2BeZ7FEfcYkg476zPFsLnS"

[provider]
cluster = "devnet"  # or "mainnet-beta"
wallet = "~/.config/solana/id.json"
```

### Step 5: Build the Program

```bash
# Build the Solana program
anchor build

# This creates: target/deploy/token_program.so
```

### Step 6: Deploy to Solana

```bash
# Set cluster
solana config set --url devnet  # or mainnet-beta

# Airdrop SOL for testing (devnet only)
solana airdrop 2

# Deploy the program
anchor deploy

# Output will show: Program Id: Fg6PaFpoGXkYsidMpWTK6W2BeZ7FEfcYkg476zPFsLnS
```

### Step 7: Interact with Program

**JavaScript client:**
```javascript
const anchor = require("@coral-xyz/anchor");

async function main() {
  const provider = anchor.AnchorProvider.env();
  anchor.setProvider(provider);

  const program = anchor.workspace.TokenProgram;

  // Initialize token
  await program.methods
    .initialize(new anchor.BN(1000000))
    .accounts({
      contract: contractKeypair.publicKey,
      signer: provider.wallet.publicKey,
      systemProgram: anchor.web3.SystemProgram.programId,
    })
    .signers([contractKeypair])
    .rpc();

  console.log("Token initialized!");
}

main();
```

---

## Part 5: Deploying to Polkadot (ink!)

### Prerequisites

- Rust with `wasm32-unknown-unknown` target
- `cargo-contract` CLI tool
- Substrate node or Polkadot parachain
- Polkadot.js wallet

### Step 1: Install Dependencies

```bash
# Install wasm32 target
rustup target add wasm32-unknown-unknown

# Install cargo-contract
cargo install cargo-contract --force
rustup component add rust-src

# Verify installation
cargo contract --version
```

### Step 2: Create ink! Project

```bash
# Create new ink! contract project
cargo contract new token_contract
cd token_contract

# Copy generated ink! code
cp ../token.rs lib.rs
```

### Step 3: Update Cargo.toml

```toml
[package]
name = "token_contract"
version = "0.1.0"
edition = "2021"

[dependencies]
ink = { version = "4.3", default-features = false }

[lib]
name = "token_contract"
path = "lib.rs"
crate-type = ["cdylib"]

[features]
default = ["std"]
std = [
    "ink/std",
]
ink-as-dependency = []
```

### Step 4: Build the Contract

```bash
# Build the contract
cargo contract build --release

# This creates:
# - target/ink/token_contract.wasm (Wasm binary)
# - target/ink/token_contract.json (Metadata)
# - target/ink/token_contract.contract (Bundle)
```

### Step 5: Deploy Using Polkadot.js

#### Option A: Using Polkadot.js UI

1. Go to https://polkadot.js.org/apps
2. Connect to your network (local node, testnet, or mainnet)
3. Navigate to Developer → Contracts
4. Click "Upload & deploy code"
5. Upload `token_contract.contract`
6. Set constructor parameters (initial_supply)
7. Click "Deploy"
8. Sign transaction

#### Option B: Using cargo-contract CLI

```bash
# Connect to local node
cargo contract instantiate \
  --constructor new \
  --args 1000000 \
  --suri //Alice \
  --skip-confirm

# Deploy to testnet (e.g., Contracts on Rococo)
cargo contract instantiate \
  --url wss://rococo-contracts-rpc.polkadot.io \
  --constructor new \
  --args 1000000 \
  --suri "YOUR_SEED_PHRASE" \
  --skip-confirm
```

### Step 6: Interact with Contract

**Using Polkadot.js:**
```javascript
const { ApiPromise, WsProvider } = require('@polkadot/api');
const { ContractPromise } = require('@polkadot/api-contract');

async function main() {
  const wsProvider = new WsProvider('ws://127.0.0.1:9944');
  const api = await ApiPromise.create({ provider: wsProvider });

  const metadata = require('./target/ink/token_contract.json');
  const contract = new ContractPromise(api, metadata, contractAddress);

  // Call transfer function
  const { gasRequired, result } = await contract.query.transfer(
    aliceAddress,
    { value: 0, gasLimit: -1 },
    bobAddress,
    100
  );

  console.log('Transfer result:', result.toHuman());
}

main();
```

---

## Part 6: Platform-Specific Considerations

### Ethereum/EVM

**Gas Optimization:**
- Yul code is already optimized
- Use `solc --optimize` flag for further optimization
- Test gas costs on testnets first

**Networks:**
- Localhost: `npx hardhat node`
- Testnet: Sepolia, Goerli, Mumbai
- Mainnet: Ethereum, Polygon, BSC, Arbitrum

**Costs:**
- Deployment: ~500,000-1,000,000 gas
- At 20 gwei: ~$20-40 USD

### Solana

**Rent Considerations:**
- Accounts require rent (SOL deposit)
- Size affects cost
- Use `anchor build` size optimization

**Networks:**
- Localnet: `solana-test-validator`
- Devnet: Free SOL from faucet
- Mainnet-beta: Real SOL required

**Costs:**
- Deployment: ~5-10 SOL (~$100-200)
- Transactions: <0.001 SOL (<$0.20)

### Polkadot/ink!

**Storage Deposits:**
- Storage requires deposit
- Refundable when storage freed
- Calculate before deployment

**Networks:**
- Local: `substrate-contracts-node`
- Testnet: Contracts on Rococo
- Mainnet: Astar, Phala, Aleph Zero

**Costs:**
- Deployment: 1-5 DOT (~$5-25)
- Transactions: 0.01-0.1 DOT (~$0.05-0.50)

---

## Part 7: Testing Before Deployment

### Local Testing (All Platforms)

```bash
# Ethereum - Run local Hardhat node
npx hardhat node

# Solana - Run local validator
solana-test-validator

# Polkadot - Run local substrate node
substrate-contracts-node --dev
```

### Integration Testing

Create test scripts for each platform:

**Ethereum (Hardhat):**
```javascript
const { expect } = require("chai");

describe("Token", function () {
  it("Should transfer tokens", async function () {
    const Token = await ethers.getContractFactory("Token");
    const token = await Token.deploy(1000000);
    await token.deployed();

    await token.transfer(addr1.address, 100);
    expect(await token.balanceOf(addr1.address)).to.equal(100);
  });
});
```

**Solana (Anchor):**
```javascript
describe("token_program", () => {
  it("Transfers tokens", async () => {
    await program.methods
      .transfer(recipient, new anchor.BN(100))
      .rpc();

    const balance = await program.methods
      .balanceOf(recipient)
      .view();

    assert.equal(balance.toNumber(), 100);
  });
});
```

**Polkadot (ink!):**
```rust
#[ink::test]
fn transfer_works() {
    let mut token = Token::new(1000);
    assert_eq!(token.transfer(bob(), 100), Ok(true));
    assert_eq!(token.balance_of(bob()), 100);
}
```

---

## Part 8: Deployment Checklist

### Pre-Deployment

- [ ] Code compiled successfully for target platform
- [ ] All tests passing
- [ ] Security audit completed (for production)
- [ ] Gas/cost estimates calculated
- [ ] Wallet funded with native tokens
- [ ] Network configuration verified

### Deployment

- [ ] Deploy to testnet first
- [ ] Verify contract functionality
- [ ] Test all functions
- [ ] Monitor for errors
- [ ] Document contract address

### Post-Deployment

- [ ] Verify contract on block explorer
- [ ] Update frontend with contract address
- [ ] Monitor contract activity
- [ ] Set up event listeners
- [ ] Document deployment details

---

## Part 9: Verification and Monitoring

### Ethereum

**Verify on Etherscan:**
```bash
npx hardhat verify --network mainnet CONTRACT_ADDRESS
```

**Monitor:**
- Etherscan: https://etherscan.io
- Tenderly: https://tenderly.co
- Blocknative: https://blocknative.com

### Solana

**Verify on Solana Explorer:**
- Mainnet: https://explorer.solana.com
- Devnet: https://explorer.solana.com?cluster=devnet

**Monitor:**
```bash
solana logs PROGRAM_ID
```

### Polkadot

**Verify on Subscan:**
- https://polkadot.subscan.io
- https://astar.subscan.io

**Monitor:**
```bash
cargo contract info --contract CONTRACT_ADDRESS
```

---

## Part 10: Common Issues and Solutions

### Issue: "Out of gas" (Ethereum)

**Solution:**
```javascript
// Increase gas limit
const tx = await token.transfer(to, amount, { gasLimit: 300000 });
```

### Issue: "Insufficient SOL" (Solana)

**Solution:**
```bash
# Check balance
solana balance

# Airdrop (devnet only)
solana airdrop 2

# Transfer from another wallet
solana transfer RECIPIENT AMOUNT
```

### Issue: "Storage deposit required" (Polkadot)

**Solution:**
```javascript
// Set deposit value when deploying
const deposit = api.consts.contracts.depositPerByte.toNumber() * codeSize;
```

---

## Summary

You now have a complete guide to:
1. ✅ Build the Quorlin compiler
2. ✅ Compile contracts to all three platforms
3. ✅ Deploy to Ethereum/EVM chains
4. ✅ Deploy to Solana
5. ✅ Deploy to Polkadot parachains
6. ✅ Test and verify deployments
7. ✅ Monitor and maintain contracts

**One codebase. Three blockchains. Full deployment capability!** 🚀

---

*For more details, see the Documentations folder*
