# 04_functions.ql - Functions, parameters, and return values
#
# This example demonstrates:
# - Function definitions with fn keyword
# - Function parameters and return types
# - Function decorators (@external, @view, @constructor)
# - Public vs internal functions
# - Function calls
# - Require statements for validation

event OperationPerformed(operation: str, input: uint256, output: uint256)

contract FunctionsExample:
    """
    Demonstrates different types of functions in Quorlin.
    """

    # State
    value: uint256
    owner: address

    # === Constructor ===

    @constructor
    fn __init__(initial_value: uint256):
        """
        Constructor - called once when contract is deployed.
        Used to initialize state variables.
        """
        self.value = initial_value
        self.owner = msg.sender

    # === External Functions ===
    # Can be called from outside the contract (by users or other contracts)

    @external
    fn set_value(new_value: uint256):
        """
        Simple function with one parameter, no return value.
        """
        require(msg.sender == self.owner, "Only owner can set value")
        self.value = new_value

    @external
    fn add(amount: uint256) -> uint256:
        """
        Function with parameter and return value.
        """
        self.value = self.value + amount
        emit OperationPerformed("add", amount, self.value)
        return self.value

    @external
    fn multiply(multiplier: uint256) -> uint256:
        """
        Another function with parameter and return value.
        """
        self.value = self.value * multiplier
        emit OperationPerformed("multiply", multiplier, self.value)
        return self.value

    @external
    fn complex_calculation(a: uint256, b: uint256, c: uint256) -> uint256:
        """
        Function with multiple parameters.
        Demonstrates calling internal helper functions.
        """
        let step1: uint256 = self._internal_add(a, b)
        let step2: uint256 = self._internal_multiply(step1, c)
        self.value = step2
        return step2

    # === View Functions ===
    # Read-only functions that don't modify state

    @view
    fn get_value() -> uint256:
        """
        Simple getter function.
        View functions are free to call (no gas cost for reads).
        """
        return self.value

    @view
    fn get_owner() -> address:
        """
        Another getter function.
        """
        return self.owner

    @view
    fn calculate_without_storing(a: uint256, b: uint256) -> uint256:
        """
        View function that performs calculations without modifying state.
        """
        return (a + b) * 2

    @view
    fn is_owner(address_to_check: address) -> bool:
        """
        View function returning a boolean.
        """
        return address_to_check == self.owner

    # === Internal Functions ===
    # Can only be called from within the contract
    # Note: Quorlin uses underscore prefix for internal functions by convention

    fn _internal_add(a: uint256, b: uint256) -> uint256:
        """
        Internal helper function for addition.
        Not marked as @external or @view, so it's internal by default.
        """
        return a + b

    fn _internal_multiply(a: uint256, b: uint256) -> uint256:
        """
        Internal helper function for multiplication.
        """
        return a * b

    fn _validate_positive(amount: uint256):
        """
        Internal validation function with no return value.
        """
        require(amount > 0, "Amount must be positive")

    # === Functions with Validation ===

    @external
    fn transfer_ownership(new_owner: address):
        """
        Demonstrates input validation with require.
        """
        require(msg.sender == self.owner, "Only current owner can transfer")
        require(new_owner != address(0), "New owner cannot be zero address")
        self.owner = new_owner

    @external
    fn safe_divide(numerator: uint256, denominator: uint256) -> uint256:
        """
        Function with multiple validation checks.
        """
        require(denominator != 0, "Cannot divide by zero")
        require(numerator >= denominator, "Numerator must be >= denominator")

        let result: uint256 = numerator / denominator
        return result

    # === Functions Demonstrating Control Flow ===

    @external
    fn conditional_operation(amount: uint256) -> str:
        """
        Function with conditional logic.
        """
        if amount > 100:
            self.value = amount * 2
            return "large"
        else:
            self.value = amount
            return "small"

    @external
    fn sum_range(n: uint256) -> uint256:
        """
        Function with loop to calculate sum of 1 to n.
        """
        let total: uint256 = 0

        for i in range(n + 1):
            total = total + i

        self.value = total
        return total

# Expected behavior:
#
# 1. Deploy with initial_value=100
#    → value = 100, owner = deployer address
#
# 2. Call get_value()
#    → Returns: 100
#
# 3. Call add(50)
#    → value = 150, returns 150, emits OperationPerformed event
#
# 4. Call multiply(2)
#    → value = 300, returns 300
#
# 5. Call complex_calculation(10, 20, 5)
#    → Calculates (10 + 20) * 5 = 150
#    → value = 150, returns 150
#
# 6. Call calculate_without_storing(25, 75)
#    → Returns: (25 + 75) * 2 = 200
#    → value unchanged (still 150)
#
# 7. Call is_owner(deployer_address)
#    → Returns: true
#
# 8. Call safe_divide(100, 5)
#    → Returns: 20
#
# 9. Call safe_divide(100, 0)
#    → Reverts with "Cannot divide by zero"
#
# 10. Call conditional_operation(150)
#     → value = 300, returns "large"
#
# 11. Call sum_range(10)
#     → Calculates 1+2+3+...+10 = 55
#     → value = 55, returns 55
