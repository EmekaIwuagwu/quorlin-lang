# Simple Counter Contract
# Demonstrates basic state management and functions

contract SimpleCounter:
    """A simple counter that can be incremented and decremented."""
    
    count: uint256
    owner: address
    
    event CountChanged:
        old_value: uint256
        new_value: uint256
    
    @constructor
    fn __init__():
        """Initialize counter to zero."""
        self.count = 0
        self.owner = msg.sender
    
    @external
    fn increment():
        """Increment the counter by 1."""
        let old_count = self.count
        self.count = self.count + 1
        emit CountChanged(old_count, self.count)
    
    @external
    fn decrement():
        """Decrement the counter by 1."""
        require(self.count > 0, "Counter cannot go below zero")
        let old_count = self.count
        self.count = self.count - 1
        emit CountChanged(old_count, self.count)
    
    @external
    fn add(amount: uint256):
        """Add a specific amount to the counter."""
        let old_count = self.count
        self.count = self.count + amount
        emit CountChanged(old_count, self.count)
    
    @view
    fn get_count() -> uint256:
        """Get the current count."""
        return self.count
    
    @external
    fn reset():
        """Reset counter to zero (owner only)."""
        require(msg.sender == self.owner, "Only owner can reset")
        let old_count = self.count
        self.count = 0
        emit CountChanged(old_count, 0)
