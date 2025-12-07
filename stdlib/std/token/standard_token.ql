# standard_token.ql — Universal token implementation for Quorlin
# Compiles to ERC-20 (EVM), SPL Token (Solana), PSP22 (Polkadot), and equivalents

from std.math import safe_add, safe_sub
from std.log import emit_event, require, require_not_zero_address

contract StandardToken:
    """
    Universal fungible token implementation that compiles to:
    - ERC-20 (EVM/Avalanche)
    - SPL Token (Solana)
    - PSP22 (Polkadot)
    - Fungible Asset (Aptos)
    - ERC-20-like (StarkNet)
    
    This provides a single source of truth for token logic across all chains.
    """
    
    # State variables
    _name: str
    _symbol: str
    _decimals: uint8
    _total_supply: uint256
    _balances: mapping[address, uint256]
    _allowances: mapping[address, mapping[address, uint256]]
    _owner: address
    _paused: bool
    
    # Events
    event Transfer(from_addr: address, to: address, value: uint256)
    event Approval(owner: address, spender: address, value: uint256)
    event Mint(to: address, amount: uint256)
    event Burn(from_addr: address, amount: uint256)
    event OwnershipTransferred(previous_owner: address, new_owner: address)
    event Paused(account: address)
    event Unpaused(account: address)
    
    @constructor
    fn __init__(name: str, symbol: str, decimals: uint8, initial_supply: uint256):
        """
        Initialize the token.
        
        Args:
            name: Token name (e.g., "My Token")
            symbol: Token symbol (e.g., "MTK")
            decimals: Number of decimals (typically 18 for EVM, 9 for Solana)
            initial_supply: Initial token supply (minted to deployer)
        """
        self._name = name
        self._symbol = symbol
        self._decimals = decimals
        self._owner = msg.sender
        self._paused = False
        
        if initial_supply > 0:
            self._mint(msg.sender, initial_supply)
    
    # ========== View Functions ==========
    
    @view
    fn name() -> str:
        """Returns the token name."""
        return self._name
    
    @view
    fn symbol() -> str:
        """Returns the token symbol."""
        return self._symbol
    
    @view
    fn decimals() -> uint8:
        """Returns the number of decimals."""
        return self._decimals
    
    @view
    fn total_supply() -> uint256:
        """Returns the total token supply."""
        return self._total_supply
    
    @view
    fn balance_of(account: address) -> uint256:
        """
        Returns the token balance of an account.
        
        Args:
            account: Address to query
        
        Returns:
            Token balance
        """
        return self._balances[account]
    
    @view
    fn allowance(owner: address, spender: address) -> uint256:
        """
        Returns the allowance granted by owner to spender.
        
        Args:
            owner: Token owner address
            spender: Spender address
        
        Returns:
            Approved amount
        """
        return self._allowances[owner][spender]
    
    @view
    fn owner() -> address:
        """Returns the contract owner address."""
        return self._owner
    
    @view
    fn paused() -> bool:
        """Returns whether the contract is paused."""
        return self._paused
    
    # ========== External Functions ==========
    
    @external
    fn transfer(to: address, amount: uint256) -> bool:
        """
        Transfers tokens to another address.
        
        Args:
            to: Recipient address
            amount: Amount to transfer
        
        Returns:
            True on success
        """
        self._require_not_paused()
        self._transfer(msg.sender, to, amount)
        return True
    
    @external
    fn approve(spender: address, amount: uint256) -> bool:
        """
        Approves spender to transfer tokens on behalf of caller.
        
        Args:
            spender: Address to approve
            amount: Amount to approve
        
        Returns:
            True on success
        """
        self._approve(msg.sender, spender, amount)
        return True
    
    @external
    fn transfer_from(from_addr: address, to: address, amount: uint256) -> bool:
        """
        Transfers tokens using allowance mechanism.
        
        Args:
            from_addr: Source address
            to: Destination address
            amount: Amount to transfer
        
        Returns:
            True on success
        """
        self._require_not_paused()
        self._spend_allowance(from_addr, msg.sender, amount)
        self._transfer(from_addr, to, amount)
        return True
    
    @external
    fn increase_allowance(spender: address, added_value: uint256) -> bool:
        """
        Increases the allowance granted to spender.
        
        Args:
            spender: Spender address
            added_value: Amount to add to allowance
        
        Returns:
            True on success
        """
        current_allowance: uint256 = self._allowances[msg.sender][spender]
        self._approve(msg.sender, spender, safe_add(current_allowance, added_value))
        return True
    
    @external
    fn decrease_allowance(spender: address, subtracted_value: uint256) -> bool:
        """
        Decreases the allowance granted to spender.
        
        Args:
            spender: Spender address
            subtracted_value: Amount to subtract from allowance
        
        Returns:
            True on success
        """
        current_allowance: uint256 = self._allowances[msg.sender][spender]
        require(current_allowance >= subtracted_value, "Decreased allowance below zero")
        self._approve(msg.sender, spender, safe_sub(current_allowance, subtracted_value))
        return True
    
    # ========== Owner Functions ==========
    
    @external
    fn mint(to: address, amount: uint256):
        """
        Mints new tokens (owner only).
        
        Args:
            to: Recipient address
            amount: Amount to mint
        """
        self._only_owner()
        self._mint(to, amount)
    
    @external
    fn burn(amount: uint256):
        """
        Burns tokens from caller's balance.
        
        Args:
            amount: Amount to burn
        """
        self._burn(msg.sender, amount)
    
    @external
    fn burn_from(from_addr: address, amount: uint256):
        """
        Burns tokens from another address using allowance.
        
        Args:
            from_addr: Address to burn from
            amount: Amount to burn
        """
        self._spend_allowance(from_addr, msg.sender, amount)
        self._burn(from_addr, amount)
    
    @external
    fn pause():
        """Pauses all token transfers (owner only)."""
        self._only_owner()
        require(not self._paused, "Already paused")
        self._paused = True
        emit Paused(msg.sender)
    
    @external
    fn unpause():
        """Unpauses token transfers (owner only)."""
        self._only_owner()
        require(self._paused, "Not paused")
        self._paused = False
        emit Unpaused(msg.sender)
    
    @external
    fn transfer_ownership(new_owner: address):
        """
        Transfers contract ownership (owner only).
        
        Args:
            new_owner: New owner address
        """
        self._only_owner()
        require_not_zero_address(new_owner, "New owner is zero address")
        old_owner: address = self._owner
        self._owner = new_owner
        emit OwnershipTransferred(old_owner, new_owner)
    
    @external
    fn renounce_ownership():
        """Renounces ownership, leaving contract without owner."""
        self._only_owner()
        old_owner: address = self._owner
        self._owner = address(0)
        emit OwnershipTransferred(old_owner, address(0))
    
    # ========== Internal Functions ==========
    
    fn _transfer(from_addr: address, to: address, amount: uint256):
        """Internal transfer function."""
        require_not_zero_address(from_addr, "Transfer from zero address")
        require_not_zero_address(to, "Transfer to zero address")
        
        from_balance: uint256 = self._balances[from_addr]
        require(from_balance >= amount, "Transfer amount exceeds balance")
        
        self._balances[from_addr] = safe_sub(from_balance, amount)
        self._balances[to] = safe_add(self._balances[to], amount)
        
        emit Transfer(from_addr, to, amount)
    
    fn _mint(account: address, amount: uint256):
        """Internal mint function."""
        require_not_zero_address(account, "Mint to zero address")
        
        self._total_supply = safe_add(self._total_supply, amount)
        self._balances[account] = safe_add(self._balances[account], amount)
        
        emit Transfer(address(0), account, amount)
        emit Mint(account, amount)
    
    fn _burn(account: address, amount: uint256):
        """Internal burn function."""
        require_not_zero_address(account, "Burn from zero address")
        
        account_balance: uint256 = self._balances[account]
        require(account_balance >= amount, "Burn amount exceeds balance")
        
        self._balances[account] = safe_sub(account_balance, amount)
        self._total_supply = safe_sub(self._total_supply, amount)
        
        emit Transfer(account, address(0), amount)
        emit Burn(account, amount)
    
    fn _approve(owner: address, spender: address, amount: uint256):
        """Internal approve function."""
        require_not_zero_address(owner, "Approve from zero address")
        require_not_zero_address(spender, "Approve to zero address")
        
        self._allowances[owner][spender] = amount
        emit Approval(owner, spender, amount)
    
    fn _spend_allowance(owner: address, spender: address, amount: uint256):
        """Internal function to update allowance."""
        current_allowance: uint256 = self.allowance(owner, spender)
        
        # Check for unlimited allowance (max uint256)
        if current_allowance != 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff:
            require(current_allowance >= amount, "Insufficient allowance")
            self._approve(owner, spender, safe_sub(current_allowance, amount))
    
    fn _only_owner():
        """Modifier: requires caller to be owner."""
        require(msg.sender == self._owner, "Caller is not the owner")
    
    fn _require_not_paused():
        """Modifier: requires contract not to be paused."""
        require(not self._paused, "Token transfers are paused")
