# Deploy Quorlin Token - Step by Step

## Prerequisites

Make sure you have:
- ✅ Hardhat node running in Terminal 1
- ✅ Compiled qlc in target/release/
- ✅ solc installed (optional - script has fallback)

## Quick Deploy (Recommended)

### Option 1: Automated Script

```bash
cd hardhat-test
npx hardhat run scripts/compile-and-deploy.js --network localhost
```

This will automatically:
1. ✅ Compile Quorlin → Yul
2. ✅ Compile Yul → Bytecode (if solc available)
3. ✅ Deploy with correct constructor parameters
4. ✅ Save contract address to deployed-address.txt

---

## Manual Deploy (If automated script fails)

### Step 1: Compile Quorlin → Yul

```bash
cd /path/to/quorlin-lang
./target/release/qlc compile examples/token.ql --target evm --output hardhat-test/token.yul
```

### Step 2: Compile Yul → Bytecode

```bash
# If solc is installed
solc --strict-assembly hardhat-test/token.yul --bin --optimize > hardhat-test/token-bytecode.txt

# Otherwise, save the Yul to token.bin manually after running solc elsewhere
```

### Step 3: Extract Bytecode

Open `hardhat-test/token-bytecode.txt` and copy ONLY the hex string after "Binary representation:" (the long string starting with numbers/letters, NOT including "0x").

### Step 4: Update Deploy Script

Open `hardhat-test/scripts/deploy-token.js` in a text editor.

Find this line (around line 19):
```javascript
const bytecode = "0x5f3580600355...";  // OLD BYTECODE
```

Replace it with:
```javascript
const bytecode = "0x" + "PASTE_YOUR_BYTECODE_HERE";
```

Save the file.

### Step 5: Deploy

```bash
cd hardhat-test
npx hardhat run scripts/deploy-token.js --network localhost
```

You should now see the correct total supply: 1000000.0 tokens!

### Step 6: Interact

```bash
# Linux/Mac
CONTRACT_ADDRESS=0xYourContractAddressHere npx hardhat run scripts/interact-token.js --network localhost

# Or read from saved file
CONTRACT_ADDRESS=$(cat deployed-address.txt) npx hardhat run scripts/interact-token.js --network localhost
```

---

## Troubleshooting

### Error: "solc: command not found"

The automated script will use a fallback bytecode file if solc is not available. You can:
1. Install solc: `npm install -g solc`
2. Download solc binary from https://github.com/ethereum/solidity/releases
3. Or compile Yul on another machine and copy the bytecode

### Error: "Cannot connect to localhost:8545"

Make sure Hardhat node is running:
```bash
cd hardhat-test
npx hardhat node
```

### Error: "Contract deployed but total supply is 0"

This means constructor parameters weren't passed correctly. The fix in v0.1.1+ handles this automatically using `codecopy` instead of `calldataload`.

Make sure you're using the latest compiler:
```bash
cargo build --release
```

---

## What Changed in v0.1.1

**Fixed:** Constructor parameter handling

**Before (v0.1.0):**
```yul
let initial_supply := calldataload(0)  // ❌ Didn't work
```

**After (v0.1.1):**
```yul
let paramsStart := datasize("Contract")
codecopy(0, add(paramsStart, 0), 32)
let initial_supply := mload(0)  // ✅ Works correctly
```

This properly reads constructor parameters appended to the deployment bytecode.

---

## Success Criteria

Your deployment is successful when you see:

```
╔════════════════════════════════════════════════════════════╗
║              ✨ DEPLOYMENT SUCCESSFUL ✨                  ║
╚════════════════════════════════════════════════════════════╝

  📦 Contract address: 0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0
  ⛽ Gas used: 227177
  🔗 Block number: 1

  ✅ Total supply verified: 1000000.0 tokens
```

The total supply should be **1000000.0 tokens**, not 0!
