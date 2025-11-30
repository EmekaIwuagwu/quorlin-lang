# Getting Started with Quorlin

This guide will walk you through writing, compiling, and deploying your first Quorlin smart contract to Ethereum, Solana, and Polkadot.

## Prerequisites

- Rust 1.70+ (`rustup` recommended)
- Basic understanding of smart contracts
- Familiarity with Python syntax (helpful but not required)

## Installation

### 1. Clone and Build

```bash
git clone https://github.com/yourusername/quorlin-lang.git
cd quorlin-lang
cargo build --release
```

### 2. Add to PATH

```bash
# Linux/macOS
export PATH="$PWD/target/release:$PATH"

# Add to ~/.bashrc or ~/.zshrc to make permanent
echo 'export PATH="/path/to/quorlin-lang/target/release:$PATH"' >> ~/.bashrc
```

### 3. Verify Installation

```bash
qlc --version
# Should output: qlc 0.1.0
```

## Your First Contract: SimpleStorage

Let's create a simple storage contract that works on all three platforms.

### Step 1: Create the Contract

Create a file called `storage.ql`:

```python
contract SimpleStorage:
    """
    A simple storage contract that stores a single number.
    Demonstrates basic state management across chains.
    """

    stored_value: uint256

    @constructor
    def __init__(initial_value: uint256):
        """Initialize with a starting value."""
        self.stored_value = initial_value

    @external
    def set(new_value: uint256):
        """Update the stored value."""
        self.stored_value = new_value

    @view
    def get() -> uint256:
        """Retrieve the stored value."""
        return self.stored_value
```

### Step 2: Compile for Ethereum/EVM

```bash
qlc compile storage.ql --target evm -o storage.yul
```

This generates Yul code that can be compiled with `solc`:

```bash
# Compile Yul to bytecode
solc --strict-assembly storage.yul --bin
```

### Step 3: Compile for Solana

```bash
qlc compile storage.ql --target solana -o storage_solana.rs
```

This generates an Anchor program. To build it:

```bash
# Create Anchor project structure
anchor init my_storage
cp storage_solana.rs my_storage/programs/my_storage/src/lib.rs
cd my_storage
anchor build
```

### Step 4: Compile for Polkadot

```bash
qlc compile storage.ql --target ink -o storage_ink.rs
```

This generates ink! code. To build it:

```bash
# Create cargo-contract project
cargo contract new my_storage
cp storage_ink.rs my_storage/lib.rs
cd my_storage
cargo contract build
```

## Advanced Example: Token Contract

Now let's build a real-world token with all the features.

Create `my_token.ql`:

```python
from std.math import safe_add, safe_sub

event Transfer(from_addr: address, to_addr: address, value: uint256)
event Approval(owner: address, spender: address, value: uint256)

contract MyToken:
    """
    A complete ERC-20 compatible token.
    Works on Ethereum, Solana, and Polkadot!
    """

    # Token metadata
    name: str = "My Token"
    symbol: str = "MTK"
    decimals: uint8 = 18
    total_supply: uint256

    # Token balances and allowances
    balances: mapping[address, uint256]
    allowances: mapping[address, mapping[address, uint256]]

    @constructor
    def __init__(initial_supply: uint256):
        """Mint initial supply to deployer."""
        self.total_supply = initial_supply
        self.balances[msg.sender] = initial_supply
        emit Transfer(address(0), msg.sender, initial_supply)

    @view
    def balance_of(owner: address) -> uint256:
        """Get balance of an address."""
        return self.balances[owner]

    @view
    def allowance(owner: address, spender: address) -> uint256:
        """Get allowance for spender."""
        return self.allowances[owner][spender]

    @external
    def transfer(to: address, amount: uint256) -> bool:
        """Transfer tokens to another address."""
        require(to != address(0), "Cannot transfer to zero address")
        require(self.balances[msg.sender] >= amount, "Insufficient balance")

        self.balances[msg.sender] = safe_sub(self.balances[msg.sender], amount)
        self.balances[to] = safe_add(self.balances[to], amount)

        emit Transfer(msg.sender, to, amount)
        return True

    @external
    def approve(spender: address, amount: uint256) -> bool:
        """Approve spender to transfer tokens."""
        require(spender != address(0), "Cannot approve zero address")

        self.allowances[msg.sender][spender] = amount
        emit Approval(msg.sender, spender, amount)
        return True

    @external
    def transfer_from(from_addr: address, to: address, amount: uint256) -> bool:
        """Transfer tokens using allowance."""
        require(to != address(0), "Cannot transfer to zero address")
        require(self.balances[from_addr] >= amount, "Insufficient balance")
        require(self.allowances[from_addr][msg.sender] >= amount, "Insufficient allowance")

        self.balances[from_addr] = safe_sub(self.balances[from_addr], amount)
        self.balances[to] = safe_add(self.balances[to], amount)
        self.allowances[from_addr][msg.sender] = safe_sub(
            self.allowances[from_addr][msg.sender],
            amount
        )

        emit Transfer(from_addr, to, amount)
        return True
```

