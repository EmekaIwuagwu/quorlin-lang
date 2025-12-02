# Deploy Quorlin Token - Step by Step

## Prerequisites

Make sure you have:
- ✅ Hardhat node running in Terminal 1
- ✅ Compiled qlc.exe in target/release/
- ✅ Downloaded solc.exe in project root

## Step 1: Compile Quorlin → Yul → Bytecode

Open Terminal 2 and run:

```cmd
cd C:\Users\HP\Desktop\quorlin-lang

# Compile Quorlin to Yul
.\target\release\qlc.exe compile examples\token.ql --target evm --output hardhat-test\token.yul

# Compile Yul to bytecode
.\solc.exe --strict-assembly hardhat-test\token.yul --bin --optimize > hardhat-test\token-bytecode.txt
```

## Step 2: Extract Bytecode

Open `hardhat-test\token-bytecode.txt` and copy ONLY the hex string after "Binary representation:" (the long string starting with numbers/letters, NOT including "0x").

## Step 3: Update Deploy Script

Open `hardhat-test\scripts\deploy-token.js` in a text editor.

Find this line (around line 19):
```javascript
const bytecode = "0x5f3580600355...";  // OLD BYTECODE
```

Replace it with:
```javascript
const bytecode = "0x" + "PASTE_YOUR_BYTECODE_HERE";
```

Save the file.

## Step 4: Deploy

```cmd
cd hardhat-test
npx hardhat run scripts\deploy-token.js --network localhost
```

You should now see the correct total supply: 1000000.0 tokens!

## Step 5: Interact

```cmd
set CONTRACT_ADDRESS=0xYourContractAddressHere
npx hardhat run scripts\interact-token.js --network localhost
```

---

## Alternative: Automated Script

If you want automatic compilation, use:

```cmd
cd hardhat-test
npx hardhat run scripts\compile-and-deploy.js --network localhost
```

This will automatically:
1. Compile Quorlin to Yul
2. Compile Yul to bytecode (if solc is in PATH)
3. Deploy with correct bytecode
