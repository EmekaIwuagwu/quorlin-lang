// Contract: ArithmeticExample
object "Contract" {
  code {
    // Constructor (deployment) code
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
      case 0xa6393cff { basic_operations() }
      case 0x2e220991 { safe_operations() }
      case 0xbd7523e5 { comparison_operations() }
      case 0x621f346d { order_of_operations() }
      case 0x1558fd38 { compound_assignments() }
      case 0x81ee6cf0 { demonstrate_overflow_protection() }
      case 0xb1a36e6d { get_result() }
      default { revert(0, 0) }

      function selector() -> s {
        s := div(calldataload(0), 0x100000000000000000000000000000000000000000000000000000000)
      }

      function basic_operations() {
        let a := calldataload(4)
        let b := calldataload(36)

        let sum := checked_add(a, b)
        let diff := checked_sub(a, b)
        let product := checked_mul(a, b)
        let quotient := checked_div(a, b)
        let remainder := checked_mod(a, b)
        sstore(0, checked_add(checked_add(checked_add(checked_add(sum, diff), product), quotient), remainder))
        let ret := sload(0)
        mstore(0, ret)
        return(0, 32)
      }

      function safe_operations() {
        let a := calldataload(4)
        let b := calldataload(36)

        let sum := checked_add(a, b)
        let diff := checked_sub(a, b)
        let product := checked_mul(a, b)
        let quotient := checked_div(a, b)
        let ret := checked_add(sum, diff)
        mstore(0, ret)
        return(0, 32)
      }

      function comparison_operations() {
        let a := calldataload(4)
        let b := calldataload(36)

        let is_equal := eq(a, b)
        let is_not_equal := iszero(eq(a, b)))
        let is_greater := gt(a, b)
        let is_less := lt(a, b)
        let is_greater_equal := iszero(lt(a, b)))
        let is_less_equal := iszero(gt(a, b)))
        let ret := is_greater
        mstore(0, ret)
        return(0, 32)
      }

      function order_of_operations() {
        let a := calldataload(4)
        let b := calldataload(36)
        let c := calldataload(68)

        let result1 := checked_mul(checked_add(a, b), c)
        let result2 := checked_mul(checked_add(a, b), c)
        let result3 := checked_div(checked_mul(checked_add(a, b), c), checked_add(checked_sub(b, a), 1))
        let ret := result3
        mstore(0, ret)
        return(0, 32)
      }

      function compound_assignments() {
        let value := calldataload(4)

        sstore(0, value)
        sstore(0, checked_add(sload(0), 10))
        sstore(0, checked_sub(sload(0), 5))
        sstore(0, checked_mul(sload(0), 2))
        sstore(0, checked_div(sload(0), 3))
      }

      function demonstrate_overflow_protection() {
        let max_value := 115792089237316195423570985008687907853269984665640564039457584007913129639935
        if gt(max_value, 1000) {
          sstore(0, checked_sub(max_value, 1000))
        }
      }

      function get_result() {
        let ret := sload(0)
        mstore(0, ret)
        return(0, 32)
      }

    }
  }
}
