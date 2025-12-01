# ownable.ql — Ownership access control for Quorlin contracts
# Provides basic authorization control with a single owner

from std.errors import Unauthorized

# Events
event OwnershipTransferred(previous_owner: address, new_owner: address)

contract Ownable:
    """
    Contract module providing basic access control where there is
    an account (an owner) that can be granted exclusive access to
    specific functions.
    """

    # State
    owner: address

    @constructor
    fn __init__():
        """Initialize contract with deployer as owner."""
        self.owner = msg.sender
        emit OwnershipTransferred(address(0), msg.sender)

    # Modifiers (implemented as internal functions)
    fn _only_owner():
        """Throws if called by any account other than the owner."""
        require(msg.sender == self.owner, "Ownable: caller is not the owner")

    @view
    fn get_owner() -> address:
        """Returns the address of the current owner."""
        return self.owner

    @external
    fn renounce_ownership():
        """
        Leaves the contract without owner. It will not be possible to call
        functions with the onlyOwner modifier anymore.
        """
        self._only_owner()
        emit OwnershipTransferred(self.owner, address(0))
        self.owner = address(0)

    @external
    fn transfer_ownership(new_owner: address):
        """
        Transfers ownership of the contract to a new account.
        Can only be called by the current owner.
        """
        self._only_owner()
        require(new_owner != address(0), "Ownable: new owner is the zero address")
        emit OwnershipTransferred(self.owner, new_owner)
        self.owner = new_owner
