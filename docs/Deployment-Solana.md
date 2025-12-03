# Deploying Quorlin Contracts to Solana

This guide walks you through deploying Quorlin smart contracts to Solana DevNet and MainNet using the Anchor framework.

## 📋 Prerequisites

### Required Software

1. **Rust** (1.70+)
   ```bash
   # Install Rust
   curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

   # Verify
   rustc --version
   cargo --version
   ```

2. **Solana CLI** (1.17+)
   ```bash
   # Linux/Mac
   sh -c "$(curl -sSfL https://release.solana.com/stable/install)"

   # Windows (PowerShell)
   cmd /c "curl https://release.solana.com/stable/solana-install-init-x86_64-pc-windows-msvc.exe --output C:\solana-install-tmp\solana-install-init.exe --create-dirs"

   # Verify
   solana --version
   ```

3. **Anchor Framework** (0.29+)
   ```bash
   # Install Anchor Version Manager (avm)
   cargo install --git https://github.com/coral-xyz/anchor avm --locked --force

   # Install Anchor
   avm install latest
   avm use latest

   # Verify
   anchor --version
   ```

4. **Node.js** (16+) - For testing
   ```bash
   # Verify
   node --version
   npm --version
   ```

---

## 📁 Project Structure

```
quorlin-lang/
├── anchor-test/                    # Anchor project for Solana
│   ├── Anchor.toml                # Anchor configuration
│   ├── Cargo.toml                 # Workspace manifest
│   ├── programs/
│   │   └── quorlin-token/         # Your Solana program
│   │       ├── Cargo.toml
│   │       └── src/
│   │           └── lib.rs         # Program code (generated)
│   └── scripts/
│       ├── deploy.sh              # Deployment script
│       └── compile-and-deploy.sh  # Full pipeline
├── examples/
│   └── token.ql                   # Your Quorlin contract
└── target/release/
    └── qlc                        # Quorlin compiler
```

---

## 🚀 Quick Start: Automated Deployment

The fastest way to deploy to Solana DevNet:

```bash
# From anchor-test directory
cd anchor-test

# Run the full pipeline
./scripts/compile-and-deploy.sh
```

This script automatically:
1. ✅ Compiles Quorlin → Anchor/Rust
2. ✅ Builds the Solana program
3. ✅ Deploys to DevNet
4. ✅ Returns program ID and explorer link

---

## 📝 Step-by-Step Deployment

### Step 1: Configure Solana Wallet

```bash
# Create a new keypair (if you don't have one)
solana-keygen new --outfile ~/.config/solana/id.json

# Check your address
solana address

# Check balance
solana balance
```

**Output:**
```
5Yj3kDvF2qwLPAYdhG7xC3cN8qKJRq9Xm4xU7pL2VxKz
0 SOL
```

---

### Step 2: Get DevNet SOL

```bash
# Request airdrop (DevNet only)
solana airdrop 2

# Verify balance
solana balance
```

**Output:**
```
2 SOL
```

