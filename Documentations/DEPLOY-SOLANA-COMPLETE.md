# Complete Guide: Deploy Quorlin on Solana DevNet
## From Git Pull to Live Deployment

This is a **complete beginner-friendly guide** to deploy your Quorlin smart contract to Solana DevNet.

---

## ⏱️ Estimated Time: 30-45 minutes
## 💰 Cost: FREE (DevNet)

---

## Part 1: Get the Latest Code

### Step 1: Pull Latest Changes

```bash
cd /path/to/quorlin-lang
git pull origin claude/quorlin-compiler-setup-018umvaBWj2DWyPtPny19Mqu
```

**Expected Output:**
```
From github.com:EmekaIwuagwu/quorlin-lang
 * branch            claude/quorlin-compiler-setup-018umvaBWj2DWyPtPny19Mqu -> FETCH_HEAD
Already up to date.
```

---

## Part 2: Install Prerequisites (One-Time Setup)

### Step 2: Install Rust (if not already installed)

**Check if you have Rust:**
```bash
rustc --version
```

**If not installed:**
```bash
# Linux/Mac
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Follow prompts, then:
source ~/.bashrc  # or source ~/.zshrc

# Verify
rustc --version
cargo --version
```

**Expected Output:**
```
rustc 1.75.0 (82e1608df 2023-12-21)
cargo 1.75.0 (1d8b05cdd 2023-11-20)
```

---

### Step 3: Install Solana CLI

**Check if you have Solana:**
```bash
solana --version
```

**If not installed:**

**Linux/Mac:**
```bash
sh -c "$(curl -sSfL https://release.solana.com/stable/install)"
```

**Windows (PowerShell as Administrator):**
```powershell
cmd /c "curl https://release.solana.com/stable/solana-install-init-x86_64-pc-windows-msvc.exe --output C:\solana-install-tmp\solana-install-init.exe --create-dirs"
C:\solana-install-tmp\solana-install-init.exe
```

**Add to PATH:**

**Linux/Mac:**
```bash
export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"
echo 'export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

**Windows:** The installer does this automatically.

**Verify:**
```bash
solana --version
```

**Expected Output:**
```
solana-cli 1.17.10 (src:b3b9a603; feat:3352961542, client:SolanaLabs)
```

---

### Step 4: Install Anchor Framework

**Check if you have Anchor:**
```bash
anchor --version
```

**If not installed:**

```bash
# Install Anchor Version Manager (avm)
cargo install --git https://github.com/coral-xyz/anchor avm --locked --force

# This takes 5-10 minutes...
```

**Expected Output:**
```
    Updating git repository `https://github.com/coral-xyz/anchor`
   Compiling avm v0.29.0
    Finished release [optimized] target(s) in 8m 23s
  Installing ~/.cargo/bin/avm
   Installed package `avm v0.29.0` (executable `avm`)
```

**Install Anchor:**
```bash
avm install latest
avm use latest
```

**Expected Output:**
```
downloading anchor version: 0.29.0
anchor version 0.29.0 installed
anchor 0.29.0 set as default
```

**Verify:**
```bash
anchor --version
```

**Expected Output:**
```
anchor-cli 0.29.0
```

---

### Step 5: Install Node.js (for testing - optional)

**Check if you have Node:**
```bash
node --version
npm --version
```

**If not installed:** Download from https://nodejs.org/ (LTS version)

**Expected Output:**
```
v18.17.0
9.6.7
```

---

## Part 3: Build Quorlin Compiler

### Step 6: Build the Compiler

```bash
cd /path/to/quorlin-lang

# Build in release mode (optimized)
cargo build --release
```

**This takes 5-10 minutes the first time...**

**Expected Output:**
```
   Compiling quorlin-parser v0.1.0
   Compiling quorlin-semantics v0.1.0
   Compiling quorlin-codegen-evm v0.1.0
   Compiling quorlin-codegen-solana v0.1.0
   Compiling qlc v0.1.0
    Finished release [optimized] target(s) in 8m 34s
```

**Verify:**
```bash
./target/release/qlc --version
```

**Expected Output:**
```
qlc 0.1.0
```

---

## Part 4: Set Up Solana Wallet

### Step 7: Create Solana Wallet

**Check if you have a wallet:**
```bash
ls ~/.config/solana/id.json
```

**If file exists, skip to Step 8. Otherwise, create one:**
```bash
solana-keygen new --outfile ~/.config/solana/id.json
```

**You'll be prompted:**
```
Generating a new keypair

For added security, enter a BIP39 passphrase

NOTE! This passphrase improves security of the recovery seed phrase NOT the
keypair file itself, which is stored as insecure plain text

