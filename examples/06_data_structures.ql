# 06_data_structures.ql - Working with complex data structures
#
# This example demonstrates:
# - Mappings (dictionaries/hash maps)
# - Nested mappings
# - Arrays/Lists
# - Accessing and updating data structures

event DataUpdated(key: address, value: uint256)
event BalanceTransferred(from_addr: address, to_addr: address, amount: uint256)

contract DataStructuresExample:
    """
    Demonstrates how to use mappings and other data structures in Quorlin.
    """

    # === Simple Mapping ===
    # Maps addresses to uint256 values (like a dictionary)
    balances: mapping[address, uint256]

    # === Nested Mapping ===
    # Maps address -> address -> uint256 (like allowances in ERC-20)
    allowances: mapping[address, mapping[address, uint256]]

    # === Another mapping example ===
    # Maps addresses to boolean flags
    is_approved: mapping[address, bool]

    # === State variables ===
    total_supply: uint256
    owner: address

    @constructor
    fn __init__():
        """Initialize the contract."""
        self.owner = msg.sender
        self.total_supply = 0

    # === Working with Simple Mappings ===

    @external
    fn set_balance(account: address, amount: uint256):
        """
        Set a value in a mapping.
        """
        require(msg.sender == self.owner, "Only owner can set balances")
        self.balances[account] = amount
        emit DataUpdated(account, amount)

    @external
    fn increase_balance(account: address, amount: uint256):
        """
        Increase a mapping value.
        Demonstrates reading and writing to mappings.
        """
        # Read current value
        let current: uint256 = self.balances[account]

        # Update with new value
        self.balances[account] = current + amount

        emit DataUpdated(account, self.balances[account])

    @external
    fn transfer_balance(from_addr: address, to_addr: address, amount: uint256):
        """
        Transfer value between two mapping entries.
        """
        require(msg.sender == self.owner, "Only owner")
        require(self.balances[from_addr] >= amount, "Insufficient balance")

        # Decrease sender balance
        self.balances[from_addr] = self.balances[from_addr] - amount

        # Increase receiver balance
        self.balances[to_addr] = self.balances[to_addr] + amount

        emit BalanceTransferred(from_addr, to_addr, amount)

    @view
    fn get_balance(account: address) -> uint256:
        """
        Read a value from a mapping.
        Returns 0 if key doesn't exist (default value).
        """
        return self.balances[account]

    # === Working with Nested Mappings ===

    @external
    fn approve(spender: address, amount: uint256):
        """
        Set a value in a nested mapping.
        Allows 'spender' to spend 'amount' on behalf of msg.sender.
        """
        self.allowances[msg.sender][spender] = amount

    @external
    fn increase_allowance(spender: address, added_value: uint256):
        """
        Increase a value in a nested mapping.
        """
        let current: uint256 = self.allowances[msg.sender][spender]
        self.allowances[msg.sender][spender] = current + added_value

    @external
    fn decrease_allowance(spender: address, subtracted_value: uint256):
        """
        Decrease a value in a nested mapping.
        """
        let current: uint256 = self.allowances[msg.sender][spender]
        require(current >= subtracted_value, "Allowance too low")
        self.allowances[msg.sender][spender] = current - subtracted_value

    @view
    fn get_allowance(owner_addr: address, spender: address) -> uint256:
        """
        Read a value from a nested mapping.
        """
        return self.allowances[owner_addr][spender]

    @external
    fn spend_allowance(owner_addr: address, spender: address, amount: uint256):
        """
        Use and decrease an allowance.
        Demonstrates reading and updating nested mappings.
        """
        # Check allowance
        let allowed: uint256 = self.allowances[owner_addr][spender]
        require(allowed >= amount, "Allowance exceeded")

        # Check owner has sufficient balance
        require(self.balances[owner_addr] >= amount, "Insufficient balance")

        // Decrease allowance
        self.allowances[owner_addr][spender] = allowed - amount

        # Transfer balance
        self.balances[owner_addr] = self.balances[owner_addr] - amount
        self.balances[spender] = self.balances[spender] + amount

    # === Working with Boolean Mappings ===

    @external
    fn set_approval_status(account: address, approved: bool):
        """
        Set a boolean value in a mapping.
        """
        require(msg.sender == self.owner, "Only owner")
        self.is_approved[account] = approved

    @view
    fn check_approval(account: address) -> bool:
        """
        Read a boolean from a mapping.
        Returns false by default if key doesn't exist.
        """
        return self.is_approved[account]

    # === Practical Example: Token-like System ===

    @external
    fn mint(to: address, amount: uint256):
        """
        Create new tokens and add to an account.
        Demonstrates updating multiple mappings.
        """
        require(msg.sender == self.owner, "Only owner can mint")
        require(to != address(0), "Cannot mint to zero address")

        # Increase account balance
        self.balances[to] = self.balances[to] + amount

        # Increase total supply
        self.total_supply = self.total_supply + amount

        emit DataUpdated(to, self.balances[to])

    @external
    fn burn(from_addr: address, amount: uint256):
        """
        Destroy tokens from an account.
        """
        require(msg.sender == self.owner, "Only owner can burn")
        require(self.balances[from_addr] >= amount, "Insufficient balance")

        # Decrease account balance
        self.balances[from_addr] = self.balances[from_addr] - amount

        # Decrease total supply
        self.total_supply = self.total_supply - amount

        emit DataUpdated(from_addr, self.balances[from_addr])

    @view
    fn get_total_supply() -> uint256:
        """Get the total token supply."""
        return self.total_supply

# Expected behavior:
#
# 1. Deploy contract
#    → owner = deployer, total_supply = 0
#
# 2. Call set_balance(Alice, 1000)
#    → balances[Alice] = 1000
#
# 3. Call get_balance(Alice)
#    → Returns: 1000
#
# 4. Call increase_balance(Alice, 500)
#    → balances[Alice] = 1500
#
# 5. Call set_balance(Bob, 500)
#    → balances[Bob] = 500
#
# 6. Call transfer_balance(Alice, Bob, 300)
#    → balances[Alice] = 1200, balances[Bob] = 800
#
# 7. From Alice's account: Call approve(Bob, 500)
#    → allowances[Alice][Bob] = 500
#
# 8. Call get_allowance(Alice, Bob)
#    → Returns: 500
#
# 9. Call spend_allowance(Alice, Bob, 200)
#    → allowances[Alice][Bob] = 300
#    → balances[Alice] = 1000, balances[Bob] = 1000
#
# 10. Call set_approval_status(Charlie, true)
#     → is_approved[Charlie] = true
#
# 11. Call check_approval(Charlie)
#     → Returns: true
#
# 12. Call mint(Alice, 10000)
#     → balances[Alice] = 11000, total_supply = 10000
#
# 13. Call burn(Alice, 1000)
#     → balances[Alice] = 10000, total_supply = 9000
