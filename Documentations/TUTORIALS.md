# Quorlin Tutorials

Step-by-step guides to building smart contracts with Quorlin.

---

## Table of Contents

1. [Tutorial 1: Hello World](#tutorial-1-hello-world)
2. [Tutorial 2: Simple Storage](#tutorial-2-simple-storage)
3. [Tutorial 3: Counter with Events](#tutorial-3-counter-with-events)
4. [Tutorial 4: Basic Token](#tutorial-4-basic-token)
5. [Tutorial 5: Ownable Contract](#tutorial-5-ownable-contract)
6. [Tutorial 6: Complete ERC-20 Token](#tutorial-6-complete-erc-20-token)
7. [Tutorial 7: Multi-Signature Wallet](#tutorial-7-multi-signature-wallet)
8. [Tutorial 8: NFT Contract](#tutorial-8-nft-contract)

---

## Tutorial 1: Hello World

**Goal:** Create your first Quorlin contract

**What you'll learn:**
- Basic contract structure
- State variables
- Simple functions

### Step 1: Create the Contract File

Create a file named `hello.ql`:

```python
contract HelloWorld:
    """My first Quorlin contract."""

    greeting: str = "Hello, Quorlin!"

    @view
    fn get_greeting() -> str:
        """Return the greeting message."""
        return self.greeting
```

### Step 2: Compile the Contract

```bash
# For Ethereum
./target/release/qlc compile hello.ql --target evm -o hello.yul

# For Solana
./target/release/qlc compile hello.ql --target solana -o hello.rs

# For Polkadot
./target/release/qlc compile hello.ql --target ink -o hello.rs
```

### Step 3: Understand the Code

- `contract HelloWorld:` - Defines a new contract
- `greeting: str` - A state variable (stored on-chain)
- `@view` - Read-only function decorator
- `fn get_greeting()` - Function that returns the greeting

### What's Next?

Try modifying the greeting or adding more state variables!

---

## Tutorial 2: Simple Storage

**Goal:** Build a contract that stores and retrieves a number

**What you'll learn:**
- Constructor functions
- External functions
- Reading and writing state

### Step 1: Create storage.ql

```python
contract SimpleStorage:
    """A contract that stores a single number."""

    stored_value: uint256

    @constructor
    fn __init__(initial_value: uint256):
        """Initialize with a starting value."""
        self.stored_value = initial_value

    @external
    fn set(new_value: uint256):
        """Update the stored value."""
        self.stored_value = new_value

    @view
    fn get() -> uint256:
        """Retrieve the stored value."""
        return self.stored_value
```

### Step 2: Compile and Test

```bash
qlc compile storage.ql --target evm -o storage.yul
```

### Step 3: Understanding the Components

**Constructor (`@constructor`):**
- Runs once when contract is deployed
- Used to initialize state variables
- Takes parameters for customization

**External Function (`@external`):**
- Can be called from outside the contract
- Can modify state (costs gas)
- Used for state-changing operations

**View Function (`@view`):**
- Read-only, doesn't modify state
- Free to call (no gas cost for queries)
- Perfect for getters

### Exercise

Add a function to increment the stored value by a given amount:

```python
@external
fn increment(amount: uint256):
    """Increase stored value by amount."""
    self.stored_value = self.stored_value + amount
```

---

## Tutorial 3: Counter with Events

**Goal:** Add events to track state changes

**What you'll learn:**
- Declaring events
- Emitting events
- Event parameters

### Step 1: Create counter.ql

```python
# Declare events at the top
event ValueChanged(old_value: uint256, new_value: uint256, changed_by: address)

contract Counter:
    """A counter that emits events."""

    count: uint256
    owner: address

    @constructor
    fn __init__():
        """Initialize counter at zero."""
        self.count = 0
        self.owner = msg.sender

    @external
    fn increment():
        """Increase count by 1."""
        old_count: uint256 = self.count
        self.count = self.count + 1

        # Emit event
        emit ValueChanged(old_count, self.count, msg.sender)

    @external
    fn decrement():
        """Decrease count by 1."""
        require(self.count > 0, "Counter cannot go below zero")

        old_count: uint256 = self.count
        self.count = self.count - 1

        emit ValueChanged(old_count, self.count, msg.sender)

    @view
    fn get_count() -> uint256:
        """Get current count."""
        return self.count
```

### Step 2: Understanding Events

**Why Use Events?**
- Track important state changes
- Allow off-chain applications to monitor contract
- Cheaper than storing data on-chain
- Indexed by blockchain explorers

**Event Declaration:**
```python
event EventName(param1: type1, param2: type2)
```

**Emitting Events:**
```python
emit EventName(value1, value2)
```

### Exercise

Add a `reset()` function that sets count to zero and emits an event:

```python
event CounterReset(reset_by: address, previous_value: uint256)

@external
fn reset():
    """Reset counter to zero."""
    old_count: uint256 = self.count
    self.count = 0
    emit CounterReset(msg.sender, old_count)
```

---

## Tutorial 4: Basic Token

**Goal:** Create a simple token with balances and transfers

**What you'll learn:**
- Mappings (key-value storage)
- Safe arithmetic
- Token transfers

### Step 1: Create basic_token.ql

```python
from std.math import safe_add, safe_sub

event Transfer(from_addr: address, to_addr: address, amount: uint256)

contract BasicToken:
    """A simple token implementation."""

    name: str = "Basic Token"
    symbol: str = "BASIC"
    decimals: uint8 = 18
    total_supply: uint256

    balances: mapping[address, uint256]

    @constructor
    fn __init__(initial_supply: uint256):
        """Create token with initial supply."""
        self.total_supply = initial_supply
        self.balances[msg.sender] = initial_supply
        emit Transfer(address(0), msg.sender, initial_supply)

    @view
    fn balance_of(account: address) -> uint256:
        """Get balance of an account."""
        return self.balances[account]

    @external
    fn transfer(to: address, amount: uint256) -> bool:
        """Transfer tokens to another address."""
        # Validation
        require(to != address(0), "Cannot transfer to zero address")
        require(self.balances[msg.sender] >= amount, "Insufficient balance")

        # Update balances (using safe math)
        self.balances[msg.sender] = safe_sub(self.balances[msg.sender], amount)
        self.balances[to] = safe_add(self.balances[to], amount)

        # Emit event
        emit Transfer(msg.sender, to, amount)
        return True
```

### Step 2: Understanding Mappings

**Mapping Declaration:**
```python
balances: mapping[key_type, value_type]
```

**Mapping Usage:**
```python
# Write
self.balances[address] = 100

# Read
amount: uint256 = self.balances[address]
```

**Important:**
- Default value is 0 for unmapped keys
- Keys are not enumerable
- Perfect for balances, ownership, etc.

### Step 3: Understanding Safe Math

**Why Use Safe Math?**
```python
# ❌ Bad - Can overflow
balance = balance + amount

# ✅ Good - Safe from overflow
from std.math import safe_add
balance = safe_add(balance, amount)
```

**Common Functions:**
- `safe_add(a, b)` - Addition
- `safe_sub(a, b)` - Subtraction
- `safe_mul(a, b)` - Multiplication
- `safe_div(a, b)` - Division

### Exercise

Add a `burn()` function to destroy tokens:

```python
event Burn(from_addr: address, amount: uint256)

@external
fn burn(amount: uint256):
    """Burn (destroy) tokens."""
    require(self.balances[msg.sender] >= amount, "Insufficient balance")

    self.balances[msg.sender] = safe_sub(self.balances[msg.sender], amount)
    self.total_supply = safe_sub(self.total_supply, amount)

    emit Burn(msg.sender, amount)
```

---

## Tutorial 5: Ownable Contract

**Goal:** Add owner-only functions using access control

**What you'll learn:**
- Contract inheritance
- Access control patterns
- Owner-only functions

### Step 1: Create owned_token.ql

```python
from std.math import safe_add
from std.access import Ownable

event Transfer(from_addr: address, to_addr: address, amount: uint256)
event Mint(to_addr: address, amount: uint256)

contract OwnedToken(Ownable):
    """A token where owner can mint new tokens."""

    name: str = "Owned Token"
    symbol: str = "OWN"
    total_supply: uint256
    balances: mapping[address, uint256]

    @constructor
    fn __init__(initial_supply: uint256):
        """Initialize token."""
        self.total_supply = initial_supply
        self.balances[msg.sender] = initial_supply
        emit Transfer(address(0), msg.sender, initial_supply)

    @external
    fn mint(to: address, amount: uint256):
        """Mint new tokens (owner only)."""
        # Check if caller is owner
        self._only_owner()

        # Mint tokens
        self.balances[to] = safe_add(self.balances[to], amount)
        self.total_supply = safe_add(self.total_supply, amount)

        emit Mint(to, amount)
        emit Transfer(address(0), to, amount)

    @external
    fn transfer(to: address, amount: uint256) -> bool:
        """Transfer tokens."""
        require(to != address(0), "Invalid address")
        require(self.balances[msg.sender] >= amount, "Insufficient balance")

        self.balances[msg.sender] = safe_sub(self.balances[msg.sender], amount)
        self.balances[to] = safe_add(self.balances[to], amount)

        emit Transfer(msg.sender, to, amount)
        return True

    @view
    fn balance_of(account: address) -> uint256:
        """Get balance."""
        return self.balances[account]
```

### Step 2: Understanding Inheritance

**Inheriting from Ownable:**
```python
from std.access import Ownable

contract MyContract(Ownable):
    # Your contract now has:
    # - owner: address (state variable)
    # - _only_owner() (internal function)
    # - transfer_ownership() (external function)
    # - renounce_ownership() (external function)
```

**Using Owner Checks:**
```python
@external
fn admin_function():
    self._only_owner()  # Reverts if caller is not owner
    # ... admin logic ...
```

### Exercise

Add a `pause()` function that stops all transfers:

```python
is_paused: bool = False

@external
fn pause():
    """Pause all transfers (owner only)."""
    self._only_owner()
    self.is_paused = True

@external
fn unpause():
    """Unpause transfers (owner only)."""
    self._only_owner()
    self.is_paused = False

@external
fn transfer(to: address, amount: uint256) -> bool:
    """Transfer tokens."""
    require(not self.is_paused, "Transfers are paused")
    # ... rest of transfer logic ...
```

---

## Tutorial 6: Complete ERC-20 Token

**Goal:** Build a full ERC-20 token with allowances

**What you'll learn:**
- Nested mappings
- Allowance mechanism
- Complete token standard

### Step 1: Create erc20_token.ql

```python
from std.math import safe_add, safe_sub

event Transfer(from_addr: address, to_addr: address, value: uint256)
event Approval(owner: address, spender: address, value: uint256)

contract ERC20Token:
    """Complete ERC-20 token implementation."""

    name: str = "My Token"
    symbol: str = "MTK"
    decimals: uint8 = 18
    total_supply: uint256

    balances: mapping[address, uint256]
    allowances: mapping[address, mapping[address, uint256]]

    @constructor
    fn __init__(initial_supply: uint256):
        """Initialize token with supply."""
        self.total_supply = initial_supply
        self.balances[msg.sender] = initial_supply
        emit Transfer(address(0), msg.sender, initial_supply)

    @view
    fn balance_of(account: address) -> uint256:
        """Get account balance."""
        return self.balances[account]

    @view
    fn allowance(owner: address, spender: address) -> uint256:
        """Get approved allowance."""
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
        """Approve spender to transfer tokens."""
        require(spender != address(0), "Invalid spender")

        self.allowances[msg.sender][spender] = amount
        emit Approval(msg.sender, spender, amount)
        return True

    @external
    fn transfer_from(from_addr: address, to: address, amount: uint256) -> bool:
        """Transfer tokens using allowance."""
        require(to != address(0), "Invalid recipient")
        require(self.balances[from_addr] >= amount, "Insufficient balance")
        require(
            self.allowances[from_addr][msg.sender] >= amount,
            "Insufficient allowance"
        )

        # Update balances
        self.balances[from_addr] = safe_sub(self.balances[from_addr], amount)
        self.balances[to] = safe_add(self.balances[to], amount)

        # Update allowance
        self.allowances[from_addr][msg.sender] = safe_sub(
            self.allowances[from_addr][msg.sender],
            amount
        )

        emit Transfer(from_addr, to, amount)
        return True
```

### Step 2: Understanding Allowances

**The Allowance Pattern:**

1. **Owner approves spender:**
   ```python
   token.approve(spender_address, 100)
   ```

2. **Spender transfers on behalf of owner:**
   ```python
   token.transfer_from(owner_address, recipient, 50)
   ```

**Use Cases:**
- DEX (decentralized exchanges)
- Automated payments
- Delegated transfers

### Step 3: Nested Mappings

```python
# Declaration
allowances: mapping[address, mapping[address, uint256]]

# Usage
# allowances[owner][spender] = amount
self.allowances[msg.sender][spender] = 100

# Reading
amount: uint256 = self.allowances[owner][spender]
```

### Exercise

Add increase/decrease allowance functions:

```python
@external
fn increase_allowance(spender: address, added_value: uint256) -> bool:
    """Increase spender allowance."""
    current: uint256 = self.allowances[msg.sender][spender]
    new_allowance: uint256 = safe_add(current, added_value)
    self.allowances[msg.sender][spender] = new_allowance
    emit Approval(msg.sender, spender, new_allowance)
    return True

@external
fn decrease_allowance(spender: address, subtracted_value: uint256) -> bool:
    """Decrease spender allowance."""
    current: uint256 = self.allowances[msg.sender][spender]
    require(current >= subtracted_value, "Allowance below zero")
    new_allowance: uint256 = safe_sub(current, subtracted_value)
    self.allowances[msg.sender][spender] = new_allowance
    emit Approval(msg.sender, spender, new_allowance)
    return True
```

---

## Tutorial 7: Multi-Signature Wallet

**Goal:** Create a wallet requiring multiple approvals

**What you'll learn:**
- Complex state management
- Multiple owners
- Proposal/voting patterns

### Step 1: Create multisig.ql

```python
from std.math import safe_add

event Deposit(from_addr: address, amount: uint256)
event Proposal(proposal_id: uint256, to: address, amount: uint256)
event Approval(proposal_id: uint256, approver: address)
event Execution(proposal_id: uint256)

contract MultiSigWallet:
    """A wallet requiring multiple signatures."""

    owners: mapping[address, bool]
    owner_count: uint256
    required_approvals: uint256

    proposals: mapping[uint256, Proposal]
    proposal_count: uint256
    approvals: mapping[uint256, mapping[address, bool]]

    struct Proposal:
        to: address
        amount: uint256
        executed: bool
        approval_count: uint256

    @constructor
    fn __init__(owner_addresses: list[address], required: uint256):
        """Initialize multisig wallet."""
        require(required > 0, "Required must be positive")
        require(required <= len(owner_addresses), "Required too high")

        # Set owners
        for owner in owner_addresses:
            require(owner != address(0), "Invalid owner")
            require(not self.owners[owner], "Duplicate owner")
            self.owners[owner] = True

        self.owner_count = len(owner_addresses)
        self.required_approvals = required

    fn _is_owner() -> bool:
        """Check if caller is owner."""
        return self.owners[msg.sender]

    @external
    fn propose(to: address, amount: uint256) -> uint256:
        """Create a new proposal."""
        require(self._is_owner(), "Only owners can propose")
        require(to != address(0), "Invalid recipient")

        proposal_id: uint256 = self.proposal_count
        self.proposal_count = safe_add(self.proposal_count, 1)

        # Create proposal
        self.proposals[proposal_id] = Proposal(
            to=to,
            amount=amount,
            executed=False,
            approval_count=0
        )

        emit Proposal(proposal_id, to, amount)
        return proposal_id

    @external
    fn approve(proposal_id: uint256):
        """Approve a proposal."""
        require(self._is_owner(), "Only owners can approve")
        require(not self.approvals[proposal_id][msg.sender], "Already approved")
        require(not self.proposals[proposal_id].executed, "Already executed")

        # Record approval
        self.approvals[proposal_id][msg.sender] = True
        self.proposals[proposal_id].approval_count = safe_add(
            self.proposals[proposal_id].approval_count,
            1
        )

        emit Approval(proposal_id, msg.sender)

    @external
    fn execute(proposal_id: uint256):
        """Execute an approved proposal."""
        require(self._is_owner(), "Only owners can execute")
        require(not self.proposals[proposal_id].executed, "Already executed")
        require(
            self.proposals[proposal_id].approval_count >= self.required_approvals,
            "Insufficient approvals"
        )

        # Mark as executed
        self.proposals[proposal_id].executed = True

        # Transfer funds (simplified - platform specific implementation needed)
        emit Execution(proposal_id)
```

### Step 2: Understanding the Pattern

**Multisig Flow:**
1. Owner creates proposal
2. Other owners approve
3. When threshold reached, execute

**Key Concepts:**
- Multiple owners with equal rights
- Proposals stored with IDs
- Approval tracking per proposal
- Execution only when threshold met

---

## Tutorial 8: NFT Contract

**Goal:** Create a non-fungible token (NFT) contract

**What you'll learn:**
- Unique token IDs
- Ownership tracking
- Metadata handling

### Step 1: Create nft.ql

```python
from std.math import safe_add

event Transfer(from_addr: address, to_addr: address, token_id: uint256)
event Mint(to_addr: address, token_id: uint256)

contract SimpleNFT:
    """A simple NFT implementation."""

    name: str = "Simple NFT"
    symbol: str = "SNFT"

    owners: mapping[uint256, address]
    balances: mapping[address, uint256]
    token_count: uint256

    @constructor
    fn __init__():
        """Initialize NFT contract."""
        self.token_count = 0

    @view
    fn owner_of(token_id: uint256) -> address:
        """Get owner of token."""
        owner: address = self.owners[token_id]
        require(owner != address(0), "Token does not exist")
        return owner

    @view
    fn balance_of(owner: address) -> uint256:
        """Get number of tokens owned."""
        require(owner != address(0), "Invalid address")
        return self.balances[owner]

    @external
    fn mint(to: address) -> uint256:
        """Mint a new NFT."""
        require(to != address(0), "Invalid recipient")

        token_id: uint256 = self.token_count
        self.token_count = safe_add(self.token_count, 1)

        self.owners[token_id] = to
        self.balances[to] = safe_add(self.balances[to], 1)

        emit Mint(to, token_id)
        emit Transfer(address(0), to, token_id)

        return token_id

    @external
    fn transfer(to: address, token_id: uint256):
        """Transfer NFT to another address."""
        require(to != address(0), "Invalid recipient")
        require(self.owners[token_id] == msg.sender, "Not token owner")

        from_addr: address = msg.sender

        # Update ownership
        self.owners[token_id] = to
        self.balances[from_addr] = self.balances[from_addr] - 1
        self.balances[to] = safe_add(self.balances[to], 1)

        emit Transfer(from_addr, to, token_id)
```

### Step 2: Understanding NFTs

**Key Differences from Fungible Tokens:**
- Each token has unique ID
- Track owner per token ID
- Balance = number of tokens owned
- Transfer by token ID, not amount

**NFT Use Cases:**
- Digital art
- Gaming items
- Real estate titles
- Identity tokens
- Collectibles

---

## Next Steps

### Recommended Learning Path

1. ✅ Complete all tutorials above
2. Read the [Language Reference](LANGUAGE_REFERENCE.md)
3. Study the [Standard Library](STDLIB_REFERENCE.md)
4. Explore [example contracts](../examples/)
5. Build your own project!

### Advanced Topics

- **Security Patterns**: Reentrancy guards, pull over push
- **Gas Optimization**: Storage packing, batch operations
- **Upgradeability**: Proxy patterns, data separation
- **Cross-Chain**: Platform-specific considerations

### Resources

- [Quorlin Examples](../examples/) - Working contracts
- [Deployment Guide](DEPLOYMENT_GUIDE.md) - Deploy to mainnet
- [Architecture](ARCHITECTURE.md) - How the compiler works

---

## Common Patterns Cheatsheet

### Access Control
```python
from std.access import Ownable

contract MyContract(Ownable):
    @external
    fn admin_only():
        self._only_owner()
        # ...
```

### Safe Math
```python
from std.math import safe_add, safe_sub

balance = safe_add(balance, amount)
balance = safe_sub(balance, amount)
```

### Events
```python
event Something(param1: type1, param2: type2)

emit Something(value1, value2)
```

### Validation
```python
require(condition, "Error message")
```

### Mappings
```python
# Simple
balances: mapping[address, uint256]

# Nested
allowances: mapping[address, mapping[address, uint256]]
```

---

**Happy Building! 🚀**

*Last Updated: 2025-11-30*
