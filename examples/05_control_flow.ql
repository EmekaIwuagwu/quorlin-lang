# 05_control_flow.ql - Conditional logic and loops
#
# This example demonstrates:
# - if/elif/else statements
# - for loops with range()
# - while loops
# - break and continue
# - Boolean logic (and, or, not)
# - require statements

contract ControlFlowExample:
    """
    Demonstrates control flow structures in Quorlin.
    """

    result: uint256
    status: str

    # === Conditional Statements ===

    @external
    fn simple_if(value: uint256):
        """
        Basic if statement.
        """
        if value > 100:
            self.status = "high"
            self.result = value * 2

    @external
    fn if_else(value: uint256):
        """
        If-else statement.
        """
        if value > 100:
            self.status = "high"
            self.result = value * 2
        else:
            self.status = "low"
            self.result = value

    @external
    fn if_elif_else(value: uint256):
        """
        If-elif-else chain for multiple conditions.
        """
        if value > 1000:
            self.status = "very high"
            self.result = value * 3
        elif value > 100:
            self.status = "high"
            self.result = value * 2
        elif value > 10:
            self.status = "medium"
            self.result = value
        else:
            self.status = "low"
            self.result = value / 2

    @external
    fn nested_conditions(a: uint256, b: uint256):
        """
        Nested if statements.
        """
        if a > 50:
            if b > 50:
                self.status = "both high"
                self.result = a + b
            else:
                self.status = "a high, b low"
                self.result = a
        else:
            if b > 50:
                self.status = "a low, b high"
                self.result = b
            else:
                self.status = "both low"
                self.result = 0

    # === Boolean Logic ===

    @external
    fn boolean_and(a: uint256, b: uint256):
        """
        Using 'and' operator - both conditions must be true.
        """
        if a > 50 and b > 50:
            self.status = "both conditions true"
        else:
            self.status = "at least one false"

    @external
    fn boolean_or(a: uint256, b: uint256):
        """
        Using 'or' operator - at least one condition must be true.
        """
        if a > 100 or b > 100:
            self.status = "at least one high"
        else:
            self.status = "both low"

    @external
    fn boolean_not(is_active: bool):
        """
        Using 'not' operator - inverts boolean value.
        """
        if not is_active:
            self.status = "inactive"
        else:
            self.status = "active"

    @external
    fn complex_boolean(a: uint256, b: uint256, is_enabled: bool):
        """
        Complex boolean expressions with multiple operators.
        """
        if (a > 50 and b > 50) or is_enabled:
            self.status = "condition met"
        else:
            self.status = "condition not met"

    # === For Loops ===

    @external
    fn simple_for_loop(n: uint256) -> uint256:
        """
        Basic for loop using range(n).
        Iterates from 0 to n-1.
        """
        let sum: uint256 = 0

        for i in range(n):
            sum = sum + i

        self.result = sum
        return sum

    @external
    fn for_loop_with_start_end(start: uint256, end: uint256) -> uint256:
        """
        For loop with start and end using range(start, end).
        Iterates from start to end-1.
        """
        let sum: uint256 = 0

        for i in range(start, end):
            sum = sum + i

        self.result = sum
        return sum

    @external
    fn for_loop_with_step(start: uint256, end: uint256, step: uint256) -> uint256:
        """
        For loop with custom step using range(start, end, step).
        """
        let sum: uint256 = 0

        for i in range(start, end, step):
            sum = sum + i

        self.result = sum
        return sum

    @external
    fn for_loop_with_conditional(n: uint256) -> uint256:
        """
        For loop with conditional logic inside.
        Sums only even numbers.
        """
        let sum: uint256 = 0

        for i in range(n):
            if i % 2 == 0:
                sum = sum + i

        self.result = sum
        return sum

    # === While Loops ===

    @external
    fn simple_while_loop(n: uint256) -> uint256:
        """
        Basic while loop.
        """
        let count: uint256 = 0
        let sum: uint256 = 0

        while count < n:
            sum = sum + count
            count = count + 1

        self.result = sum
        return sum

    @external
    fn while_with_condition(target: uint256) -> uint256:
        """
        While loop with more complex condition.
        """
        let value: uint256 = 1

        while value < target:
            value = value * 2

        self.result = value
        return value

    # === Require Statements ===

    @external
    fn validate_inputs(a: uint256, b: uint256):
        """
        Using require for input validation.
        Transaction reverts if condition is false.
        """
        require(a > 0, "a must be positive")
        require(b > 0, "b must be positive")
        require(a < 1000, "a must be less than 1000")
        require(b < 1000, "b must be less than 1000")

        self.result = a + b

    @external
    fn validate_with_logic(value: uint256):
        """
        Require with complex boolean expressions.
        """
        require(value > 10 and value < 1000, "Value must be between 10 and 1000")
        require(value % 2 == 0 or value % 3 == 0, "Value must be divisible by 2 or 3")

        self.result = value

    # === Practical Examples ===

    @external
    fn calculate_factorial(n: uint256) -> uint256:
        """
        Calculate factorial using a for loop.
        Example: factorial(5) = 5 * 4 * 3 * 2 * 1 = 120
        """
        require(n > 0, "n must be positive")
        require(n <= 20, "n too large (risk of overflow)")

        let result: uint256 = 1

        for i in range(1, n + 1):
            result = result * i

        self.result = result
        return result

    @external
    fn is_prime(n: uint256) -> bool:
        """
        Check if a number is prime using a for loop.
        """
        if n <= 1:
            return False

        if n == 2:
            return True

        if n % 2 == 0:
            return False

        # Check odd divisors up to sqrt(n)
        let i: uint256 = 3
        while i * i <= n:
            if n % i == 0:
                return False
            i = i + 2

        return True

    @view
    fn get_result() -> uint256:
        """Read the stored result."""
        return self.result

    @view
    fn get_status() -> str:
        """Read the stored status."""
        return self.status

# Expected behavior:
#
# 1. Call if_elif_else(150)
#    → status = "high", result = 300
#
# 2. Call nested_conditions(60, 40)
#    → status = "a high, b low", result = 60
#
# 3. Call boolean_and(60, 40)
#    → status = "at least one false" (40 not > 50)
#
# 4. Call simple_for_loop(10)
#    → result = 0+1+2+...+9 = 45
#
# 5. Call for_loop_with_start_end(5, 10)
#    → result = 5+6+7+8+9 = 35
#
# 6. Call for_loop_with_step(0, 20, 5)
#    → result = 0+5+10+15 = 30
#
# 7. Call for_loop_with_conditional(10)
#    → result = 0+2+4+6+8 = 20
#
# 8. Call simple_while_loop(5)
#    → result = 0+1+2+3+4 = 10
#
# 9. Call while_with_condition(100)
#    → result = 128 (first power of 2 >= 100)
#
# 10. Call validate_inputs(0, 50)
#     → Reverts with "a must be positive"
#
# 11. Call calculate_factorial(5)
#     → result = 120
#
# 12. Call is_prime(17)
#     → Returns: true
