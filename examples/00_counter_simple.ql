# 00_counter_simple.ql - Simplest possible Quorlin contract
#
# A basic counter that can be incremented and read.
# This demonstrates the essential structure of a Quorlin smart contract.

event CounterIncremented(new_value: uint256)

contract Counter:
    """A simple counter contract."""

    # State variable - stores a number on the blockchain
    count: uint256

    @constructor
    fn __init__():
        """Initialize counter to zero."""
        self.count = 0

    @view
    fn get_count() -> uint256:
        """Read the current count (free, read-only)."""
        return self.count

    @external
    fn increment():
        """Increase the counter by 1 (costs gas)."""
        self.count = self.count + 1
        emit CounterIncremented(self.count)

    @external
    fn add(amount: uint256):
        """Add a specific amount to the counter."""
        self.count = self.count + amount
        emit CounterIncremented(self.count)

    @external
    fn reset():
        """Reset counter to zero."""
        self.count = 0
        emit CounterIncremented(0)

# To compile for different blockchains:
# qlc compile examples/00_counter_simple.ql --target evm -o counter.yul
# qlc compile examples/00_counter_simple.ql --target solana -o counter.rs
# qlc compile examples/00_counter_simple.ql --target ink -o counter.rs
