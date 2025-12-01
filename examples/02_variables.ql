# 02_variables.ql - Working with variables and types
#
# This example demonstrates:
# - Different data types (integers, booleans, addresses, strings)
# - State variables vs local variables
# - Type annotations
# - Variable assignments and updates

contract VariablesExample:
    """
    Demonstrates variable types and usage in Quorlin.
    """

    # === State Variables (stored on blockchain) ===

    # Unsigned integers (non-negative numbers)
    counter: uint256 = 0          # 256-bit unsigned integer (most common for amounts)
    small_number: uint8 = 100     # 8-bit unsigned integer (0 to 255)

    # Signed integers (can be negative)
    temperature: int256 = -40     # 256-bit signed integer

    # Boolean (true/false)
    is_active: bool = True
    is_paused: bool = False

    # Address (Ethereum/blockchain address)
    owner: address

    # String
    name: str = "Variables Demo"

    # Bytes (fixed-size byte array)
    data: bytes32

    @constructor
    fn __init__(initial_owner: address):
        """Initialize with an owner address."""
        self.owner = initial_owner

    @external
    fn demonstrate_local_variables():
        """
        Shows how to use local variables within a function.
        Local variables only exist during function execution.
        """
        # Local variables with type inference
        let x: uint256 = 42
        let y: uint256 = 10

        # Arithmetic with local variables
        let sum: uint256 = x + y            # 52
        let difference: uint256 = x - y     # 32
        let product: uint256 = x * y        # 420
        let quotient: uint256 = x / y       # 4

        # Update state variable using local variable
        self.counter = sum

    @external
    fn demonstrate_state_updates():
        """
        Shows different ways to update state variables.
        """
        # Direct assignment
        self.counter = 100

        # Arithmetic assignment operators
        self.counter += 50        # counter is now 150
        self.counter -= 30        # counter is now 120
        self.counter *= 2         # counter is now 240
        self.counter /= 4         # counter is now 60

        # Boolean operations
        self.is_active = True
        self.is_paused = not self.is_active  # False

    @external
    fn demonstrate_special_variables():
        """
        Shows built-in global variables available in contracts.
        """
        # msg.sender - address of the account calling this function
        let caller: address = msg.sender

        # msg.value - amount of native currency sent with the transaction
        let payment: uint256 = msg.value

        # block.timestamp - current block timestamp
        let current_time: uint256 = block.timestamp

        # block.number - current block number
        let current_block: uint256 = block.number

        # Update owner if caller sent value
        if msg.value > 0:
            self.owner = msg.sender

    @view
    fn get_counter() -> uint256:
        """Read the current counter value."""
        return self.counter

    @view
    fn get_owner() -> address:
        """Read the current owner address."""
        return self.owner

    @view
    fn get_status() -> bool:
        """Read the active status."""
        return self.is_active

# Expected behavior:
# 1. Deploy with owner address → owner is set
# 2. Call demonstrate_local_variables() → counter becomes 52
# 3. Call demonstrate_state_updates() → counter becomes 60
# 4. Call get_counter() → returns 60
# 5. Call demonstrate_special_variables() with value → owner changes to msg.sender
