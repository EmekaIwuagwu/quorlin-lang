# Quorlin Standard Library

The Quorlin Standard Library provides reusable, audited contract modules for common smart contract patterns.

**Phase 9 Enhanced**: Now includes cryptography, time utilities, logging, and universal token standards!

## Core Modules

### Math (`std.math`)

Safe arithmetic operations with overflow/underflow protection:

- `safe_add(a, b)` - Safe addition
- `safe_sub(a, b)` - Safe subtraction
- `safe_mul(a, b)` - Safe multiplication
- `safe_div(a, b)` - Safe division
- `safe_mod(a, b)` - Safe modulo
- `safe_pow(base, exp)` - Safe exponentiation
- `min(a, b)` - Minimum of two values
- `max(a, b)` - Maximum of two values
- `average(a, b)` - Average of two values

**Example**:
```quorlin
from std.math import safe_add, safe_mul

fn calculate_total(price: uint256, quantity: uint256) -> uint256:
    return safe_mul(price, quantity)
```

### Cryptography (`std.crypto`) ✨ NEW

Cross-chain cryptographic primitives:

**Hashing**:
- `sha256(data)` - SHA-256 hash
- `keccak256(data)` - Keccak-256 hash (Ethereum standard)
- `blake2_256(data)` - BLAKE2b-256 hash (Polkadot standard)
- `ripemd160(data)` - RIPEMD-160 hash

**Signatures**:
- `verify_ecdsa_signature(hash, signature, pubkey)` - Verify ECDSA signature
- `recover_ecdsa_signer(hash, signature)` - Recover signer address
- `verify_ed25519_signature(message, signature, pubkey)` - Verify Ed25519 signature

**Merkle Trees**:
- `merkle_root(leaves)` - Compute Merkle root
- `verify_merkle_proof(leaf, proof, root, index)` - Verify Merkle proof

**Example**:
```quorlin
from std.crypto import keccak256, verify_merkle_proof

fn verify_airdrop_claim(
    account: address,
    amount: uint256,
    proof: list[bytes32],
    root: bytes32
) -> bool:
    leaf: bytes32 = keccak256(encode(account, amount))
    return verify_merkle_proof(leaf, proof, root, 0)
```

### Time & Block Utilities (`std.time`) ✨ NEW

Access to blockchain time and block information:

**Block Information**:
- `block_timestamp()` - Current block timestamp (Unix time)
- `block_number()` - Current block number
- `chain_id()` - Current chain ID
- `block_difficulty()` - Block difficulty (EVM)
- `coinbase()` - Block producer address

**Time Utilities**:
- `is_past(timestamp)` - Check if timestamp is in the past
- `is_future(timestamp)` - Check if timestamp is in the future
- `time_until(timestamp)` - Seconds until future timestamp
- `time_since(timestamp)` - Seconds since past timestamp

**Time Arithmetic**:
- `add_seconds(timestamp, seconds)` - Add seconds to timestamp
- `add_minutes(timestamp, minutes)` - Add minutes
- `add_hours(timestamp, hours)` - Add hours
- `add_days(timestamp, days)` - Add days
- `add_weeks(timestamp, weeks)` - Add weeks

**Constants**:
- `MINUTE`, `HOUR`, `DAY`, `WEEK`, `MONTH`, `YEAR`

**Example**:
```quorlin
from std.time import block_timestamp, add_days, is_past

contract Auction:
    end_time: uint64
    
    @constructor
    fn __init__(duration_days: uint64):
        self.end_time = add_days(block_timestamp(), duration_days)
    
    @view
    fn is_ended() -> bool:
        return is_past(self.end_time)
```

### Logging & Events (`std.log`) ✨ NEW

Event emission, logging, and assertion utilities:

**Event Emission**:
- `emit_event(name, data)` - Emit generic event
- `emit_indexed_event(name, indexed_data, data)` - Emit indexed event

**Logging** (development only):
- `log_debug(message)` - Debug log
- `log_info(message)` - Info log
- `log_warning(message)` - Warning log
- `log_error(message)` - Error log
- `log_value(label, value)` - Log labeled value
- `log_address(label, addr)` - Log labeled address

**Assertions**:
- `require(condition, message)` - Assert condition or revert
- `require_not_zero_address(addr, message)` - Require non-zero address
- `require_positive(value, message)` - Require value > 0
- `require_equal(a, b, message)` - Require a == b
- `require_greater_than(a, b, message)` - Require a > b
- `require_less_or_equal(a, b, message)` - Require a <= b

**Revert**:
- `revert(message)` - Revert transaction with message
- `revert_with_code(code, message)` - Revert with error code

**Example**:
```quorlin
from std.log import require, require_not_zero_address, emit_event

fn transfer(to: address, amount: uint256):
    require_not_zero_address(to, "Invalid recipient")
    require(amount > 0, "Amount must be positive")
    
    # ... transfer logic ...
    
    emit_event("Transfer", encode(msg.sender, to, amount))
```

### Access Control (`std.access`)

#### Ownable

Single-owner access control pattern:

```quorlin
from std.access import Ownable

contract MyContract(Ownable):
    @external
    fn admin_function():
        self._only_owner()
        # Only owner can execute
        pass
```

#### AccessControl

Role-based access control with multiple roles:

```quorlin
from std.access import AccessControl

contract MyContract(AccessControl):
    MINTER_ROLE: bytes32 = 0x01

    @external
    fn mint(to: address, amount: uint256):
        self._check_role(self.MINTER_ROLE)
        # Only minters can execute
        pass
```

## Token Standards

