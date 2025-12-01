# 01_hello_world_simple.ql - Your first Quorlin contract
#
# This is a simplified, working version of the Hello World example.

event MessageChanged(new_message: str)

contract HelloWorld:
    """A simple Hello World contract."""

    message: str

    @constructor
    fn __init__():
        """Initialize with default message."""
        self.message = "Hello, World!"

    @view
    fn get_message() -> str:
        """Get the current message."""
        return self.message

    @external
    fn set_message(new_message: str):
        """Update the message."""
        self.message = new_message
        emit MessageChanged(new_message)

# To compile:
# qlc compile examples/01_hello_world_simple.ql --target evm -o hello.yul