### Compile to All Platforms

```bash
# EVM
qlc compile my_token.ql --target evm -o my_token.yul

# Solana
qlc compile my_token.ql --target solana -o my_token_solana.rs

# Polkadot
qlc compile my_token.ql --target ink -o my_token_ink.rs
```

## Using the Standard Library

Quorlin comes with a comprehensive standard library.

### Safe Math

```python
from std.math import safe_add, safe_sub, safe_mul, safe_div

contract Calculator:
    @external
    def calculate(a: uint256, b: uint256) -> uint256:
        # All operations are overflow-safe
        result: uint256 = safe_mul(a, b)
        result = safe_add(result, 100)
        return safe_div(result, 2)
```

### Access Control

```python
from std.access import Ownable

contract AdminContract(Ownable):
    """Only owner can call sensitive functions."""

    @external
    def sensitive_operation():
        self._only_owner()  # Reverts if caller is not owner
        # ... do sensitive stuff

    @external
    def change_owner(new_owner: address):
        self.transfer_ownership(new_owner)
```

### Role-Based Access Control

```python
from std.access import AccessControl

contract MultiAdmin(AccessControl):
    """Multiple roles for different permissions."""

    MINTER_ROLE: bytes32 = 0x01
    BURNER_ROLE: bytes32 = 0x02

    @external
    def mint(to: address, amount: uint256):
        self._check_role(self.MINTER_ROLE)
        # Only accounts with MINTER_ROLE can mint

    @external
    def burn(from_addr: address, amount: uint256):
        self._check_role(self.BURNER_ROLE)
        # Only accounts with BURNER_ROLE can burn

    @external
    def grant_minter(account: address):
        self._check_role(self.DEFAULT_ADMIN_ROLE)
        self.grant_role(self.MINTER_ROLE, account)
```

## CLI Reference

### Compile

```bash
qlc compile <file> --target <platform> -o <output>

# Platforms: evm, solana, ink (or polkadot)
# Examples:
qlc compile contract.ql --target evm
qlc compile contract.ql --target solana -o program.rs
```

### Type Check

```bash
# Check for errors without generating code
qlc check contract.ql
```

### Parse/Debug

```bash
# View tokens
qlc tokenize contract.ql

# View AST
qlc parse contract.ql
```

### Format (Coming Soon)

```bash
# Auto-format code
qlc fmt contract.ql
```

## Platform-Specific Notes

### Ethereum/EVM

- Generated Yul code can be compiled with `solc --strict-assembly`
- Compatible with all EVM chains (Ethereum, Polygon, BSC, etc.)
- Function selectors use simplified hashing (full keccak256 coming soon)

### Solana

- Generates Anchor framework code
- `uint256` maps to `u128` (Solana doesn't support 256-bit integers)
- Mappings become `HashMap` in account data
- Requires Anchor CLI to build: `anchor build`

### Polkadot

- Generates ink! smart contract code
- Full `U256` support via scale-info
- Mappings become `ink::storage::Mapping`
- Build with: `cargo contract build`

## Next Steps

- Explore [example contracts](examples/) for more patterns
- Read the [Language Reference](docs/LANGUAGE.md) for full syntax
- Check out [Standard Library docs](stdlib/README.md)
- Join our [Discord](https://discord.gg/quorlin) for help

## Common Issues

### "Contract not found" error

Make sure your contract is properly defined:

```python
contract MyContract:  # Must have colon and indentation
    # content here
    pass
```

### Type errors

All variables need type annotations:

```python
# ❌ Wrong
value = 100

# ✅ Correct
value: uint256 = 100
```

### Import errors

Standard library imports should use absolute paths:

```python
# ✅ Correct
from std.math import safe_add

# ❌ Wrong (relative imports not supported yet)
from ..math import safe_add
```

## Getting Help

- 📖 [Documentation](docs/)
- 💬 [Discord Community](https://discord.gg/quorlin)
- 🐛 [GitHub Issues](https://github.com/yourusername/quorlin-lang/issues)
- 📧 [Email Support](mailto:support@quorlin.dev)

---

**Happy coding! 🚀**