**Note:** If airdrop fails due to rate limiting, use the [Solana Faucet](https://faucet.solana.com/).

---

### Step 3: Configure Network

```bash
# Set to DevNet
solana config set --url https://api.devnet.solana.com

# Verify
solana config get
```

**Output:**
```
Config File: /home/user/.config/solana/cli/config.yml
RPC URL: https://api.devnet.solana.com
WebSocket URL: wss://api.devnet.solana.com/ (computed)
Keypair Path: /home/user/.config/solana/id.json
Commitment: confirmed
```

---

### Step 4: Compile Quorlin → Anchor/Rust

```bash
# From project root
./target/release/qlc compile examples/token.ql --target solana --output anchor-test/programs/quorlin-token/src/lib.rs
```

**Output:**
```
╔════════════════════════════════════════════════════════════╗
║                  🚀 QUORLIN COMPILER 🚀                   ║
╚════════════════════════════════════════════════════════════╝

  📄 Source: examples/token.ql
  🎯 Target: solana

  ✨ COMPILATION SUCCESSFUL ✨

  📦 Output: anchor-test/programs/quorlin-token/src/lib.rs
```

**Verify:** Check that `lib.rs` contains:
- `use anchor_lang::prelude::*;`
- `#[program]` module
- Account structures
- Instruction handlers

---

### Step 5: Build Solana Program

```bash
cd anchor-test

# Build the program
anchor build
```

This compiles the Rust code to Solana BPF bytecode.

**Output:**
```
Compiling quorlin-token v0.1.0
Finished release [optimized] target(s) in 45.2s
```

**Files created:**
- `target/deploy/quorlin_token.so` - Program binary
- `target/deploy/quorlin_token-keypair.json` - Program keypair
- `target/idl/quorlin_token.json` - Interface Definition Language

---

### Step 6: Deploy to DevNet

```bash
# Deploy
anchor deploy --provider.cluster devnet
```

**Output:**
```
Deploying workspace: https://api.devnet.solana.com
Upgrade authority: 5Yj3kDvF2qwLPAYdhG7xC3cN8qKJRq9Xm4xU7pL2VxKz
Deploying program "quorlin_token"...
Program path: target/deploy/quorlin_token.so...
Program Id: Fg6PaFpoGXkYsidMpWTK6W2BeZ7FEfcYkg476zPFsLnS

Deploy success
```

---

### Step 7: Verify Deployment

```bash
# Get your program ID
solana address -k target/deploy/quorlin_token-keypair.json

# Check program account
solana program show <PROGRAM_ID> --url devnet
```

**Explorer Link:**
```
https://explorer.solana.com/address/<PROGRAM_ID>?cluster=devnet
```

---

## 🧪 Testing Your Deployment

### Option 1: Using Anchor Test Framework

```bash
# From anchor-test directory
anchor test --skip-local-validator
```

This runs tests against DevNet.

### Option 2: Manual Interaction

Create a client script to interact with your program:

```typescript
// tests/token.ts
import * as anchor from "@coral-xyz/anchor";
import { Program } from "@coral-xyz/anchor";
import { QuorlinToken } from "../target/types/quorlin_token";

describe("quorlin-token", () => {
  const provider = anchor.AnchorProvider.env();
  anchor.setProvider(provider);

  const program = anchor.workspace.QuorlinToken as Program<QuorlinToken>;

  it("Initialize token", async () => {
    const contract = anchor.web3.Keypair.generate();

    const tx = await program.methods
      .initialize(new anchor.BN(1_000_000))
      .accounts({
        contract: contract.publicKey,
        signer: provider.wallet.publicKey,
        systemProgram: anchor.web3.SystemProgram.programId,
      })
      .signers([contract])
      .rpc();

    console.log("Transaction signature:", tx);
  });
});
```

Run tests:
```bash
anchor test
```

---

## 🌐 Deploying to MainNet

**⚠️ WARNING:** MainNet deployment costs real SOL. Ensure your code is thoroughly tested!

### Step 1: Switch to MainNet

```bash
solana config set --url https://api.mainnet-beta.solana.com
```

### Step 2: Fund Your Wallet

Transfer SOL to your wallet address. You'll need:
- ~0.5-2 SOL for program deployment (depending on program size)
- Additional SOL for rent exemption

### Step 3: Deploy

```bash
anchor deploy --provider.cluster mainnet
```

### Step 4: Verify

```bash
solana program show <PROGRAM_ID> --url mainnet-beta
```

**Explorer Link:**
```
https://explorer.solana.com/address/<PROGRAM_ID>
```

---

## 🔧 Troubleshooting

### Error: "Insufficient funds"

**Problem:** Not enough SOL in your wallet.

**Solution:**
```bash
# DevNet: Request airdrop
solana airdrop 2

# MainNet: Transfer SOL to your wallet
solana balance
```

---

### Error: "Program account does not exist"

**Problem:** Deployment failed or program was closed.

**Solution:**
```bash
# Redeploy
anchor build
anchor deploy --provider.cluster devnet
```

---

### Error: "Anchor version mismatch"

**Problem:** Local Anchor version doesn't match program dependency.

**Solution:**
```bash
# Check versions
anchor --version
cat anchor-test/programs/quorlin-token/Cargo.toml | grep anchor-lang

# Update Anchor
avm install 0.29.0
avm use 0.29.0

# Rebuild
anchor build
```

---

### Error: "Failed to send transaction"

**Problem:** Network congestion or RPC issues.

**Solution:**
```bash
# Try a different RPC endpoint
solana config set --url https://solana-devnet.g.alchemy.com/v2/YOUR_API_KEY

# Or use GenesysGo
solana config set --url https://devnet.genesysgo.net/
```

---

### Error: "Program ID mismatch"

**Problem:** `declare_id!()` in code doesn't match deployed program ID.

**Solution:**
1. Get your program ID:
   ```bash
   solana address -k target/deploy/quorlin_token-keypair.json
   ```

2. Update `lib.rs`:
   ```rust
   declare_id!("YourActualProgramIDHere");
   ```

3. Update `Anchor.toml`:
   ```toml
   [programs.devnet]
   quorlin_token = "YourActualProgramIDHere"
   ```

4. Rebuild and redeploy:
   ```bash
   anchor build
   anchor deploy --provider.cluster devnet
   ```

---

## 📊 Cost Estimation

| Operation | DevNet Cost | MainNet Cost (Approx) |
|-----------|-------------|------------------------|
| Program Deployment | FREE | 0.5-2 SOL |
| Account Rent Exemption | FREE | 0.001-0.01 SOL |
| Transaction Fee | FREE | 0.000005 SOL |
| Account Creation | FREE | 0.001 SOL |

**Total for MainNet:** ~0.5-2.1 SOL depending on program size

---

## 🔐 Security Checklist

Before deploying to MainNet:

- [ ] Audit all access controls
- [ ] Test all edge cases
- [ ] Verify arithmetic operations don't overflow
- [ ] Check account validation in all instructions
- [ ] Test with different wallet providers
- [ ] Review PDA (Program Derived Address) logic
- [ ] Ensure proper error handling
- [ ] Test upgrade/migration path
- [ ] Document security assumptions
- [ ] Consider a professional audit for high-value contracts

---

## 📚 Additional Resources

- [Solana Documentation](https://docs.solana.com/)
- [Anchor Book](https://book.anchor-lang.com/)
- [Solana Cookbook](https://solanacookbook.com/)
- [Solana Stack Exchange](https://solana.stackexchange.com/)
- [Anchor Examples](https://github.com/coral-xyz/anchor/tree/master/examples)

---

## 🆘 Getting Help

If you encounter issues:

1. Check the [Quorlin GitHub Issues](https://github.com/your-org/quorlin-lang/issues)
2. Ask in [Solana Discord](https://discord.gg/solana)
3. Post on [Solana Stack Exchange](https://solana.stackexchange.com/)

---

## 📝 Quick Reference Commands

```bash
# Configuration
solana config get                                    # View current config
solana config set --url <RPC_URL>                   # Change network
solana-keygen new                                    # Create new wallet

# Wallet Management
solana address                                       # Show wallet address
solana balance                                       # Check balance
solana airdrop 2                                     # Get DevNet SOL

# Building & Deploying
anchor build                                         # Build program
anchor deploy --provider.cluster devnet              # Deploy to DevNet
anchor deploy --provider.cluster mainnet             # Deploy to MainNet

# Program Management
solana program show <PROGRAM_ID>                     # Show program info
solana program close <PROGRAM_ID>                    # Close program (reclaim SOL)

# Testing
anchor test                                          # Run tests (local)
anchor test --skip-local-validator                   # Run tests (DevNet)

# Full Pipeline
./scripts/compile-and-deploy.sh                      # Quorlin → Deploy
```

---

## ✅ Success Criteria

Your deployment is successful when:

1. ✅ `anchor deploy` completes without errors
2. ✅ You receive a Program ID
3. ✅ Program appears on Solana Explorer
4. ✅ `solana program show <PROGRAM_ID>` returns program info
5. ✅ Anchor tests pass against deployed program

**Example successful output:**
```
╔════════════════════════════════════════════════════════════╗
║              ✨ DEPLOYMENT SUCCESSFUL ✨                  ║
╚════════════════════════════════════════════════════════════╝

  📦 Program ID: Fg6PaFpoGXkYsidMpWTK6W2BeZ7FEfcYkg476zPFsLnS
  🌐 Network: devnet
  💰 Wallet: 5Yj3kDvF2qwLPAYdhG7xC3cN8qKJRq9Xm4xU7pL2VxKz

  🔗 Explorer:
     https://explorer.solana.com/address/Fg6PaFpoGXkYsidMpWTK6W2BeZ7FEfcYkg476zPFsLnS?cluster=devnet
```

---

**Happy Deploying! 🚀**
