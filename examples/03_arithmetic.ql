# 03_arithmetic.ql - Arithmetic operations and overflow protection
#
# This example demonstrates:
# - Basic arithmetic operations (+, -, *, /, %)
# - Safe arithmetic (overflow protection)
# - Comparison operations
# - Order of operations

from std.math import safe_add, safe_sub, safe_mul, safe_div

contract ArithmeticExample:
    """
    Demonstrates arithmetic operations in Quorlin.
    All operations have built-in overflow/underflow protection!
    """

    result: uint256

    @external
    fn basic_operations(a: uint256, b: uint256) -> uint256:
        """
        Perform basic arithmetic operations.
        All operations are automatically checked for overflow/underflow.
        """
        # Addition
        let sum: uint256 = a + b

        # Subtraction (will revert if b > a to prevent underflow)
        let diff: uint256 = a - b

        # Multiplication
        let product: uint256 = a * b

        # Division (will revert if b == 0)
        let quotient: uint256 = a / b

        # Modulo (remainder)
        let remainder: uint256 = a % b

        # Store result
        self.result = sum + diff + product + quotient + remainder

        return self.result

    @external
    fn safe_operations(a: uint256, b: uint256) -> uint256:
        """
        Explicit safe arithmetic using standard library.
        These are equivalent to the built-in operators.
        """
        # Safe addition - reverts on overflow
        let sum: uint256 = safe_add(a, b)

        # Safe subtraction - reverts on underflow
        let diff: uint256 = safe_sub(a, b)

        # Safe multiplication - reverts on overflow
        let product: uint256 = safe_mul(a, b)

        # Safe division - reverts on division by zero
        let quotient: uint256 = safe_div(a, b)

        return safe_add(sum, diff)

    @external
    fn comparison_operations(a: uint256, b: uint256) -> bool:
        """
        Demonstrates comparison operators.
        """
        # Equality
        let is_equal: bool = a == b

        # Inequality
        let is_not_equal: bool = a != b

        # Greater than
        let is_greater: bool = a > b

        # Less than
        let is_less: bool = a < b

        # Greater than or equal
        let is_greater_equal: bool = a >= b

        # Less than or equal
        let is_less_equal: bool = a <= b

        return is_greater

    @external
    fn order_of_operations(a: uint256, b: uint256, c: uint256) -> uint256:
        """
        Demonstrates order of operations (PEMDAS).
        Parentheses, Exponents, Multiplication/Division, Addition/Subtraction
        """
        # Without parentheses: multiplication happens first
        let result1: uint256 = a + b * c  # a + (b * c)

        # With parentheses: explicit ordering
        let result2: uint256 = (a + b) * c

        # Complex expression
        let result3: uint256 = (a + b) * c / (b - a + 1)

        return result3

    @external
    fn compound_assignments(value: uint256):
        """
        Demonstrates compound assignment operators.
        """
        self.result = value

        # These are equivalent to self.result = self.result + value
        self.result += 10   # Add 10
        self.result -= 5    # Subtract 5
        self.result *= 2    # Multiply by 2
        self.result /= 3    # Divide by 3

    @external
    fn demonstrate_overflow_protection():
        """
        Shows overflow protection in action.
        This function will revert if overflow would occur.
        """
        # Maximum uint256 value
        let max_value: uint256 = 115792089237316195423570985008687907853269984665640564039457584007913129639935

        # This would overflow, so it will revert
        # let overflow: uint256 = max_value + 1  # ← This line would cause revert

        # Instead, we can check before adding
        if max_value > 1000:
            self.result = max_value - 1000

    @view
    fn get_result() -> uint256:
        """Read the stored result."""
        return self.result

# Expected behavior:
# 1. Call basic_operations(100, 10)
#    → Returns: 100 + 90 + 1000 + 10 + 0 = 1200
#
# 2. Call safe_operations(50, 25)
#    → Returns: 75 + 25 = 100
#
# 3. Call comparison_operations(100, 50)
#    → Returns: true (100 > 50)
#
# 4. Call order_of_operations(5, 10, 2)
#    → Returns: (5 + 10) * 2 / (10 - 5 + 1) = 15 * 2 / 6 = 5
#
# 5. Call compound_assignments(100)
#    → result becomes: ((100 + 10 - 5) * 2) / 3 = 70
#
# 6. Call demonstrate_overflow_protection()
#    → Sets result safely without overflow
