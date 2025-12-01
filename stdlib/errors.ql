# errors.ql — Standard error definitions for Quorlin

# Access control errors
error Unauthorized(address caller, address expected)
error MissingRole(address account, bytes32 role)
error InvalidOwner(address owner)

# Token errors
error InsufficientBalance(uint256 available, uint256 required)
error InsufficientAllowance(uint256 available, uint256 required)
error InvalidRecipient(address recipient)
error InvalidSender(address sender)

# Math errors
error MathOverflow()
error MathUnderflow()
error DivisionByZero()

# General errors
error InvalidAddress(address addr)
error InvalidAmount(uint256 amount)
error OperationFailed(str reason)
error NotImplemented(str feature)