### StandardToken (`std.token.standard_token`) ✨ NEW

Universal fungible token implementation (ERC-20 compatible):

**Features**:
- Complete ERC-20 interface (transfer, approve, transferFrom)
- Minting and burning
- Pausable functionality
- Ownership management
- Allowance management (increaseAllowance, decreaseAllowance)

**Compiles to**:
- ERC-20 (EVM/Avalanche)
- SPL Token (Solana)
- PSP22 (Polkadot)
- Fungible Asset (Aptos)
- ERC-20-like (StarkNet)

**Example**:
```quorlin
from std.token.standard_token import StandardToken

contract MyToken(StandardToken):
    @constructor
    fn __init__():
        StandardToken.__init__(
            "My Token",      # name
            "MTK",           # symbol
            18,              # decimals
            1000000          # initial supply
        )
```

### ERC20 (`std.token.erc20`)

Standard fungible token implementation (original):

```quorlin
from std.token import ERC20

contract MyToken(ERC20):
    @constructor
    fn __init__():
        ERC20.__init__("My Token", "MTK", 18)
        self._mint(msg.sender, 1000000)
```

### Errors (`std.errors`)

Standard error definitions for consistent error handling across contracts.

## Usage Examples

### Complete Contract Example

```quorlin
from std.math import safe_add, safe_sub
from std.time import block_timestamp, add_days
from std.log import require, require_not_zero_address, emit_event
from std.crypto import keccak256

contract Crowdsale:
    token: address
    rate: uint256  # tokens per wei
    end_time: uint64
    raised: uint256
    
    event TokensPurchased(buyer: address, amount: uint256, cost: uint256)
    
    @constructor
    fn __init__(token_address: address, token_rate: uint256, duration_days: uint64):
        require_not_zero_address(token_address, "Invalid token")
        require(token_rate > 0, "Invalid rate")
        
        self.token = token_address
        self.rate = token_rate
        self.end_time = add_days(block_timestamp(), duration_days)
        self.raised = 0
    
    @payable
    @external
    fn buy_tokens():
        require(block_timestamp() < self.end_time, "Crowdsale ended")
        require(msg.value > 0, "Must send ETH")
        
        tokens: uint256 = safe_mul(msg.value, self.rate)
        self.raised = safe_add(self.raised, msg.value)
        
        # Transfer tokens to buyer
        transfer_tokens(self.token, msg.sender, tokens)
        
        emit_event("TokensPurchased", encode(msg.sender, tokens, msg.value))
```

### Import Best Practices

```quorlin
# Import only what you need
from std.math import safe_add, safe_mul
from std.log import require

# Import multiple items from same module
from std.crypto import keccak256, verify_merkle_proof, merkle_root

# Import entire module (if using many functions)
from std.time import *
```

## Cross-Chain Compatibility

All standard library modules compile to:
- **EVM** (Ethereum, Polygon, BSC, Arbitrum, Optimism): Solidity-compatible bytecode via Yul
- **Solana**: Anchor program Rust code
- **Polkadot** (Substrate): ink! smart contract Rust code
- **Aptos**: Move language
- **StarkNet**: Cairo language
- **Avalanche**: EVM-compatible Solidity

The same Quorlin code works across all platforms!

### Backend-Specific Notes

Each stdlib function includes documentation on how it's implemented on different chains:

```quorlin
fn sha256(data: bytes) -> bytes32:
    """
    Backend implementations:
    - EVM: Precompiled contract at address 0x02
    - Solana: solana_program::hash::sha256
    - Polkadot: ink::env::hash_bytes with SHA-256
    - Aptos: std::hash::sha2_256
    - StarkNet: core::sha256
    - Avalanche: Precompiled contract (EVM-compatible)
    """
```

## Module Organization

```
stdlib/
├── std/                    # New Phase 9 structure
│   ├── crypto.ql          # Cryptographic primitives
│   ├── time.ql            # Time and block utilities
│   ├── log.ql             # Logging and assertions
│   └── token/
│       └── standard_token.ql  # Universal token standard
│
├── math/                   # Original structure
│   └── safe_math.ql       # Safe arithmetic
├── token/
│   └── erc20.ql           # ERC-20 implementation
├── access/
│   ├── ownable.ql         # Ownership pattern
│   └── access_control.ql  # Role-based access
└── errors.ql              # Standard errors
```

## Security Considerations

### Safe Arithmetic
Always use `safe_*` functions from `std.math` to prevent overflow/underflow:

```quorlin
# ❌ BAD - can overflow
total = a + b

# ✅ GOOD - safe arithmetic
total = safe_add(a, b)
```

### Input Validation
Use `require` functions from `std.log`:

```quorlin
from std.log import require, require_not_zero_address, require_positive

fn transfer(to: address, amount: uint256):
    require_not_zero_address(to, "Invalid recipient")
    require_positive(amount, "Amount must be positive")
    # ... transfer logic ...
```

### Checks-Effects-Interactions Pattern
Update state before external calls:

```quorlin
# ✅ GOOD - state updated first
self.balances[msg.sender] = safe_sub(self.balances[msg.sender], amount)
self.balances[to] = safe_add(self.balances[to], amount)
emit Transfer(msg.sender, to, amount)  # Event last
```

## Contributing

To add new stdlib modules:

1. Create `.ql` file in appropriate `stdlib/std/` subdirectory
2. Use compiler intrinsics (`pass`) for platform-specific operations
3. Document all functions with docstrings
4. Include backend-specific implementation notes
5. Add usage examples
6. Update this README

## License

MIT License - See LICENSE file for details
