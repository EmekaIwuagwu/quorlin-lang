# Simple Counter - Minimal test contract
# No stdlib dependencies

event Incremented(counter: uint256)
event Decremented(counter: uint256)

contract Counter:
    """
    Simple counter contract for testing compilation.
    Compiles to all backends without stdlib dependencies.
    """
    
    # State variables
    _count: uint256
    _owner: address
    
    @constructor
    fn __init__(initial_count: uint256):
        """Initialize the counter."""
        self._count = initial_count
        self._owner = msg.sender
    
    @view
    fn get_count() -> uint256:
        """Returns the current count."""
        return self._count
    
    @view
    fn get_owner() -> address:
        """Returns the owner address."""
        return self._owner
    
    @external
    fn increment():
        """Increments the counter by 1."""
        self._count = self._count + 1
        emit Incremented(self._count)
    
    @external
    fn decrement():
        """Decrements the counter by 1."""
        require(self._count > 0, "Insufficient balance")
        self._count = self._count - 1
        emit Decremented(self._count)
    
    @external
    fn add(amount: uint256):
        """Adds an amount to the counter."""
        require(msg.sender == self._owner, "Insufficient allowance")
        self._count = self._count + amount
        emit Incremented(self._count)
    
    @external
    fn reset():
        """Resets counter to zero (owner only)."""
        require(msg.sender == self._owner, "Insufficient allowance")
        self._count = 0
