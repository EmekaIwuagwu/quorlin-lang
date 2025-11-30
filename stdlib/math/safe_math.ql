# safe_math.ql — Safe arithmetic operations for Quorlin
# Provides overflow/underflow protection for mathematical operations

def safe_add(a: uint256, b: uint256) -> uint256:
    """
    Safely adds two uint256 numbers with overflow protection.
    Reverts if overflow would occur.
    """
    result: uint256 = a + b
    require(result >= a, "SafeMath: addition overflow")
    return result

def safe_sub(a: uint256, b: uint256) -> uint256:
    """
    Safely subtracts two uint256 numbers with underflow protection.
    Reverts if underflow would occur.
    """
    require(b <= a, "SafeMath: subtraction underflow")
    return a - b

def safe_mul(a: uint256, b: uint256) -> uint256:
    """
    Safely multiplies two uint256 numbers with overflow protection.
    Reverts if overflow would occur.
    """
    if a == 0:
        return 0

    result: uint256 = a * b
    require(result / a == b, "SafeMath: multiplication overflow")
    return result

def safe_div(a: uint256, b: uint256) -> uint256:
    """
    Safely divides two uint256 numbers.
    Reverts if dividing by zero.
    """
    require(b > 0, "SafeMath: division by zero")
    return a / b

def safe_mod(a: uint256, b: uint256) -> uint256:
    """
    Returns the modulus of two uint256 numbers.
    Reverts if dividing by zero.
    """
    require(b > 0, "SafeMath: modulo by zero")
    return a % b

def safe_pow(base: uint256, exponent: uint256) -> uint256:
    """
    Safely calculates base raised to exponent.
    Reverts on overflow.
    """
    if exponent == 0:
        return 1

    if base == 0:
        return 0

    result: uint256 = 1
    i: uint256 = 0

    while i < exponent:
        result = safe_mul(result, base)
        i = safe_add(i, 1)

    return result

def min(a: uint256, b: uint256) -> uint256:
    """Returns the smaller of two numbers."""
    if a < b:
        return a
    return b

def max(a: uint256, b: uint256) -> uint256:
    """Returns the larger of two numbers."""
    if a > b:
        return a
    return b

def average(a: uint256, b: uint256) -> uint256:
    """Returns the average of two numbers, rounded down."""
    return (a + b) / 2
