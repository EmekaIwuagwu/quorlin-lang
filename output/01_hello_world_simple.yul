// Contract: HelloWorld
object "Contract" {
  code {
    // Constructor (deployment) code
    // Execute constructor
    sstore(0, 0x48656c6c6f2c20576f726c642100000000000000000000000000000000000000)

    // Copy runtime code to memory and return it
    datacopy(0, dataoffset("runtime"), datasize("runtime"))
    return(0, datasize("runtime"))
  }
  object "runtime" {
    code {

      // ========================================
      // CHECKED ARITHMETIC HELPERS
      // Prevent integer overflow/underflow
      // ========================================

      function checked_add(a, b) -> result {
          result := add(a, b)
          // Overflow check: result must be >= a
          if lt(result, a) { revert(0, 0) }
      }

      function checked_sub(a, b) -> result {
          // Underflow check: a must be >= b
          if lt(a, b) { revert(0, 0) }
          result := sub(a, b)
      }

      function checked_mul(a, b) -> result {
          result := mul(a, b)
          // Overflow check (except for zero)
          if iszero(b) { leave }
          if iszero(eq(div(result, b), a)) { revert(0, 0) }
      }

      function checked_div(a, b) -> result {
          // Division by zero check
          if iszero(b) { revert(0, 0) }
          result := div(a, b)
      }

      function checked_mod(a, b) -> result {
          // Modulo by zero check
          if iszero(b) { revert(0, 0) }
          result := mod(a, b)
      }

      // ========================================
      // Function dispatcher
      switch selector()
      case 0x7727cda7 { get_message() }
      case 0x01d1714f { set_message() }
      default { revert(0, 0) }

      function selector() -> s {
        s := div(calldataload(0), 0x100000000000000000000000000000000000000000000000000000000)
      }

      function get_message() {
        let ret := sload(0)
        mstore(0, ret)
        return(0, 32)
      }

      function set_message() {
        let new_message := calldataload(4)

        sstore(0, new_message)
        mstore(0, new_message)
        log1(0, 32, 0x000000000000000000000000000000000000000000000000e180410c8841cc0c)
      }

    }
  }
}
