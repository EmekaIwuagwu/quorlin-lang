// Contract: Counter
object "Contract" {
  code {
    // Constructor (deployment) code
    // Execute constructor
    sstore(0, 0)

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
      case 0x8b241b58 { get_count() }
      case 0x6c4866b9 { increment() }
      case 0x19a9f771 { add() }
      case 0x686462e7 { reset() }
      default { revert(0, 0) }

      function selector() -> s {
        s := div(calldataload(0), 0x100000000000000000000000000000000000000000000000000000000)
      }

      function get_count() {
        let ret := sload(0)
        mstore(0, ret)
        return(0, 32)
      }

      function increment() {
        sstore(0, checked_add(sload(0), 1))
        mstore(0, sload(0))
        log1(0, 32, 0x000000000000000000000000000000000000000000000000444cf4967a58f27a)
      }

      function add() {
        let amount := calldataload(4)

        sstore(0, checked_add(sload(0), amount))
        mstore(0, sload(0))
        log1(0, 32, 0x000000000000000000000000000000000000000000000000444cf4967a58f27a)
      }

      function reset() {
        sstore(0, 0)
        mstore(0, 0)
        log1(0, 32, 0x000000000000000000000000000000000000000000000000444cf4967a58f27a)
      }

    }
  }
}