BIP39 Passphrase (empty for none):
```

**Press Enter for no passphrase (this is DevNet, security is not critical)**

**Expected Output:**
```
Wrote new keypair to /home/user/.config/solana/id.json
================================================================================
pubkey: 5Yj3kDvF2qwLPAYdhG7xC3cN8qKJRq9Xm4xU7pL2VxKz
================================================================================
Save this seed phrase and your BIP39 passphrase to recover your new keypair:
[12-24 word seed phrase shown here]
================================================================================
```

**⚠️ IMPORTANT:** Save the seed phrase somewhere safe!

---

### Step 8: Configure Solana to Use DevNet

```bash
# Set network to DevNet
solana config set --url https://api.devnet.solana.com

# Verify configuration
solana config get
```

**Expected Output:**
```
Config File: /home/user/.config/solana/cli/config.yml
RPC URL: https://api.devnet.solana.com
WebSocket URL: wss://api.devnet.solana.com/ (computed)
Keypair Path: /home/user/.config/solana/id.json
Commitment: confirmed
```

---

### Step 9: Get Your Wallet Address

```bash
solana address
```

**Expected Output:**
```
5Yj3kDvF2qwLPAYdhG7xC3cN8qKJRq9Xm4xU7pL2VxKz
```

**Copy this address - you'll need it!**

---

### Step 10: Get Free DevNet SOL

```bash
# Check current balance
solana balance

# Request airdrop (2 SOL)
solana airdrop 2

# Wait 5 seconds, then check again
solana balance
```

**Expected Output:**
```
0 SOL
Requesting airdrop of 2 SOL

Signature: 2ZE7R...xyz (transaction signature)

2 SOL
```

**⚠️ If airdrop fails with rate limit:**
- Wait 1-2 minutes and try again
- Or use the web faucet: https://faucet.solana.com/
- Paste your address and request SOL

---

## Part 5: Compile Quorlin Contract to Solana

### Step 11: Compile Token Contract

```bash
cd /path/to/quorlin-lang

# Compile Quorlin → Solana/Anchor
./target/release/qlc compile examples/token.ql --target solana --output anchor-test/programs/quorlin-token/src/lib.rs
```

**Expected Output:**
```
╔════════════════════════════════════════════════════════════╗
║                  🚀 QUORLIN COMPILER 🚀                   ║
╚════════════════════════════════════════════════════════════╝

  📄 Source: examples/token.ql
  🎯 Target: solana

  [1/4] → Tokenizing
      ✓ 566 tokens generated
      [█████░░░░░░░░░░░░░░░] 25%

  [2/4] → Parsing
      ✓ AST generated successfully
      [██████████░░░░░░░░░░] 50%

  [3/4] → Semantic Analysis
      ✓ Type checking passed
      [███████████████░░░░░] 75%

  [4/4] → Code Generation
      ✓ Generated anchor-test/programs/quorlin-token/src/lib.rs
      [████████████████████] 100%

╔════════════════════════════════════════════════════════════╗
║              ✨ COMPILATION SUCCESSFUL ✨                 ║
╚════════════════════════════════════════════════════════════╝

  📦 Output: anchor-test/programs/quorlin-token/src/lib.rs
  📊 Size: 4.94 KB
  ⚡ Time: 1ms
```

**✅ Quorlin contract compiled to Solana!**

---

## Part 6: Build Solana Program

### Step 12: Navigate to Anchor Project

```bash
cd anchor-test
```

---

### Step 13: Install Dependencies (First Time Only)

```bash
npm install
```

**Expected Output:**
```
added 234 packages in 12s
```

---

### Step 14: Build the Solana Program

```bash
anchor build
```

**This takes 3-5 minutes the first time...**

**Expected Output:**
```
   Compiling quorlin-token v0.1.0 (/path/to/quorlin-lang/anchor-test/programs/quorlin-token)
    Finished release [optimized] target(s) in 3m 42s
```

**Expected Files Created:**
```
target/deploy/quorlin_token.so              # Program binary
target/deploy/quorlin_token-keypair.json    # Program keypair
target/idl/quorlin_token.json               # Interface Definition
```

**Verify the build:**
```bash
ls -lh target/deploy/quorlin_token.so
```

**Expected Output:**
```
-rwxr-xr-x 1 user user 245K Dec 3 10:30 target/deploy/quorlin_token.so
```

---

## Part 7: Deploy to Solana DevNet

### Step 15: Deploy the Program

```bash
anchor deploy --provider.cluster devnet
```

**This uploads your program to DevNet...**

**Expected Output:**
```
Deploying workspace: https://api.devnet.solana.com
Upgrade authority: 5Yj3kDvF2qwLPAYdhG7xC3cN8qKJRq9Xm4xU7pL2VxKz
Deploying program "quorlin_token"...
Program path: /path/to/anchor-test/target/deploy/quorlin_token.so...
Program Id: Fg6PaFpoGXkYsidMpWTK6W2BeZ7FEfcYkg476zPFsLnS

