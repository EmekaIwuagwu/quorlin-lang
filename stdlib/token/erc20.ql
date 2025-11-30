# erc20.ql — Standard ERC-20 token interface for Quorlin
# Implements the standard fungible token interface

from std.math import safe_add, safe_sub

# Events
event Transfer(from_addr: address, to: address, value: uint256)
event Approval(owner: address, spender: address, value: uint256)

interface IERC20:
    """Standard ERC-20 token interface."""

    @view
    def name() -> str:
        """Returns the name of the token."""
        pass

    @view
    def symbol() -> str:
        """Returns the symbol of the token."""
        pass

    @view
    def decimals() -> uint8:
        """Returns the number of decimals the token uses."""
        pass

    @view
    def total_supply() -> uint256:
        """Returns the total token supply."""
        pass

    @view
    def balance_of(account: address) -> uint256:
        """Returns the account balance."""
        pass

    @external
    def transfer(to: address, amount: uint256) -> bool:
        """Moves amount tokens to recipient."""
        pass

    @view
    def allowance(owner: address, spender: address) -> uint256:
        """Returns the remaining number of tokens spender is allowed to spend."""
        pass

    @external
    def approve(spender: address, amount: uint256) -> bool:
        """Sets amount as the allowance of spender."""
        pass

    @external
    def transfer_from(from_addr: address, to: address, amount: uint256) -> bool:
        """Moves amount tokens from sender to recipient using allowance."""
        pass

contract ERC20:
    """
    Implementation of the ERC20 interface.
    This is a basic, standard implementation.
    """

    # State variables
    _name: str
    _symbol: str
    _decimals: uint8
    _total_supply: uint256
    _balances: mapping[address, uint256]
    _allowances: mapping[address, mapping[address, uint256]]

    @constructor
    def __init__(name: str, symbol: str, decimals: uint8):
        """Initialize the token with name, symbol, and decimals."""
        self._name = name
        self._symbol = symbol
        self._decimals = decimals

    # View functions
    @view
    def name() -> str:
        """Returns the name of the token."""
        return self._name

    @view
    def symbol() -> str:
        """Returns the symbol of the token."""
        return self._symbol

    @view
    def decimals() -> uint8:
        """Returns the number of decimals."""
        return self._decimals

    @view
    def total_supply() -> uint256:
        """Returns the total supply."""
        return self._total_supply

    @view
    def balance_of(account: address) -> uint256:
        """Returns the balance of an account."""
        return self._balances[account]

    @view
    def allowance(owner: address, spender: address) -> uint256:
        """Returns the allowance."""
        return self._allowances[owner][spender]

    # External functions
    @external
    def transfer(to: address, amount: uint256) -> bool:
        """Transfer tokens to another address."""
        self._transfer(msg.sender, to, amount)
        return True

    @external
    def approve(spender: address, amount: uint256) -> bool:
        """Approve spender to transfer tokens."""
        self._approve(msg.sender, spender, amount)
        return True

    @external
    def transfer_from(from_addr: address, to: address, amount: uint256) -> bool:
        """Transfer tokens from one address to another using allowance."""
        self._spend_allowance(from_addr, msg.sender, amount)
        self._transfer(from_addr, to, amount)
        return True

    # Internal functions
    def _transfer(from_addr: address, to: address, amount: uint256):
        """Internal transfer function."""
        require(from_addr != address(0), "ERC20: transfer from zero address")
        require(to != address(0), "ERC20: transfer to zero address")

        from_balance: uint256 = self._balances[from_addr]
        require(from_balance >= amount, "ERC20: transfer amount exceeds balance")

        self._balances[from_addr] = safe_sub(from_balance, amount)
        self._balances[to] = safe_add(self._balances[to], amount)

        emit Transfer(from_addr, to, amount)

    def _mint(account: address, amount: uint256):
        """Internal function to create tokens."""
        require(account != address(0), "ERC20: mint to zero address")

        self._total_supply = safe_add(self._total_supply, amount)
        self._balances[account] = safe_add(self._balances[account], amount)

        emit Transfer(address(0), account, amount)

    def _burn(account: address, amount: uint256):
        """Internal function to destroy tokens."""
        require(account != address(0), "ERC20: burn from zero address")

        account_balance: uint256 = self._balances[account]
        require(account_balance >= amount, "ERC20: burn amount exceeds balance")

        self._balances[account] = safe_sub(account_balance, amount)
        self._total_supply = safe_sub(self._total_supply, amount)

        emit Transfer(account, address(0), amount)

    def _approve(owner: address, spender: address, amount: uint256):
        """Internal function to set allowance."""
        require(owner != address(0), "ERC20: approve from zero address")
        require(spender != address(0), "ERC20: approve to zero address")

        self._allowances[owner][spender] = amount
        emit Approval(owner, spender, amount)

    def _spend_allowance(owner: address, spender: address, amount: uint256):
        """Internal function to update allowance."""
        current_allowance: uint256 = self.allowance(owner, spender)
        require(current_allowance >= amount, "ERC20: insufficient allowance")
        self._approve(owner, spender, safe_sub(current_allowance, amount))
