# 01_hello_world.ql - Your first Quorlin contract
#
# This example demonstrates the simplest possible Quorlin smart contract.
# It shows:
# - Basic contract structure
# - Constructor pattern
# - View functions (read-only)
# - Events
# - String storage

# Define an event (can be emitted by the contract)
event MessageChanged(old_message: str, new_message: str)

contract HelloWorld:
    """
    A simple Hello World contract.
    Stores a greeting message that can be read and updated.
    """

    # State variable - stored on blockchain
    message: str

    @constructor
    fn __init__():
        """Initialize the contract with a default message."""
        self.message = "Hello, World!"
        emit MessageChanged("", "Hello, World!")

    @view
    fn get_message() -> str:
        """
        Read the current message.

        This is a 'view' function - it doesn't modify state,
        so it's free to call and doesn't require a transaction.
        """
        return self.message

    @external
    fn set_message(new_message: str):
        """
        Update the message.

        This is an 'external' function - it modifies state,
        so calling it requires a transaction and costs gas.
        """
        emit MessageChanged(self.message, new_message)
        self.message = new_message

# Expected behavior:
# 1. Deploy contract → message is "Hello, World!"
# 2. Call get_message() → returns "Hello, World!"
# 3. Call set_message("Hello, Blockchain!") → emits MessageChanged event
# 4. Call get_message() → returns "Hello, Blockchain!"
