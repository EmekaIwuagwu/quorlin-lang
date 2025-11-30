# Quorlin Standard Library Reference

Complete reference for all standard library modules and functions.

---

## Table of Contents

1. [Overview](#overview)
2. [Math Module (std.math)](#math-module-stdmath)
3. [Access Control Module (std.access)](#access-control-module-stdaccess)
4. [Token Module (std.token)](#token-module-stdtoken)
5. [Errors Module (std.errors)](#errors-module-stderrors)
6. [Usage Examples](#usage-examples)

---

## Overview

The Quorlin standard library provides battle-tested, audited modules for common smart contract patterns. All modules are:

- ✅ **Cross-Platform**: Work on EVM, Solana, and Polkadot
- ✅ **Security Audited**: Follow best practices
- ✅ **Gas Optimized**: Efficient implementations
- ✅ **Well Documented**: Clear usage examples

### Importing from Standard Library

```python
# Import specific functions
from std.math import safe_add, safe_sub

# Import entire module (coming soon)
import std.math

# Import classes/contracts
from std.access import Ownable
from std.token import ERC20
```

---

## Math Module (std.math)

**Location:** `stdlib/math/safe_math.ql`

Provides overflow-safe arithmetic operations. **Always use these instead of raw operators** for financial calculations.

### safe_add

```python
fn safe_add(a: uint256, b: uint256) -> uint256
```

**Description:** Addition with overflow protection.

**Parameters:**
- `a`: First operand
- `b`: Second operand

**Returns:** Sum of a and b

**Reverts:** If result would overflow uint256

**Example:**
```python
from std.math import safe_add

fn deposit(amount: uint256):
    self.total_deposits = safe_add(self.total_deposits, amount)
```

---

### safe_sub

```python
fn safe_sub(a: uint256, b: uint256) -> uint256
```

**Description:** Subtraction with underflow protection.

**Parameters:**
- `a`: Minuend (value to subtract from)
- `b`: Subtrahend (value to subtract)

**Returns:** Difference of a and b

**Reverts:** If b > a (underflow)

**Example:**
```python
from std.math import safe_sub

fn withdraw(amount: uint256):
    self.balances[msg.sender] = safe_sub(self.balances[msg.sender], amount)
```

---

### safe_mul

```python
fn safe_mul(a: uint256, b: uint256) -> uint256
```

**Description:** Multiplication with overflow protection.

**Parameters:**
- `a`: First factor
- `b`: Second factor

**Returns:** Product of a and b

**Reverts:** If result would overflow uint256

**Example:**
```python
from std.math import safe_mul

fn calculate_fee(amount: uint256, rate: uint256) -> uint256:
    return safe_mul(amount, rate) / 10000  # Basis points
```

---

### safe_div

```python
fn safe_div(a: uint256, b: uint256) -> uint256
```

**Description:** Division with zero-check.

**Parameters:**
- `a`: Dividend
- `b`: Divisor

**Returns:** Quotient of a / b

**Reverts:** If b is zero

**Example:**
```python
from std.math import safe_div

fn calculate_average(total: uint256, count: uint256) -> uint256:
    return safe_div(total, count)
```

---

### safe_mod

```python
fn safe_mod(a: uint256, b: uint256) -> uint256
```

**Description:** Modulo operation with zero-check.

**Parameters:**
- `a`: Dividend
- `b`: Modulus

**Returns:** Remainder of a % b

**Reverts:** If b is zero

**Example:**
```python
from std.math import safe_mod

fn is_even(value: uint256) -> bool:
    return safe_mod(value, 2) == 0
```

---

### safe_pow

```python
fn safe_pow(base: uint256, exponent: uint256) -> uint256
```

**Description:** Exponentiation with overflow protection.

**Parameters:**
- `base`: Base value
- `exponent`: Exponent

**Returns:** base raised to the power of exponent

**Reverts:** If result would overflow uint256

**Example:**
```python
from std.math import safe_pow

fn calculate_compound_interest(principal: uint256, periods: uint256) -> uint256:
    multiplier: uint256 = safe_pow(105, periods)  # 5% per period
    return safe_mul(principal, multiplier) / safe_pow(100, periods)
```

---

### min

```python
fn min(a: uint256, b: uint256) -> uint256
```

**Description:** Returns the smaller of two values.

**Parameters:**
- `a`: First value
- `b`: Second value

**Returns:** Minimum of a and b

**Example:**
```python
from std.math import min

fn withdraw(requested: uint256):
    available: uint256 = self.balances[msg.sender]
    amount: uint256 = min(requested, available)
    # ... withdraw amount ...
```

---

### max

```python
fn max(a: uint256, b: uint256) -> uint256
```

**Description:** Returns the larger of two values.

**Parameters:**
- `a`: First value
- `b`: Second value

**Returns:** Maximum of a and b

**Example:**
```python
from std.math import max

fn set_minimum_value(new_value: uint256):
    self.value = max(new_value, self.MIN_THRESHOLD)
```

---

### average

```python
fn average(a: uint256, b: uint256) -> uint256
```

**Description:** Returns the average of two values (overflow-safe).

**Parameters:**
- `a`: First value
- `b`: Second value

**Returns:** (a + b) / 2, computed safely

**Example:**
```python
from std.math import average

fn get_mid_price(price1: uint256, price2: uint256) -> uint256:
    return average(price1, price2)
```

---

## Access Control Module (std.access)

**Location:** `stdlib/access/`

Provides access control patterns for restricting function access.

### Ownable

**Location:** `stdlib/access/ownable.ql`

Single-owner access control pattern.

#### Contract Inheritance

```python
from std.access import Ownable

contract MyContract(Ownable):
    # Automatically gets owner state variable and functions
    pass
```

#### State Variables

```python
owner: address  # Current contract owner
```

#### Events

```python
event OwnershipTransferred(previous_owner: address, new_owner: address)
```

#### Functions

##### _only_owner

```python
fn _only_owner()
```

**Description:** Internal function to check if caller is owner. Call at the start of owner-only functions.

**Reverts:** If msg.sender is not the owner

**Example:**
```python
@external
fn admin_function():
    self._only_owner()  # Reverts if not owner
    # ... admin logic ...
```

---

##### get_owner

```python
@view
fn get_owner() -> address
```

**Description:** Get the current owner address.

**Returns:** Owner address

---

##### transfer_ownership

```python
@external
fn transfer_ownership(new_owner: address)
```

**Description:** Transfer ownership to a new address.

**Parameters:**
- `new_owner`: Address of new owner

**Reverts:** If caller is not current owner or new_owner is zero address

**Emits:** `OwnershipTransferred` event

---

##### renounce_ownership

```python
@external
fn renounce_ownership()
```

**Description:** Remove owner, making contract ownerless.

**Reverts:** If caller is not current owner

**Emits:** `OwnershipTransferred` event with new_owner = address(0)

**Example:**
```python
from std.access import Ownable

contract AdminPanel(Ownable):
    settings: mapping[bytes32, uint256]

    @external
    fn update_setting(key: bytes32, value: uint256):
        self._only_owner()
        self.settings[key] = value

    @external
    fn emergency_shutdown():
        self._only_owner()
        self.renounce_ownership()  # Remove all admin access
```

---

### AccessControl

**Location:** `stdlib/access/access_control.ql`

Role-based access control (RBAC) pattern for multiple permission levels.

#### Contract Inheritance

```python
from std.access import AccessControl

contract MyContract(AccessControl):
    MINTER_ROLE: bytes32 = 0x01
    BURNER_ROLE: bytes32 = 0x02
```

#### State Variables

```python
DEFAULT_ADMIN_ROLE: bytes32 = 0x00  # Super admin role
roles: mapping[bytes32, mapping[address, bool]]  # role -> account -> has_role
```

#### Events

```python
event RoleGranted(role: bytes32, account: address, sender: address)
event RoleRevoked(role: bytes32, account: address, sender: address)
```

#### Functions

##### has_role

```python
@view
fn has_role(role: bytes32, account: address) -> bool
```

**Description:** Check if an account has a specific role.

**Parameters:**
- `role`: Role identifier
- `account`: Address to check

**Returns:** True if account has role

---

##### _check_role

```python
fn _check_role(role: bytes32)
```

**Description:** Internal function to require caller has a role.

**Parameters:**
- `role`: Required role

**Reverts:** If msg.sender doesn't have the role

---

##### grant_role

```python
@external
fn grant_role(role: bytes32, account: address)
```

**Description:** Grant a role to an account.

**Parameters:**
- `role`: Role to grant
- `account`: Address to grant role to

**Reverts:** If caller doesn't have DEFAULT_ADMIN_ROLE

**Emits:** `RoleGranted` event

---

##### revoke_role

```python
@external
fn revoke_role(role: bytes32, account: address)
```

**Description:** Revoke a role from an account.

**Parameters:**
- `role`: Role to revoke
- `account`: Address to revoke role from

**Reverts:** If caller doesn't have DEFAULT_ADMIN_ROLE

**Emits:** `RoleRevoked` event

---

##### renounce_role

```python
@external
fn renounce_role(role: bytes32)
```

**Description:** Renounce a role (caller removes their own role).

**Parameters:**
- `role`: Role to renounce

**Emits:** `RoleRevoked` event

**Example:**
```python
from std.access import AccessControl

contract MultiAdminToken(AccessControl):
    MINTER_ROLE: bytes32 = 0x01
    BURNER_ROLE: bytes32 = 0x02
    PAUSER_ROLE: bytes32 = 0x03

    balances: mapping[address, uint256]
    total_supply: uint256
    is_paused: bool

    @constructor
    fn __init__():
        # Grant deployer all admin roles
        self.grant_role(self.DEFAULT_ADMIN_ROLE, msg.sender)
        self.grant_role(self.MINTER_ROLE, msg.sender)

    @external
    fn mint(to: address, amount: uint256):
        self._check_role(self.MINTER_ROLE)
        self.balances[to] += amount
        self.total_supply += amount

    @external
    fn burn(from_addr: address, amount: uint256):
        self._check_role(self.BURNER_ROLE)
        self.balances[from_addr] -= amount
        self.total_supply -= amount

    @external
    fn pause():
        self._check_role(self.PAUSER_ROLE)
        self.is_paused = True

    @external
    fn add_minter(account: address):
        self._check_role(self.DEFAULT_ADMIN_ROLE)
        self.grant_role(self.MINTER_ROLE, account)
```

---

## Token Module (std.token)

**Location:** `stdlib/token/erc20.ql`

Standard token implementations.

### IERC20

Interface definition for ERC-20 tokens.

```python
interface IERC20:
    fn total_supply() -> uint256
    fn balance_of(account: address) -> uint256
    fn transfer(to: address, amount: uint256) -> bool
    fn allowance(owner: address, spender: address) -> uint256
    fn approve(spender: address, amount: uint256) -> bool
    fn transfer_from(from_addr: address, to: address, amount: uint256) -> bool
```

---

### ERC20

Complete ERC-20 token implementation.

#### Contract Inheritance

```python
from std.token import ERC20

contract MyToken(ERC20):
    @constructor
    fn __init__():
        self.name = "My Token"
        self.symbol = "MTK"
        self.decimals = 18
        self._mint(msg.sender, 1000000 * 10**18)
```

#### State Variables

```python
name: str                                           # Token name
symbol: str                                         # Token symbol
decimals: uint8                                     # Decimal places
total_supply: uint256                               # Total supply
balances: mapping[address, uint256]                 # Balances
allowances: mapping[address, mapping[address, uint256]]  # Allowances
```

#### Events

```python
event Transfer(from_addr: address, to_addr: address, value: uint256)
event Approval(owner: address, spender: address, value: uint256)
```

#### Functions

##### balance_of

```python
@view
fn balance_of(account: address) -> uint256
```

Get token balance of an account.

---

##### transfer

```python
@external
fn transfer(to: address, amount: uint256) -> bool
```

Transfer tokens to another address.

---

##### approve

```python
@external
fn approve(spender: address, amount: uint256) -> bool
```

Approve spender to transfer tokens on behalf of caller.

---

##### allowance

```python
@view
fn allowance(owner: address, spender: address) -> uint256
```

Get remaining allowance for spender.

---

##### transfer_from

```python
@external
fn transfer_from(from_addr: address, to: address, amount: uint256) -> bool
```

Transfer tokens using allowance.

---

##### _mint (Internal)

```python
fn _mint(to: address, amount: uint256)
```

Mint new tokens (internal function).

---

##### _burn (Internal)

```python
fn _burn(from_addr: address, amount: uint256)
```

Burn tokens (internal function).

---

##### _transfer (Internal)

```python
fn _transfer(from_addr: address, to: address, amount: uint256)
```

Internal transfer function.

**Example:**
```python
from std.token import ERC20
from std.access import Ownable

contract MintableToken(ERC20, Ownable):
    @constructor
    fn __init__(initial_supply: uint256):
        self.name = "Mintable Token"
        self.symbol = "MINT"
        self.decimals = 18
        self._mint(msg.sender, initial_supply)

    @external
    fn mint(to: address, amount: uint256):
        self._only_owner()
        self._mint(to, amount)

    @external
    fn burn(amount: uint256):
        self._burn(msg.sender, amount)
```

---

## Errors Module (std.errors)

**Location:** `stdlib/errors.ql`

Standard error definitions.

### Error Types

```python
# Access Control Errors
error Unauthorized(caller: address)
error MissingRole(account: address, role: bytes32)

# Token Errors
error InsufficientBalance(available: uint256, needed: uint256)
error InsufficientAllowance(available: uint256, needed: uint256)

# Math Errors
error MathOverflow()
error MathUnderflow()
error DivisionByZero()

# General Errors
error InvalidAddress(addr: address)
error InvalidAmount(amount: uint256)
error OperationFailed(reason: str)
```

### Usage

```python
from std.errors import InsufficientBalance, InvalidAddress

fn transfer(to: address, amount: uint256) -> bool:
    if to == address(0):
        raise InvalidAddress(to)

    if self.balances[msg.sender] < amount:
        raise InsufficientBalance(self.balances[msg.sender], amount)

    # ... transfer logic ...
```

---

## Usage Examples

### Example 1: Safe Token with Access Control

```python
from std.math import safe_add, safe_sub
from std.access import Ownable
from std.errors import InsufficientBalance, InvalidAddress

event Transfer(from_addr: address, to_addr: address, value: uint256)

contract SafeToken(Ownable):
    name: str = "Safe Token"
    symbol: str = "SAFE"
    decimals: uint8 = 18
    total_supply: uint256
    balances: mapping[address, uint256]
    is_paused: bool

    @constructor
    fn __init__(initial_supply: uint256):
        self.total_supply = initial_supply
        self.balances[msg.sender] = initial_supply
        emit Transfer(address(0), msg.sender, initial_supply)

    @external
    fn transfer(to: address, amount: uint256) -> bool:
        require(not self.is_paused, "Contract is paused")
        if to == address(0):
            raise InvalidAddress(to)

        sender_balance: uint256 = self.balances[msg.sender]
        if sender_balance < amount:
            raise InsufficientBalance(sender_balance, amount)

        self.balances[msg.sender] = safe_sub(sender_balance, amount)
        self.balances[to] = safe_add(self.balances[to], amount)

        emit Transfer(msg.sender, to, amount)
        return True

    @external
    fn pause():
        self._only_owner()
        self.is_paused = True

    @external
    fn unpause():
        self._only_owner()
        self.is_paused = False

    @view
    fn balance_of(account: address) -> uint256:
        return self.balances[account]
```

---

### Example 2: Multi-Role Token

```python
from std.math import safe_add, safe_sub
from std.access import AccessControl
from std.token import ERC20

contract GovernanceToken(ERC20, AccessControl):
    MINTER_ROLE: bytes32 = 0x01
    BURNER_ROLE: bytes32 = 0x02

    @constructor
    fn __init__():
        self.name = "Governance Token"
        self.symbol = "GOV"
        self.decimals = 18

        # Set up roles
        self.grant_role(self.DEFAULT_ADMIN_ROLE, msg.sender)
        self.grant_role(self.MINTER_ROLE, msg.sender)

    @external
    fn mint(to: address, amount: uint256):
        self._check_role(self.MINTER_ROLE)
        self._mint(to, amount)

    @external
    fn burn(amount: uint256):
        self._check_role(self.BURNER_ROLE)
        self._burn(msg.sender, amount)
```

---

### Example 3: Mathematical Operations

```python
from std.math import safe_add, safe_mul, safe_div, min, max

contract Calculator:
    result: uint256

    @external
    fn calculate_fee(amount: uint256, fee_basis_points: uint256) -> uint256:
        """Calculate fee in basis points (1 bp = 0.01%)."""
        fee: uint256 = safe_mul(amount, fee_basis_points)
        return safe_div(fee, 10000)

    @external
    fn calculate_bounded_value(value: uint256, min_val: uint256, max_val: uint256) -> uint256:
        """Clamp value between min and max."""
        bounded: uint256 = max(value, min_val)
        return min(bounded, max_val)

    @external
    fn compound_interest(principal: uint256, periods: uint256) -> uint256:
        """Calculate compound interest (simplified)."""
        # 5% per period
        for i in range(periods):
            principal = safe_add(principal, safe_div(safe_mul(principal, 5), 100))
        return principal
```

---

## Best Practices

### 1. Always Use Safe Math for Financial Operations

```python
# ✅ Good
from std.math import safe_add
balance = safe_add(balance, amount)

# ❌ Bad
balance = balance + amount  # Can overflow!
```

### 2. Use Ownable for Simple Admin Functions

```python
# ✅ Good - Simple ownership
from std.access import Ownable

contract SimpleAdmin(Ownable):
    @external
    fn admin_function():
        self._only_owner()
        # ...
```

### 3. Use AccessControl for Complex Permissions

```python
# ✅ Good - Multiple roles
from std.access import AccessControl

contract ComplexAdmin(AccessControl):
    OPERATOR_ROLE: bytes32 = 0x01
    ADMIN_ROLE: bytes32 = 0x02

    @external
    fn operate():
        self._check_role(self.OPERATOR_ROLE)
        # ...
```

### 4. Inherit from ERC20 for Standard Tokens

```python
# ✅ Good - Reuse tested code
from std.token import ERC20

contract MyToken(ERC20):
    # Focus on custom logic
    pass
```

---

## See Also

- [Language Reference](LANGUAGE_REFERENCE.md) - Complete language syntax
- [Tutorials](TUTORIALS.md) - Step-by-step guides
- [Examples](../examples/) - Working contract examples

---

*Last Updated: 2025-11-30*
