// Contract: ControlFlowExample
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
      case 0x98934f98 { simple_if() }
      case 0xdebd2789 { if_else() }
      case 0xdf83a103 { if_elif_else() }
      case 0xb72988e3 { nested_conditions() }
      case 0x82de31e7 { boolean_and() }
      case 0x7044a176 { boolean_or() }
      case 0x977eecfc { boolean_not() }
      case 0x164cf2ae { complex_boolean() }
      case 0x8b485dde { simple_for_loop() }
      case 0x8e812103 { for_loop_with_start_end() }
      case 0x9524ef8f { for_loop_with_step() }
      case 0x46954d8f { for_loop_with_conditional() }
      case 0xf13909e7 { simple_while_loop() }
      case 0x37cbf5ac { while_with_condition() }
      case 0x0d3119f7 { validate_inputs() }
      case 0x104e707c { validate_with_logic() }
      case 0xa90f76d6 { calculate_factorial() }
      case 0xcf49059e { is_prime() }
      case 0xb1a36e6d { get_result() }
      case 0xe1bbded1 { get_status() }
      default { revert(0, 0) }

      function selector() -> s {
        s := div(calldataload(0), 0x100000000000000000000000000000000000000000000000000000000)
      }

      function simple_if() {
        let value := calldataload(4)

        if gt(value, 100) {
          sstore(1, 0x6869676800000000000000000000000000000000000000000000000000000000)
          sstore(0, checked_mul(value, 2))
        }
      }

      function if_else() {
        let value := calldataload(4)

        if gt(value, 100) {
          sstore(1, 0x6869676800000000000000000000000000000000000000000000000000000000)
          sstore(0, checked_mul(value, 2))
        }
        // else
        {
          sstore(1, 0x6c6f770000000000000000000000000000000000000000000000000000000000)
          sstore(0, value)
        }
      }

      function if_elif_else() {
        let value := calldataload(4)

        if gt(value, 1000) {
          sstore(1, 0x7665727920686967680000000000000000000000000000000000000000000000)
          sstore(0, checked_mul(value, 3))
        }
        if gt(value, 100) {
          sstore(1, 0x6869676800000000000000000000000000000000000000000000000000000000)
          sstore(0, checked_mul(value, 2))
        }
        if gt(value, 10) {
          sstore(1, 0x6d656469756d0000000000000000000000000000000000000000000000000000)
          sstore(0, value)
        }
        // else
        {
          sstore(1, 0x6c6f770000000000000000000000000000000000000000000000000000000000)
          sstore(0, checked_div(value, 2))
        }
      }

      function nested_conditions() {
        let a := calldataload(4)
        let b := calldataload(36)

        if gt(a, 50) {
          if gt(b, 50) {
            sstore(1, 0x626f746820686967680000000000000000000000000000000000000000000000)
            sstore(0, checked_add(a, b))
          }
          // else
          {
            sstore(1, 0x6120686967682c2062206c6f7700000000000000000000000000000000000000)
            sstore(0, a)
          }
        }
        // else
        {
          if gt(b, 50) {
            sstore(1, 0x61206c6f772c2062206869676800000000000000000000000000000000000000)
            sstore(0, b)
          }
          // else
          {
            sstore(1, 0x626f7468206c6f77000000000000000000000000000000000000000000000000)
            sstore(0, 0)
          }
        }
      }

      function boolean_and() {
        let a := calldataload(4)
        let b := calldataload(36)

        if and(gt(a, 50), gt(b, 50)) {
          sstore(1, 0x626f746820636f6e646974696f6e732074727565000000000000000000000000)
        }
        // else
        {
          sstore(1, 0x6174206c65617374206f6e652066616c73650000000000000000000000000000)
        }
      }

      function boolean_or() {
        let a := calldataload(4)
        let b := calldataload(36)

        if or(gt(a, 100), gt(b, 100)) {
          sstore(1, 0x6174206c65617374206f6e652068696768000000000000000000000000000000)
        }
        // else
        {
          sstore(1, 0x626f7468206c6f77000000000000000000000000000000000000000000000000)
        }
      }

      function boolean_not() {
        let is_active := calldataload(4)

        if iszero(is_active) {
          sstore(1, 0x696e616374697665000000000000000000000000000000000000000000000000)
        }
        // else
        {
          sstore(1, 0x6163746976650000000000000000000000000000000000000000000000000000)
        }
      }

      function complex_boolean() {
        let a := calldataload(4)
        let b := calldataload(36)
        let is_enabled := calldataload(68)

        if or(and(gt(a, 50), gt(b, 50)), is_enabled) {
          sstore(1, 0x636f6e646974696f6e206d657400000000000000000000000000000000000000)
        }
        // else
        {
          sstore(1, 0x636f6e646974696f6e206e6f74206d6574000000000000000000000000000000)
        }
      }

      function simple_for_loop() {
        let n := calldataload(4)

        let sum := 0
        for { let i := 0 } lt(i, n) { i := add(i, 1) }
        {
         let sum := checked_add(sum, i)
        }
        sstore(0, sum)
        let ret := sum
        mstore(0, ret)
        return(0, 32)
      }

      function for_loop_with_start_end() {
        let start := calldataload(4)
        let end := calldataload(36)

        let sum := 0
        for { let i := start } lt(i, end) { i := add(i, 1) }
        {
         let sum := checked_add(sum, i)
        }
        sstore(0, sum)
        let ret := sum
        mstore(0, ret)
        return(0, 32)
      }

      function for_loop_with_step() {
        let start := calldataload(4)
        let end := calldataload(36)
        let step := calldataload(68)

        let sum := 0
        for { let i := start } lt(i, end) { i := add(i, step) }
        {
         let sum := checked_add(sum, i)
        }
        sstore(0, sum)
        let ret := sum
        mstore(0, ret)
        return(0, 32)
      }

      function for_loop_with_conditional() {
        let n := calldataload(4)

        let sum := 0
        for { let i := 0 } lt(i, n) { i := add(i, 1) }
        {
         if eq(checked_mod(i, 2), 0) {
           let sum := checked_add(sum, i)
         }
        }
        sstore(0, sum)
        let ret := sum
        mstore(0, ret)
        return(0, 32)
      }

      function simple_while_loop() {
        let n := calldataload(4)

        let count := 0
        let sum := 0
        for {} lt(count, n) {}
        {
          let sum := checked_add(sum, count)
          let count := checked_add(count, 1)
        }
        sstore(0, sum)
        let ret := sum
        mstore(0, ret)
        return(0, 32)
      }

      function while_with_condition() {
        let target := calldataload(4)

        let value := 1
        for {} lt(value, target) {}
        {
          let value := checked_mul(value, 2)
        }
        sstore(0, value)
        let ret := value
        mstore(0, ret)
        return(0, 32)
      }

      function validate_inputs() {
        let a := calldataload(4)
        let b := calldataload(36)

        if iszero(gt(a, 0)) { revert(0, 0) }
        if iszero(gt(b, 0)) { revert(0, 0) }
        if iszero(lt(a, 1000)) { revert(0, 0) }
        if iszero(lt(b, 1000)) { revert(0, 0) }
        sstore(0, checked_add(a, b))
      }

      function validate_with_logic() {
        let value := calldataload(4)

        if iszero(and(gt(value, 10), lt(value, 1000))) { revert(0, 0) }
        if iszero(or(eq(checked_mod(value, 2), 0), eq(checked_mod(value, 3), 0))) { revert(0, 0) }
        sstore(0, value)
      }

      function calculate_factorial() {
        let n := calldataload(4)

        if iszero(gt(n, 0)) { revert(0, 0) }
        if iszero(iszero(gt(n, 20)))) { revert(0, 0) }
        sstore(0, 1)
        for { let i := 1 } lt(i, checked_add(n, 1)) { i := add(i, 1) }
        {
         sstore(0, checked_mul(sload(0), i))
        }
        sstore(0, sload(0))
        let ret := sload(0)
        mstore(0, ret)
        return(0, 32)
      }

      function is_prime() {
        let n := calldataload(4)

        if iszero(gt(n, 1))) {
          let ret := 0
          mstore(0, ret)
          return(0, 32)
        }
        if eq(n, 2) {
          let ret := 1
          mstore(0, ret)
          return(0, 32)
        }
        if eq(checked_mod(n, 2), 0) {
          let ret := 0
          mstore(0, ret)
          return(0, 32)
        }
        let i := 3
        for {} iszero(gt(checked_mul(i, i), n))) {}
        {
          if eq(checked_mod(n, i), 0) {
            let ret := 0
            mstore(0, ret)
            return(0, 32)
          }
          let i := checked_add(i, 2)
        }
        let ret := 1
        mstore(0, ret)
        return(0, 32)
      }

      function get_result() {
        let ret := sload(0)
        mstore(0, ret)
        return(0, 32)
      }

      function get_status() {
        let ret := sload(1)
        mstore(0, ret)
        return(0, 32)
      }

    }
  }
}
