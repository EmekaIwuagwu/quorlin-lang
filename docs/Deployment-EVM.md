# Quorlin → EVM Deployment Guide

Complete guide for deploying Quorlin smart contracts to Ethereum Virtual Machine (EVM) compatible blockchains.

---

## 🎯 Prerequisites

### Required Software

1. **Rust & Cargo** (for building the Quorlin compiler)
   - Install: https://rustup.rs/

2. **Solc** (Solidity compiler for Yul → Bytecode)
   - Windows: Download `solc-windows.exe` from https://github.com/ethereum/solidity/releases
   - Linux/Mac: `npm install -g solc` or download binary

3. **Node.js & npm** (for Hardhat deployment)
   - Install: https://nodejs.org/ (v18+ recommended)

4. **Hardhat** (Ethereum development environment)
   - Installed via npm in project

---

## 📁 Project Structure

```
quorlin-lang/
├── examples/
│   └── token.ql              # Your Quorlin smart contract
├── target/release/
│   └── qlc.exe              # Compiled Quorlin compiler
├── hardhat-test/
│   ├── hardhat.config.js    # Hardhat configuration
│   ├── scripts/
│   │   ├── deploy-token.js  # Deployment script
│   │   └── interact-token.js # Interaction script
│   └── token.yul            # Generated Yul code
└── solc.exe                 # Solc compiler (Windows)
```

---

## 🔄 Compilation Pipeline

```
Quorlin (.ql) → Yul (.yul) → EVM Bytecode → Deployed Contract
```

---

## 📝 Step-by-Step Deployment

### Quick Start: Automated Deployment ⚡

The fastest way to deploy is using the automated script:

```bash
# Terminal 1: Start Hardhat node
cd hardhat-test
npx hardhat node

# Terminal 2: Compile and deploy
cd hardhat-test
npx hardhat run scripts/compile-and-deploy.js --network localhost
```

This script automatically:
1. Compiles Quorlin → Yul
2. Compiles Yul → Bytecode (if solc available)
3. Deploys with correct constructor parameters
4. Verifies total supply
5. Saves contract address for interaction

**See `hardhat-test/DEPLOY-INSTRUCTIONS.md` for detailed steps.**

---

### Manual Deployment (Advanced)

### Step 1: Build Quorlin Compiler

```bash
# From project root
cargo build --release
```

**Output:** `target/release/qlc` (or `qlc.exe` on Windows)

---

### Step 2: Compile Quorlin → Yul

```bash
# Compile your .ql contract to Yul
./target/release/qlc compile examples/token.ql --target evm --output hardhat-test/token.yul
```

**Output:** `token.yul` (Ethereum intermediate representation)

**Verify:** Check that the Yul file:
- Starts with `object "Contract" {`
- Has a constructor section: `code { ... }`
- Has a runtime section: `object "runtime" { code { ... } }`
- Constructor uses `codecopy` for parameters (v0.1.1+)

---

### Step 3: Compile Yul → Bytecode

```bash
# Compile Yul to EVM bytecode
solc --strict-assembly token.yul --bin --optimize
```

**Output:**
```
======= token.yul (EVM) =======

Binary representation:
5f3580600355335f52600460205269d3c21bcecceda100000060405f20555f80...
```

**Copy the hex string** after "Binary representation:" - this is your deployable bytecode!

---

### Step 4: Setup Hardhat Environment

```bash
cd hardhat-test
npm install
```

This installs:
- `hardhat` - Ethereum development environment
- `@nomicfoundation/hardhat-toolbox` - Essential plugins
- `ethers.js` - Ethereum library

---

### Step 5: Start Local Blockchain (Terminal 1)

```bash
cd hardhat-test
npx hardhat node
```

**Keep this running!** You should see:
```
Started HTTP and WebSocket JSON-RPC server at http://127.0.0.1:8545/

Accounts
========
Account #0: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 (10000 ETH)
Account #1: 0x70997970C51812dc3A010C7d01b50e0d17dc79C8 (10000 ETH)
...
```

---

### Step 6: Update Deployment Script (Terminal 2)

Edit `hardhat-test/scripts/deploy-token.js` and update line 19 with your bytecode:

```javascript
const bytecode = "0xYOUR_BYTECODE_HERE";
```

Paste the hex string from Step 3 (add `0x` prefix).

---

### Step 7: Deploy Contract

```bash
cd hardhat-test
npx hardhat run scripts/deploy-token.js --network localhost
```

