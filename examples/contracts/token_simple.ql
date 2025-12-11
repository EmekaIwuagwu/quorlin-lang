# Simple Token Contract
# Basic ERC20-style token without stdlib dependencies

event Transfer(from_address: address, to: address, amount: uint256)
event Approval(owner: address, spender: address, amount: uint256)
event Mint(to: address, amount: uint256)

contract SimpleToken:
    """
    Basic fungible token implementation.
    Compiles to all blockchain backends.
    """
    
    # State variables
    _name: str
    _symbol: str
    _decimals: uint256
    _total_supply: uint256
    _owner: address
    
    # Balances and allowances
    _balances: mapping[address, uint256]
    _allowances: mapping[address, mapping[address, uint256]]
    
    @constructor
    fn __init__(name: str, symbol: str, decimals: uint256, initial_supply: uint256):
        """Initialize the token."""
        self._name = name
        self._symbol = symbol
        self._decimals = decimals
        self._owner = msg.sender
        self._total_supply = initial_supply
        self._balances[msg.sender] = initial_supply
        
        emit Mint(msg.sender, initial_supply)
        emit Transfer(address(0), msg.sender, initial_supply)
    
    @view
    fn name() -> str:
        """Returns token name."""
        return self._name
    
    @view
    fn symbol() -> str:
        """Returns token symbol."""
        return self._symbol
    
    @view
    fn decimals() -> uint256:
        """Returns number of decimals."""
        return self._decimals
    
    @view
    fn total_supply() -> uint256:
        """Returns total token supply."""
        return self._total_supply
    
    @view
    fn balance_of(account: address) -> uint256:
        """Returns balance of an account."""
        return self._balances[account]
    
    @view
    fn allowance(owner: address, spender: address) -> uint256:
        """Returns allowance for spender from owner."""
        return self._allowances[owner][spender]
    
    @external
    fn transfer(to: address, amount: uint256):
        """Transfer tokens to another address."""
        require(to != address(0), "Cannot send to zero address")
        require(self._balances[msg.sender] >= amount, "Insufficient balance")
        
        self._balances[msg.sender] = self._balances[msg.sender] - amount
        self._balances[to] = self._balances[to] + amount
        
        emit Transfer(msg.sender, to, amount)
    
    @external
    fn approve(spender: address, amount: uint256):
        """Approve spender to spend tokens."""
        require(spender != address(0), "Cannot approve zero address")
        
        self._allowances[msg.sender][spender] = amount
        emit Approval(msg.sender, spender, amount)
    
    @external
    fn transfer_from(from_address: address, to: address, amount: uint256):
        """Transfer tokens using allowance."""
        require(to != address(0), "Cannot send to zero address")
        require(self._balances[from_address] >= amount, "Insufficient balance")
        require(self._allowances[from_address][msg.sender] >= amount, "Insufficient allowance")
        
        self._balances[from_address] = self._balances[from_address] - amount
        self._balances[to] = self._balances[to] + amount
        self._allowances[from_address][msg.sender] = self._allowances[from_address][msg.sender] - amount
        
        emit Transfer(from_address, to, amount)
    
    @external
    fn mint(to: address, amount: uint256):
        """Mint new tokens (owner only)."""
        require(msg.sender == self._owner, "Insufficient allowance")
        require(to != address(0), "Cannot send to zero address")
        
        self._total_supply = self._total_supply + amount
        self._balances[to] = self._balances[to] + amount
        
        emit Mint(to, amount)
        emit Transfer(address(0), to, amount)