Deploy success
```

**✅ YOUR PROGRAM IS NOW LIVE ON SOLANA DEVNET!**

---

### Step 16: Get Your Program ID

```bash
solana address -k target/deploy/quorlin_token-keypair.json
```

**Expected Output:**
```
Fg6PaFpoGXkYsidMpWTK6W2BeZ7FEfcYkg476zPFsLnS
```

**Copy this - this is your deployed program ID!**

---

## Part 8: Verify Deployment

### Step 17: Check Program on Blockchain

```bash
solana program show Fg6PaFpoGXkYsidMpWTK6W2BeZ7FEfcYkg476zPFsLnS --url devnet
```

**Expected Output:**
```
Program Id: Fg6PaFpoGXkYsidMpWTK6W2BeZ7FEfcYkg476zPFsLnS
Owner: BPFLoaderUpgradeab1e11111111111111111111111
ProgramData Address: 7Xj9...abc
Authority: 5Yj3kDvF2qwLPAYdhG7xC3cN8qKJRq9Xm4xU7pL2VxKz
Last Deployed In Slot: 276543210
Data Length: 245760 (0x3c000) bytes
Balance: 1.71 SOL
```

---

### Step 18: View on Solana Explorer

**Open your browser and visit:**
```
https://explorer.solana.com/address/Fg6PaFpoGXkYsidMpWTK6W2BeZ7FEfcYkg476zPFsLnS?cluster=devnet
```

**You should see:**
- ✅ Program account details
- ✅ Transaction history
- ✅ Program data

**Screenshot what you see - your program is LIVE!**

---

## Part 9: Test Your Deployed Program (Optional)

### Step 19: Run Anchor Tests

```bash
# From anchor-test directory
anchor test --skip-local-validator
```

**This runs tests against your deployed program on DevNet**

**Expected Output:**
```
  quorlin-token
    ✔ Initialize token (1234ms)
    ✔ Transfer tokens (567ms)

  2 passing (2s)
```

---

## 🎉 SUCCESS! You've Deployed to Solana DevNet!

### What You Accomplished:

✅ **Pulled latest Quorlin code**
✅ **Installed Solana CLI & Anchor**
✅ **Created Solana wallet**
✅ **Got free DevNet SOL**
✅ **Compiled Quorlin → Solana/Anchor**
✅ **Built Solana program**
✅ **Deployed to DevNet**
✅ **Verified on Solana Explorer**

---

## 📊 Summary of Your Deployment

| Item | Value |
|------|-------|
| **Program ID** | Fg6PaFpoGXkYsidMpWTK6W2BeZ7FEfcYkg476zPFsLnS |
| **Network** | Solana DevNet |
| **Your Wallet** | 5Yj3kDvF2qwLPAYdhG7xC3cN8qKJRq9Xm4xU7pL2VxKz |
| **Cost** | FREE (DevNet) |
| **Explorer** | https://explorer.solana.com/address/YOUR_PROGRAM_ID?cluster=devnet |

---

## 🚀 Next Steps

### Want to Deploy to MainNet?

**⚠️ WARNING: MainNet costs real SOL!**

1. **Get SOL** (~1-2 SOL for deployment)
2. **Switch network:**
   ```bash
   solana config set --url https://api.mainnet-beta.solana.com
   ```
3. **Deploy:**
   ```bash
   anchor deploy --provider.cluster mainnet
   ```

### Want to Update Your Program?

```bash
# Edit your Quorlin code
# Recompile
./target/release/qlc compile examples/token.ql --target solana --output anchor-test/programs/quorlin-token/src/lib.rs

# Rebuild
cd anchor-test
anchor build

# Upgrade (uses same Program ID)
anchor upgrade --provider.cluster devnet target/deploy/quorlin_token.so --program-id Fg6PaFpoGXkYsidMpWTK6W2BeZ7FEfcYkg476zPFsLnS
```

---

## ❓ Troubleshooting

### "solana: command not found"

**Solution:** Solana not in PATH. Run:
```bash
export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"
```

---

### "anchor: command not found"

**Solution:** Anchor not installed. Run:
```bash
cargo install --git https://github.com/coral-xyz/anchor avm --locked --force
avm install latest
avm use latest
```

---

### "Insufficient funds"

**Solution:** Get more DevNet SOL:
```bash
solana airdrop 2
# Or use: https://faucet.solana.com/
```

---

### "Error: Account allocation failed: unable to confirm transaction"

**Solution:** Network congestion. Wait 30 seconds and try again:
```bash
anchor deploy --provider.cluster devnet
```

---

### "Program ID mismatch"

**Solution:** Update the program ID in your code:

1. Get your actual program ID:
   ```bash
   solana address -k target/deploy/quorlin_token-keypair.json
   ```

2. Edit `programs/quorlin-token/src/lib.rs`:
   ```rust
   declare_id!("YOUR_ACTUAL_PROGRAM_ID_HERE");
   ```

3. Rebuild:
   ```bash
   anchor build
   anchor deploy --provider.cluster devnet
   ```

---

## 📞 Need Help?

- **Solana Discord:** https://discord.gg/solana
- **Anchor Docs:** https://www.anchor-lang.com/docs
- **Solana Docs:** https://docs.solana.com/

---

**Congratulations! You're now a Solana developer! 🎉**
