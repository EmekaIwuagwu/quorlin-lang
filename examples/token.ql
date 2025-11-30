# token.ql — A complete ERC-20 token in Quorlin
# Compiles to EVM, Solana, and Polkadot from this single file

from std.math import safe_add, safe_sub

# Events
event Transfer(from_addr: address, to_addr: address, value: uint256)
event Approval(owner: address, spender: address, value: uint256)


contract Token:
    """
    Standard fungible token implementation.
    Compatible with ERC-20 (EVM), SPL (Solana), and PSP22 (Polkadot).
    """

    # ════════════════════════════════════════════════════════════
    # State Variables
    # ════════════════════════════════════════════════════════════

    name: str = "Quorlin Token"
    symbol: str = "QRL"
    decimals: uint8 = 18
    total_supply: uint256

    balances: mapping[address, uint256]
    allowances: mapping[address, mapping[address, uint256]]

    # ════════════════════════════════════════════════════════════
    # Constructor
    # ════════════════════════════════════════════════════════════

    @constructor
    fn __init__(initial_supply: uint256):
        """Initialize token with supply going to deployer."""
        self.total_supply = initial_supply
        self.balances[msg.sender] = initial_supply
        emit Transfer(address(0), msg.sender, initial_supply)

    # ════════════════════════════════════════════════════════════
    # Public Functions
    # ════════════════════════════════════════════════════════════

    @external
    fn transfer(to: address, amount: uint256) -> bool:
        """Transfer tokens to another address."""
        require(self.balances[msg.sender] >= amount, "Insufficient balance")
        require(to != address(0), "Cannot send to zero address")

        self.balances[msg.sender] = safe_sub(self.balances[msg.sender], amount)
        self.balances[to] = safe_add(self.balances[to], amount)

        emit Transfer(msg.sender, to, amount)
        return True

    @external
    fn approve(spender: address, amount: uint256) -> bool:
        """Approve spender to transfer tokens on your behalf."""
        require(spender != address(0), "Cannot approve zero address")

        self.allowances[msg.sender][spender] = amount

        emit Approval(msg.sender, spender, amount)
        return True

    @external
    fn transfer_from(from_addr: address, to: address, amount: uint256) -> bool:
        """Transfer tokens from one address to another (requires approval)."""
        require(self.balances[from_addr] >= amount, "Insufficient balance")
        require(self.allowances[from_addr][msg.sender] >= amount, "Insufficient allowance")
        require(to != address(0), "Cannot send to zero address")

        self.balances[from_addr] = safe_sub(self.balances[from_addr], amount)
        self.balances[to] = safe_add(self.balances[to], amount)
        self.allowances[from_addr][msg.sender] -= amount

        emit Transfer(from_addr, to, amount)
        return True

    # ════════════════════════════════════════════════════════════
    # View Functions (read-only)
    # ════════════════════════════════════════════════════════════

    @view
    fn balance_of(owner: address) -> uint256:
        """Get token balance of an address."""
        return self.balances[owner]

    @view
    fn allowance(owner: address, spender: address) -> uint256:
        """Get spending allowance."""
        return self.allowances[owner][spender]

    @view
    fn get_total_supply() -> uint256:
        """Get total token supply."""
        return self.total_supply
