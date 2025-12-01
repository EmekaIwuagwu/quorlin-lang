# Quorlin Standard Library

The Quorlin Standard Library provides reusable, audited contract modules for common smart contract patterns.

## Modules

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

### Token Standards (`std.token`)

#### ERC20

Standard fungible token implementation:

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

## Usage

Import from the standard library:

```quorlin
from std.math import safe_add, safe_sub
from std.access import Ownable
from std.token import ERC20
from std.errors import Unauthorized, InsufficientBalance

contract MyContract(Ownable, ERC20):
    # Your contract code
    pass
```

## Cross-Chain Compatibility

All standard library modules compile to:
- **EVM**: Solidity-compatible bytecode via Yul
- **Solana**: Anchor program Rust code
- **Polkadot**: ink! smart contract Rust code

The same Quorlin code works across all platforms!
