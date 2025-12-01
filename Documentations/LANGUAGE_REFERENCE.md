# Quorlin Language Reference

Complete guide to Quorlin syntax, features, and semantics.

---

## Table of Contents

1. [Introduction](#introduction)
2. [Basic Syntax](#basic-syntax)
3. [Data Types](#data-types)
4. [Variables and State](#variables-and-state)
5. [Functions](#functions)
6. [Control Flow](#control-flow)
7. [Expressions and Operators](#expressions-and-operators)
8. [Events](#events)
9. [Errors and Error Handling](#errors-and-error-handling)
10. [Decorators](#decorators)
11. [Imports](#imports)
12. [Built-in Globals](#built-in-globals)
13. [Comments and Documentation](#comments-and-documentation)

---

## Introduction

Quorlin is a Python-like smart contract language that compiles to multiple blockchain platforms. This reference describes the complete syntax and semantics of the language.

### Design Philosophy

- **Familiar Syntax**: Uses Python-like syntax wherever possible
- **Type Safety**: Explicit type annotations required for all variables
- **Multi-Chain**: Single codebase compiles to EVM, Solana, and Polkadot
- **Security First**: Built-in guards against common vulnerabilities

---

## Basic Syntax

### Indentation

Quorlin uses Python-style indentation to define blocks:

```python
contract MyContract:
    # Indented block defines contract body
    value: uint256

    fn my_function():
        # Indented block defines function body
        self.value = 100
```

**Rules:**
- Use 4 spaces per indentation level (recommended)
- Mixing tabs and spaces is not allowed
- Indentation must be consistent within a file

### Line Structure

- Statements end at the end of a line
- Multi-line statements can use `\` continuation (coming soon)
- Comments start with `#`

---

## Data Types

### Primitive Types

#### Integer Types

```python
# Unsigned integers
value1: uint8 = 255           # 0 to 255
value2: uint16 = 65535        # 0 to 65,535
value3: uint32 = 4294967295   # 0 to 4,294,967,295
value4: uint64 = 18446744073709551615
value5: uint128               # Very large unsigned integer
value6: uint256               # 256-bit unsigned (most common)

# Signed integers
balance: int256 = -1000       # Signed 256-bit integer
```

**Most Common:** `uint256` for token amounts, balances, etc.

#### Address Type

```python
owner: address = msg.sender
recipient: address = address(0)  # Zero address
```

Represents a blockchain address (20 bytes on EVM, pubkey on Solana, AccountId on Polkadot).

#### Boolean Type

```python
is_active: bool = True
is_paused: bool = False
```

#### String Type

```python
name: str = "Quorlin Token"
symbol: str = "QRL"
```

**Note:** Strings are immutable and have limited support in some blockchain platforms.

#### Bytes Types

```python
data: bytes32 = 0x1234567890abcdef  # Fixed-size bytes
hash_value: bytes32
```

### Complex Types

#### Mapping

Key-value storage structure:

```python
# Simple mapping
balances: mapping[address, uint256]

# Nested mapping
allowances: mapping[address, mapping[address, uint256]]
```

**Usage:**
```python
self.balances[msg.sender] = 1000
amount: uint256 = self.balances[owner]
```

**Notes:**
- Keys are not enumerable
- Default value is zero/empty
- Nested mappings supported

#### List/Array (Coming Soon)

```python
owners: list[address]
values: list[uint256]
```

### Type Conversions

```python
# Explicit conversions
addr: address = address(0)
number: uint256 = uint256(100)
```

---

## Variables and State

### State Variables

Declared at contract level, stored on-chain:

```python
contract Token:
    # State variables
    total_supply: uint256
    owner: address
    balances: mapping[address, uint256]
```

### Local Variables

Declared inside functions, temporary:

```python
fn transfer(to: address, amount: uint256) -> bool:
    # Local variables
    sender_balance: uint256 = self.balances[msg.sender]
    new_balance: uint256 = sender_balance - amount
    return True
```

### Constants

```python
contract MyContract:
    MAX_SUPPLY: uint256 = 1000000  # Constant value
    DECIMALS: uint8 = 18
```

---

## Functions

### Function Definition

```python
fn function_name(param1: type1, param2: type2) -> return_type:
    # Function body
    return value
```

### Constructor

Special function called once during deployment:

```python
@constructor
fn __init__(initial_value: uint256):
    self.total_supply = initial_value
    self.owner = msg.sender
```

### External Functions

Callable from outside the contract:

```python
@external
fn transfer(to: address, amount: uint256) -> bool:
    # Transfer logic
    return True
```

### View Functions

Read-only functions that don't modify state:

```python
@view
fn balance_of(owner: address) -> uint256:
    return self.balances[owner]
```

### Internal Functions

Only callable from within the contract:

```python
fn _internal_helper(value: uint256) -> uint256:
    return value * 2
```

**Convention:** Prefix internal functions with `_`

### Function Parameters

```python
fn example(
    required_param: uint256,           # Required parameter
    default_param: uint256 = 100       # Default value (coming soon)
) -> bool:
    return True
```

### Return Values

```python
# Single return value
fn get_value() -> uint256:
    return 100

# Multiple return values (coming soon)
fn get_values() -> (uint256, address):
    return (100, msg.sender)

# No return value
fn set_value(value: uint256):
    self.value = value
```

---

## Control Flow

### If/Elif/Else

```python
fn check_value(amount: uint256):
    if amount > 100:
        # Large amount
        pass
    elif amount > 50:
        # Medium amount
        pass
    else:
        # Small amount
        pass
```

### While Loops

```python
fn count_down(start: uint256):
    counter: uint256 = start
    while counter > 0:
        # Do something
        counter = counter - 1
```

**Warning:** Be careful with loops on-chain due to gas costs!

### For Loops

```python
fn iterate_range():
    for i in range(10):
        # Loop body
        pass

# With custom range (coming soon)
for i in range(5, 15):
    pass

for i in range(0, 100, 5):  # Step by 5
    pass
```

### Break and Continue (Coming Soon)

```python
while condition:
    if should_skip:
        continue
    if should_exit:
        break
```

---

## Expressions and Operators

### Arithmetic Operators

```python
result = a + b      # Addition
result = a - b      # Subtraction
result = a * b      # Multiplication
result = a / b      # Division
result = a % b      # Modulo
result = a ** b     # Exponentiation (coming soon)
```

**Use safe math functions to prevent overflow:**
```python
from std.math import safe_add, safe_sub, safe_mul

result = safe_add(a, b)
```

### Comparison Operators

```python
a == b      # Equal
a != b      # Not equal
a > b       # Greater than
a >= b      # Greater than or equal
a < b       # Less than
a <= b      # Less than or equal
```

### Logical Operators

```python
condition1 and condition2   # Logical AND
condition1 or condition2    # Logical OR
not condition               # Logical NOT
```

### Assignment Operators

```python
value = 100         # Simple assignment
value += 10         # Add and assign
value -= 10         # Subtract and assign
value *= 2          # Multiply and assign
value /= 2          # Divide and assign
```

### Member Access

```python
self.balances[owner]        # State variable access
msg.sender                  # Global variable access
contract.method()           # Method call
```

### Indexing

```python
balance = self.balances[address]                     # Single index
allowed = self.allowances[owner][spender]            # Nested index
```

---

## Events

### Event Declaration

```python
event Transfer(from_addr: address, to_addr: address, value: uint256)
event Approval(owner: address, spender: address, value: uint256)
```

### Event Emission

```python
fn transfer(to: address, amount: uint256) -> bool:
    # ... transfer logic ...
    emit Transfer(msg.sender, to, amount)
    return True
```

**Usage:**
- Events log important state changes
- Indexed by blockchain explorers
- Used by off-chain applications
- Platform-specific implementation (LOG on EVM, emit! on Solana, env().emit_event() on ink!)

---

## Errors and Error Handling

### Require Statement

Assert a condition, revert if false:

```python
require(condition, "Error message")

# Examples:
require(amount > 0, "Amount must be positive")
require(msg.sender == owner, "Only owner can call")
require(balance >= amount, "Insufficient balance")
```

### Revert Statement

Unconditionally revert transaction:

```python
if invalid_state:
    revert("Invalid state")
```

### Custom Errors (Coming Soon)

```python
error InsufficientBalance(available: uint256, needed: uint256)
error Unauthorized(caller: address)

fn transfer(amount: uint256):
    if self.balances[msg.sender] < amount:
        raise InsufficientBalance(self.balances[msg.sender], amount)
```

---

## Decorators

### @constructor

Marks the contract constructor:

```python
@constructor
fn __init__(initial_value: uint256):
    self.value = initial_value
```

### @external

Marks function as externally callable:

```python
@external
fn public_function():
    pass
```

### @view

Marks function as read-only:

```python
@view
fn get_balance(owner: address) -> uint256:
    return self.balances[owner]
```

### @payable (Coming Soon)

Marks function as able to receive native tokens:

```python
@payable
fn deposit():
    # Can receive ETH/SOL/DOT
    pass
```

### @nonreentrant (Coming Soon)

Protects against reentrancy attacks:

```python
@nonreentrant
fn withdraw(amount: uint256):
    # Safe from reentrancy
    pass
```

---

## Imports

### Standard Library Imports

```python
from std.math import safe_add, safe_sub, safe_mul
from std.access import Ownable
from std.token import ERC20
```

### Module Imports (Coming Soon)

```python
import my_module
from my_package import MyContract
```

---

## Built-in Globals

### Message Context

```python
msg.sender: address     # Transaction sender
msg.value: uint256      # Amount of native token sent (EVM)
```

### Block Context (Coming Soon)

```python
block.timestamp: uint256    # Current block timestamp
block.number: uint256       # Current block number
```

### Contract Context

```python
self                    # Reference to current contract
address(0)             # Zero address constant
```

---

## Comments and Documentation

### Single-line Comments

```python
# This is a comment
value: uint256 = 100  # Inline comment
```

### Documentation Strings

```python
contract Token:
    """
    A standard ERC-20 token implementation.
    This docstring describes the contract.
    """

    fn transfer(to: address, amount: uint256) -> bool:
        """
        Transfer tokens to another address.

        Args:
            to: Recipient address
            amount: Number of tokens to transfer

        Returns:
            True if successful
        """
        return True
```

---

## Complete Example

Here's a complete contract demonstrating all major features:

```python
from std.math import safe_add, safe_sub

event Transfer(from_addr: address, to_addr: address, value: uint256)
event Approval(owner: address, spender: address, value: uint256)

contract CompleteToken:
    """A complete token implementation."""

    # State variables
    name: str = "Complete Token"
    symbol: str = "CMP"
    decimals: uint8 = 18
    total_supply: uint256
    owner: address

    # Mappings
    balances: mapping[address, uint256]
    allowances: mapping[address, mapping[address, uint256]]

    @constructor
    fn __init__(initial_supply: uint256):
        """Initialize the token."""
        self.total_supply = initial_supply
        self.owner = msg.sender
        self.balances[msg.sender] = initial_supply
        emit Transfer(address(0), msg.sender, initial_supply)

    @view
    fn balance_of(account: address) -> uint256:
        """Get token balance."""
        return self.balances[account]

    @view
    fn allowance(owner: address, spender: address) -> uint256:
        """Get spending allowance."""
        return self.allowances[owner][spender]

    @external
    fn transfer(to: address, amount: uint256) -> bool:
        """Transfer tokens."""
        require(to != address(0), "Invalid recipient")
        require(self.balances[msg.sender] >= amount, "Insufficient balance")

        self.balances[msg.sender] = safe_sub(self.balances[msg.sender], amount)
        self.balances[to] = safe_add(self.balances[to], amount)

        emit Transfer(msg.sender, to, amount)
        return True

    @external
    fn approve(spender: address, amount: uint256) -> bool:
        """Approve spending allowance."""
        require(spender != address(0), "Invalid spender")

        self.allowances[msg.sender][spender] = amount
        emit Approval(msg.sender, spender, amount)
        return True

    @external
    fn transfer_from(from_addr: address, to: address, amount: uint256) -> bool:
        """Transfer tokens using allowance."""
        require(to != address(0), "Invalid recipient")
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

    fn _only_owner():
        """Internal: Check if caller is owner."""
        require(msg.sender == self.owner, "Not owner")
```

---

## Best Practices

### 1. Use Type Annotations

```python
# ✅ Good
balance: uint256 = 100

# ❌ Bad
balance = 100
```

### 2. Use Safe Math

```python
# ✅ Good
from std.math import safe_add
result = safe_add(a, b)

# ❌ Bad (can overflow)
result = a + b
```

### 3. Check Conditions Early

```python
# ✅ Good
fn transfer(to: address, amount: uint256) -> bool:
    require(to != address(0), "Invalid address")
    require(amount > 0, "Invalid amount")
    # ... rest of logic

# ❌ Bad
fn transfer(to: address, amount: uint256) -> bool:
    # ... lots of processing ...
    if to == address(0):
        revert("Invalid address")
```

### 4. Use Events for Important State Changes

```python
# ✅ Good
fn update_value(new_value: uint256):
    old_value: uint256 = self.value
    self.value = new_value
    emit ValueUpdated(old_value, new_value)
```

### 5. Follow Naming Conventions

- `snake_case` for functions and variables
- `UPPER_CASE` for constants
- `_prefix` for internal functions
- Descriptive names over abbreviations

---

## Platform Differences

Quorlin abstracts most platform differences, but some remain:

| Feature | EVM | Solana | Polkadot |
|---------|-----|--------|----------|
| uint256 | ✅ Native | ⚠️ Maps to u128 | ✅ Via U256 |
| msg.value | ✅ Yes | ❌ Different model | ✅ Yes |
| Events | LOG opcodes | emit! macro | env().emit_event() |
| Mappings | Storage slots | HashMap | ink::storage::Mapping |

---

## Further Reading

- [Standard Library Reference](STDLIB_REFERENCE.md)
- [Tutorials](TUTORIALS.md)
- [Architecture Guide](ARCHITECTURE.md)
- [Deployment Guide](DEPLOYMENT_GUIDE.md)

---

*Last Updated: 2025-11-30*