**Expected Output:**
```
╔════════════════════════════════════════════════════════════╗
║           🚀 Deploying Quorlin Token Contract 🚀          ║
╚════════════════════════════════════════════════════════════╝

  📦 Contract address: 0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0
  ⛽ Gas used: 227177
  🔗 Block number: 1

  ✅ Total supply stored: 1000000000000000000000000
```

**Save the contract address!**

---

### Step 8: Interact with Contract

```bash
# Windows
set CONTRACT_ADDRESS=0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0
npx hardhat run scripts/interact-token.js --network localhost

# Linux/Mac
CONTRACT_ADDRESS=0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0 npx hardhat run scripts/interact-token.js --network localhost
```

**This will test:**
- ✅ Read total supply
- ✅ Transfer tokens
- ✅ Approve spending allowances
- ✅ Transfer from approved accounts
- ✅ Check balances

---

## 🌐 Deploy to Testnets

### Sepolia Testnet

1. **Get Testnet ETH:**
   - Faucet: https://sepoliafaucet.com/

2. **Update hardhat.config.js:**
```javascript
networks: {
  sepolia: {
    url: "https://sepolia.infura.io/v3/YOUR_INFURA_KEY",
    accounts: [process.env.PRIVATE_KEY]
  }
}
```

3. **Deploy:**
```bash
npx hardhat run scripts/deploy-token.js --network sepolia
```

---

## 🛠️ Troubleshooting

### Error: "solc: command not found"
- **Windows:** Ensure `solc.exe` is in project root or PATH
- **Linux/Mac:** Run `npm install -g solc` or download binary

### Error: "Cannot connect to localhost:8545"
- Make sure Hardhat node is running in Terminal 1
- Check no firewall blocking port 8545

### Error: "Transaction reverted"
- Check constructor parameters are correct
- Verify bytecode is complete
- Ensure sufficient gas limit

### Error: "Invalid bytecode"
- Bytecode must start with `0x`
- Verify no extra spaces or newlines
- Recompile Yul if needed

### Error: "Total supply is 0" (Fixed in v0.1.1)

**Problem:** Constructor parameters not being read correctly.

**Solution:** Update to Quorlin v0.1.1+ which uses `codecopy` for constructor parameters:

```bash
# Rebuild compiler
cargo build --release

# Recompile your contract
./target/release/qlc compile examples/token.ql --target evm --output hardhat-test/token.yul
```

**Technical Details:**
- **Old (v0.1.0):** Used `calldataload(0)` which doesn't work during deployment
- **New (v0.1.1+):** Uses `codecopy` to read parameters appended to bytecode

Check your generated Yul file - the constructor should look like:
```yul
// Constructor parameters are appended to the bytecode
let paramsStart := datasize("Contract")
codecopy(0, add(paramsStart, 0), 32)
let initial_supply := mload(0)
```

---

## 📊 Gas Costs (Approximate)

| Operation | Gas Cost |
|-----------|----------|
| Deploy Token Contract | ~227,000 |
| Transfer | ~51,000 |
| Approve | ~46,000 |
| Transfer From | ~64,000 |

*Costs vary based on optimization and storage operations*

---

## 🎯 Quick Reference

### One-Line Compilation

```bash
# Compile everything in one go
./target/release/qlc compile examples/token.ql --target evm --output token.yul && \
solc --strict-assembly token.yul --bin --optimize
```

### Check Contract on Etherscan

After deploying to testnet:
1. Go to https://sepolia.etherscan.io/
2. Paste your contract address
3. View transactions and state

---

## 🔐 Security Checklist

Before mainnet deployment:

- [ ] Audit all arithmetic operations
- [ ] Test access controls
- [ ] Verify event emissions
- [ ] Test edge cases (zero values, max uint256)
- [ ] Check reentrancy protection
- [ ] Review require statements
- [ ] Test with different accounts
- [ ] Verify constructor parameters

---

## 📚 Additional Resources

- **Quorlin Documentation:** [Coming Soon]
- **Hardhat Docs:** https://hardhat.org/docs
- **Ethers.js Docs:** https://docs.ethers.org/
- **Yul Docs:** https://docs.soliditylang.org/en/latest/yul.html

---

## 🎉 Success Criteria

Your deployment is successful when:

✅ Bytecode compiles without errors
✅ Contract deploys and returns address
✅ Total supply reads correctly
✅ All token functions execute
✅ Balances update correctly
✅ Events are emitted

---

**Last Updated:** December 2025
**Quorlin Version:** 0.1.0
**Compatible EVM Chains:** Ethereum, Polygon, BSC, Avalanche, Arbitrum, Optimism
