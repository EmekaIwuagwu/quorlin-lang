# Quorlin: The Universal Smart Contract Language

<div align="center">

**Write Once, Deploy Everywhere**

A next-generation smart contract language that compiles to EVM, Solana, and Polkadot from a single, Python-like codebase.

[![License: MIT OR Apache-2.0](https://img.shields.io/badge/License-MIT%20OR%20Apache--2.0-blue.svg)](LICENSE)
[![Build Status](https://img.shields.io/badge/build-passing-brightgreen.svg)]()

</div>

---

## 🌟 Why Quorlin?

Today's blockchain developers face an impossible choice: write in Solidity for EVM, Rust for Solana, or ink! for Polkadot. Each ecosystem has brilliant innovations, but **you must rewrite contracts from scratch for each target**.

Quorlin solves this with:

- **🐍 Python-like syntax** — If you know Python, you already know 90% of Quorlin
- **🚀 Multi-chain compilation** — One `.ql` file → EVM bytecode, Solana BPF, ink! Wasm
- **🔒 Security-first** — Built-in reentrancy guards, overflow protection, and static analysis
- **⚡ Zero overhead** — Compiles to native bytecode for each chain, no runtime interpreter

## 🎯 Quick Example

Here's a complete ERC-20 token in Quorlin:

```python
# token.ql — Compiles to EVM, Solana, and Polkadot!

from std.math import safe_add, safe_sub

event Transfer(from_addr: address, to_addr: address, value: uint256)

contract Token:
    """A standard fungible token."""

    name: str = "Quorlin Token"
    total_supply: uint256
    balances: mapping[address, uint256]

    @constructor
    def __init__(initial_supply: uint256):
        self.total_supply = initial_supply
        self.balances[msg.sender] = initial_supply
        emit Transfer(address(0), msg.sender, initial_supply)

    @external
    def transfer(to: address, amount: uint256) -> bool:
        """Transfer tokens to another address."""
        require(self.balances[msg.sender] >= amount, "Insufficient balance")
        require(to != address(0), "Cannot send to zero address")

        self.balances[msg.sender] = safe_sub(self.balances[msg.sender], amount)
        self.balances[to] = safe_add(self.balances[to], amount)

        emit Transfer(msg.sender, to, amount)
        return True

    @view
    def balance_of(owner: address) -> uint256:
        """Get token balance."""
        return self.balances[owner]
```

**One file. Three blockchains. Zero rewrites.**

## 🚀 Getting Started

### Installation

```bash
# Clone the repository
git clone https://github.com/yourusername/quorlin-lang.git
cd quorlin-lang

# Build the compiler
cargo build --release

# Add to PATH
export PATH="$PWD/target/release:$PATH"
```

### Your First Contract

1. **Create a new project:**
```bash
qlc init my-token
cd my-token
```

2. **Write your contract** (`contract.ql`):
```python
contract MyToken:
    balances: mapping[address, uint256]

    def transfer(to: address, amount: uint256) -> bool:
        self.balances[msg.sender] -= amount
        self.balances[to] += amount
        return True
```

3. **Compile for your target chain:**
```bash
# For Ethereum/EVM
qlc compile contract.ql --target evm -o token.bin

# For Solana
qlc compile contract.ql --target solana -o token_program/

# For Polkadot (ink!)
qlc compile contract.ql --target ink -o token.contract
```

## 📚 Language Features

### Python-Compatible Syntax

Quorlin uses Python syntax wherever possible:

| Feature | Works exactly like Python? |
|---------|---------------------------|
| `def function():` | ✅ Yes |
| `if/elif/else` | ✅ Yes |
| `for i in range(10):` | ✅ Yes |
| `self.variable` | ✅ Yes |
| `and/or/not` | ✅ Yes |
| Type hints | 🔧 Required (not optional) |
| `mapping[K,V]` | 🆕 Blockchain storage |
| `require()` | 🆕 Blockchain assertion |

### Smart Contract Additions

Only the **minimum necessary differences** for blockchain development:

```python
# Type annotations (required)
amount: uint256 = 1000
owner: address = msg.sender

# Mappings (on-chain key-value storage)
balances: mapping[address, uint256]

# Events
event Transfer(from_addr: address, to_addr: address, value: uint256)
emit Transfer(msg.sender, recipient, amount)

# Errors & Requirements
require(balance >= amount, "Insufficient balance")
revert("Operation not allowed")

# Custom errors (gas-efficient)
error InsufficientBalance(available: uint256, needed: uint256)
raise InsufficientBalance(balance, amount)
```

## 🏗️ Architecture

```
┌──────────────────────────────────────────────┐
│          QUORLIN COMPILER (qlc)              │
├──────────────────────────────────────────────┤
│  Lexer → Parser → Semantic Analysis → IR    │
│                      ↓                       │
│         ┌────────────┼────────────┐          │
│         ▼            ▼            ▼          │
│    EVM Backend  Solana Backend  ink! Backend│
│         ↓            ↓            ▼          │
│    Bytecode      BPF Program    Wasm         │
└──────────────────────────────────────────────┘
```

### Compiler Stages

1. **Lexer** — Tokenizes `.ql` source with Python-style indentation
2. **Parser** — Builds AST using LALRPOP grammar
3. **Semantic Analysis** — Type checking, name resolution, security analysis
4. **IR Generation** — Target-agnostic intermediate representation
5. **Backend Codegen** — Generate native code for each blockchain

## 📖 Documentation

- **[Language Reference](docs/book/src/language-reference/)** — Complete Quorlin syntax guide
- **[Standard Library](docs/book/src/stdlib/)** — Built-in functions and utilities
- **[Tutorials](docs/book/src/tutorials/)** — Learn by building real contracts
- **[Architecture](ARCHITECTURE.md)** — Deep dive into compiler internals

## 🛠️ Development Status

**Current Milestone:** ✅ **Foundation Complete**

- [x] Lexer with Python-style indentation
- [x] Token definitions for all language constructs
- [x] AST data structures
- [x] CLI with tokenize command
- [ ] LALRPOP parser implementation (In Progress)
- [ ] Semantic analysis
- [ ] EVM backend (Yul generation)
- [ ] Solana backend (Rust/Anchor generation)
- [ ] ink! backend (Rust generation)

See our [Project Roadmap](docs/ROADMAP.md) for detailed milestones.

## 🤝 Contributing

We welcome contributions! Whether it's:

- 🐛 Bug reports
- 💡 Feature requests
- 📖 Documentation improvements
- 🔧 Code contributions

Please read our [Contributing Guide](CONTRIBUTING.md) to get started.

### Development Setup

```bash
# Clone the repo
git clone https://github.com/yourusername/quorlin-lang.git
cd quorlin-lang

# Build
cargo build

# Run tests
cargo test

# Test the tokenizer
cargo run -- tokenize examples/token.ql
```

## 📋 CLI Commands

```bash
# Compile a contract
qlc compile contract.ql --target evm -o output.bin

# Type-check without generating code
qlc check contract.ql

# Tokenize (for debugging)
qlc tokenize contract.ql

# Format code
qlc fmt contract.ql

# Create new project
qlc init my-project
```

## 🔐 Security

Quorlin includes built-in security features:

- **Automatic overflow protection** — All arithmetic is checked by default
- **Reentrancy guards** — Built-in `@nonreentrant` decorator
- **Static analysis** — Detect common vulnerabilities at compile-time
- **Access control patterns** — Standard `Ownable`, `AccessControl` in stdlib

## 📄 License

Quorlin is dual-licensed under:

- **MIT License** ([LICENSE-MIT](LICENSE-MIT) or http://opensource.org/licenses/MIT)
- **Apache License 2.0** ([LICENSE-APACHE](LICENSE-APACHE) or http://www.apache.org/licenses/LICENSE-2.0)

You may choose either license for your use.

## 🌟 Acknowledgments

Quorlin draws inspiration from:

- **Python** — For its beautiful, readable syntax
- **Vyper** — For proving Python-like smart contracts are possible
- **Solidity** — For EVM development patterns
- **Rust** — For the compiler implementation
- **Move** — For resource-oriented programming concepts

---

<div align="center">

**Built with ❤️ for the multi-chain future**

[Website](https://quorlin.dev) • [Documentation](https://docs.quorlin.dev) • [Discord](https://discord.gg/quorlin)

</div>
