# Deploying Quorlin Contracts to Polkadot (ink!)

This guide demonstrates how to compile and deploy Quorlin smart contracts to Polkadot-compatible chains using ink! v5.

## 🎉 Achievement: DEPLOYED AND LIVE!

**We've successfully achieved write-once, deploy-everywhere** across all three major blockchain platforms:
- ✅ **EVM** (Ethereum, Polygon, BSC, etc.) - **DEPLOYED** (Local Hardhat + Testnets)
- ✅ **Solana** (Deployed to DevNet) - Program ID: `m3BqeaAW3JKJK32PnTV9PKjHA3XHpinfaWopwvdXmJz`
- ✅ **Polkadot** (ink! v5 / Substrate) - **DEPLOYED TO LOCAL NODE**

### Live Deployment Details

**Contract Address**: `5Cmg5TKsLBoeTbU4MkSJekwG6LQ5nt2My98p411sQvJb2eYs`
**Code Hash**: `0xc4ab3367b8307d99b9dd81567016f5e73519d6a2ddbaf08c63c12814f777074a`
**Network**: Local Substrate Contracts Node
**Initial Supply**: 1,000,000 tokens
**Deployment Date**: December 5, 2025
**Status**: ✅ Successfully instantiated with Transfer event emitted

The same `token.ql` contract now runs on all three blockchain ecosystems!

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Quick Start](#quick-start)
3. [Compilation Process](#compilation-process)
4. [Deployment](#deployment)
5. [Contract Interaction](#contract-interaction)
6. [Troubleshooting](#troubleshooting)

## Prerequisites

### Required Tools

```bash
# Rust and Cargo (latest stable)
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Add WASM target and rust-src
rustup target add wasm32-unknown-unknown
rustup component add rust-src --toolchain stable

# Install cargo-contract (ink! build tool)
cargo install cargo-contract --version 4.1.1
```

### Optional: Local Testnet

```bash
# substrate-contracts-node (lightweight local testnet for contracts)
cargo install contracts-node --git https://github.com/paritytech/substrate-contracts-node
```

## Quick Start

### 1. Compile Quorlin to ink!

```bash
# From the quorlin-lang directory
qlc compile examples/token.ql --target ink --output ink-test/contracts/quorlin-token/src/lib.rs
```

### 2. Build the Contract

```bash
cd ink-test/contracts/quorlin-token
cargo contract build --release
```

Your contract artifacts will be in `ink-test/target/ink/quorlin_token/`:
- `quorlin_token.contract` - Complete bundle (code + metadata)
- `quorlin_token.wasm` - Contract bytecode
- `quorlin_token.json` - Contract metadata

### 3. Deploy to Local Testnet

```bash
# Terminal 1: Start local testnet
substrate-contracts-node --dev

# Terminal 2: Deploy contract
cargo contract instantiate \
  --constructor new \
  --args 1000000 \
  --suri //Alice \
  --execute
```

## Compilation Process

### How Quorlin Compiles to ink!

The Quorlin compiler (`qlc`) performs the following steps:

1. **Lexing** - Tokenizes the Quorlin source code
2. **Parsing** - Builds an Abstract Syntax Tree (AST)
3. **Semantic Analysis** - Type checking and validation
4. **Code Generation** - Transforms AST to ink! Rust code

### Generated Code Features

The ink! code generator (`quorlin-codegen-ink`) produces:

✅ **Storage Structure** with ink! `#[ink(storage)]` macro
✅ **Constructor** mapped from `__init__` function
✅ **Messages** with proper `&self` or `&mut self` based on `@view` decorator
✅ **Events** with `#[ink(event)]` and topic indexing
✅ **Checked Arithmetic** - All math operations use `.checked_*()` methods
✅ **Nested Mappings** - Implemented using tuple keys `Mapping<(K1, K2), V>`
✅ **Zero Address Handling** - Proper `AccountId::from([0u8; 32])`

### Type Mappings

| Quorlin Type | ink! Type | Notes |
|--------------|-----------|-------|
| `uint8` - `uint64` | `u8` - `u64` | Direct mapping |
| `uint128` | `u128` | Direct mapping |
| `uint256` | `u128` | ⚠️ Downcast for ink! v5 compatibility |
| `address` | `AccountId` | 32-byte account ID |
| `str` | `String` | From `ink::prelude::string::String` |
| `bool` | `bool` | Direct mapping |
| `mapping[K,V]` | `Mapping<K,V>` | ink! storage mapping |
| `mapping[K1,mapping[K2,V]]` | `Mapping<(K1,K2),V>` | Flattened with tuple key |

## Deployment

### Option 1: Local Testnet (substrate-contracts-node)

**Start the Node:**
```bash
substrate-contracts-node --dev --tmp
```

**Deploy with cargo-contract:**
```bash
cd ink-test/contracts/quorlin-token

# Upload and instantiate
cargo contract instantiate \
  target/ink/quorlin_token/quorlin_token.contract \
  --constructor new \
  --args 1000000 \
  --suri //Alice \
  --execute

# Note the contract address from the output
```

**Interact with the Contract:**
```bash
# Check balance
cargo contract call \
  --contract <CONTRACT_ADDRESS> \
  --message balance_of \
  --args <ACCOUNT_ADDRESS> \
  --suri //Alice \
  --dry-run

# Transfer tokens
cargo contract call \
  --contract <CONTRACT_ADDRESS> \
  --message transfer \
  --args <TO_ADDRESS> 100 \
  --suri //Alice \
  --execute
```

### Option 2: Polkadot Testnets

**Rococo Contracts (Testnet):**
```bash
cargo contract instantiate \
  target/ink/quorlin_token/quorlin_token.contract \
  --constructor new \
  --args 1000000 \
  --url wss://rococo-contracts-rpc.polkadot.io \
  --suri "your mnemonic phrase here" \
  --execute
```

**Shibuya (Astar Testnet):**
```bash
cargo contract instantiate \
  target/ink/quorlin_token/quorlin_token.contract \
  --constructor new \
  --args 1000000 \
  --url wss://rpc.shibuya.astar.network \
  --suri "your mnemonic phrase here" \
  --execute
```

### Option 3: Using Contracts UI

1. Go to [https://contracts-ui.substrate.io/](https://contracts-ui.substrate.io/)
2. Connect to your local node or testnet
3. Upload `quorlin_token.contract`
4. Instantiate with initial supply parameter
5. Interact through the web interface

## Contract Interaction

### Query Methods (Read-Only)

```bash
# Get total supply
cargo contract call \
  --contract <ADDRESS> \
  --message get_total_supply \
  --suri //Alice \
  --dry-run

# Check balance
cargo contract call \
  --contract <ADDRESS> \
  --message balance_of \
  --args <OWNER_ADDRESS> \
  --suri //Alice \
  --dry-run

# Check allowance
cargo contract call \
  --contract <ADDRESS> \
  --message allowance \
  --args <OWNER> <SPENDER> \
  --suri //Alice \
  --dry-run
```

### Transaction Methods (State-Changing)

```bash
# Transfer tokens
cargo contract call \
  --contract <ADDRESS> \
  --message transfer \
  --args <TO> 1000 \
  --suri //Alice \
  --execute

# Approve spending
cargo contract call \
  --contract <ADDRESS> \
  --message approve \
  --args <SPENDER> 5000 \
  --suri //Alice \
  --execute

# Transfer from (requires approval)
cargo contract call \
  --contract <ADDRESS> \
  --message transfer_from \
  --args <FROM> <TO> 500 \
  --suri //Bob \
  --execute
```

## Automation Script

See `ink-test/scripts/compile-and-deploy.sh` for an automated deployment workflow.

## Troubleshooting

### Build Errors

**Error: `cannot find type U256`**
- **Fix**: Use u128 instead. The codegen maps uint256 → u128 for ink! v5 compatibility.

**Error: `rust-src` component missing**
```bash
rustup component add rust-src --toolchain stable
```

**Error: `StorageLayout` not implemented**
- This means a type doesn't have ink! storage traits. Use built-in types or implement the trait.

### Deployment Errors

**Error: Module not found**
```bash
# Clean and rebuild
cargo contract build --release
```

**Error: Insufficient funds**
- Ensure your account has enough tokens for gas fees
- On local testnet, use pre-funded accounts like `//Alice`

### Common Issues

**WASM file too large:**
```bash
# Build with optimization
cargo contract build --release

# The contract should be <100KB for most chains
```

**Constructor fails:**
- Check parameter types match the contract
- Verify account has sufficient balance
- Review error in transaction details

## Additional Resources

- [ink! Documentation](https://use.ink/)
- [Substrate Contracts Node](https://github.com/paritytech/substrate-contracts-node)
- [Contracts UI](https://contracts-ui.substrate.io/)
- [Polkadot Wiki - Smart Contracts](https://wiki.polkadot.network/docs/build-smart-contracts)
- [Astar Network](https://astar.network/) - Production-ready parachain with ink! support

## Next Steps

1. **Test on Rococo Contracts** - Public testnet for contracts
2. **Deploy to Astar** - Production parachain with EVM and WASM support
3. **Optimize Gas Costs** - Profile and optimize contract calls
4. **Add Access Control** - Implement ownership patterns
5. **Write Tests** - Use ink!'s E2E testing framework

## Contract Specifications

**Generated Contract:**
- Source: `examples/token.ql`
- Target: ink! v5.0.0
- WASM Size: 9.8KB (optimized, 71% reduction from 34.4KB)
- Contract Bundle: 28KB
- Metadata Size: 20KB
- Storage: 6 fields (symbol, name, decimals, total_supply, balances, allowances)
- Functions: 6 (new, transfer, approve, transfer_from, balance_of, allowance, get_total_supply)
- Events: 2 (Transfer, Approval)

## Live Deployment Results

### Performance Metrics

**Build Performance:**
```
Original WASM: 34.4KB
Optimized WASM: 9.8KB (71% reduction)
Build Time: ~25 seconds
Optimization Level: --release
```

**Deployment Costs:**
```
Gas Estimate: Weight(ref_time: 628007045, proof_size: 42842)
Storage Deposit: 350.785 mUNIT
Code Storage: 249.49 mUNIT
Contract Storage: 100.61 mUNIT + 200.175 mUNIT
Transaction Fee: 2.399795011 mUNIT
```

**Deployment Events:**
1. ✅ `Balances::Withdraw` - Deployment fee charged
2. ✅ `Contracts::CodeStored` - WASM bytecode uploaded to chain
3. ✅ `System::NewAccount` - Contract account created
4. ✅ `Balances::Endowed` - Contract account funded
5. ✅ `Balances::Transfer` - Initial balance transferred
6. ✅ `Contracts::ContractEmitted` - Transfer event with initial supply
7. ✅ `Contracts::Instantiated` - Contract successfully instantiated
8. ✅ `Contracts::StorageDepositTransferredAndHeld` - Storage deposits locked
9. ✅ `TransactionPayment::TransactionFeePaid` - Transaction finalized

### Code Generation Highlights

**Key Technical Features:**
- ✅ Nested mapping flattening: `Mapping<(AccountId, AccountId), u128>` for allowances
- ✅ Type adaptation: `uint256` → `u128` for ink! v5 StorageLayout compatibility
- ✅ No-std WASM environment: `use ink::prelude::string::String`
- ✅ Checked arithmetic: All operations use `.checked_add()`, `.checked_sub()`, etc.
- ✅ Zero address handling: `AccountId::from([0u8; 32])`
- ✅ Consistent API: `Self::env().caller()` for msg.sender equivalent

---

**🎉 Congratulations!** You've successfully deployed Quorlin contracts to Polkadot using ink!. Your contract is now running on a production-grade WASM runtime.

## Real-World Deployment Example

Here's the complete deployment we achieved:

```bash
# 1. Built contract with automation script
$ ./ink-test/scripts/compile-and-deploy.sh --deploy

# 2. Deployment output
✓ Build successful
  Contract Artifacts:
    • Contract bundle: 28K
    • WASM bytecode:   12K (9.8KB optimized)
    • Metadata:        20K
    • Location:        ink-test/target/ink/quorlin_token/

# 3. Deployment successful
  Node URL:       ws://127.0.0.1:9944
  Account:        //Alice
  Initial Supply: 1000000

   Code hash 0xc4ab3367b8307d99b9dd81567016f5e73519d6a2ddbaf08c63c12814f777074a
    Contract 5Cmg5TKsLBoeTbU4MkSJekwG6LQ5nt2My98p411sQvJb2eYs
  ✓ Deployment successful!

# 4. Verification
$ cargo contract call \
  --contract 5Cmg5TKsLBoeTbU4MkSJekwG6LQ5nt2My98p411sQvJb2eYs \
  --message get_total_supply \
  --suri //Alice \
  --dry-run

Result: 1000000 ✅
```

This demonstrates true **Write-Once, Deploy-Everywhere** capability with a single Quorlin source file deploying to EVM, Solana, and Polkadot ecosystems!
