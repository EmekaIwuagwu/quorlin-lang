// Contract: VariablesExample
object "Contract" {
  code {
    // Constructor (deployment) code
    // Execute constructor
    let initial_owner := calldataload(0)

    sstore(5, initial_owner)

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
      case 0xffb0fd47 { demonstrate_local_variables() }
      case 0x3803a5a6 { demonstrate_state_updates() }
      case 0x989d4374 { demonstrate_special_variables() }
      case 0x9e17db73 { get_counter() }
      case 0x0b4a949d { get_owner() }
      case 0xe1bbded1 { get_status() }
      default { revert(0, 0) }

      function selector() -> s {
        s := div(calldataload(0), 0x100000000000000000000000000000000000000000000000000000000)
      }

      function demonstrate_local_variables() {
        let x := 42
        let y := 10
        let sum := checked_add(x, y)
        let difference := checked_sub(x, y)
        let product := checked_mul(x, y)
        let quotient := checked_div(x, y)
        sstore(0, sum)
      }

      function demonstrate_state_updates() {
        sstore(0, 100)
        sstore(0, checked_add(sload(0), 50))
        sstore(0, checked_sub(sload(0), 30))
        sstore(0, checked_mul(sload(0), 2))
        sstore(0, checked_div(sload(0), 4))
        sstore(3, 1)
        sstore(4, iszero(sload(3)))
      }

      function demonstrate_special_variables() {
        let caller := caller()
        let payment := callvalue()
        let current_time := timestamp()
        let current_block := number()
        if gt(callvalue(), 0) {
          sstore(5, caller())
        }
      }

      function get_counter() {
        let ret := sload(0)
        mstore(0, ret)
        return(0, 32)
      }

      function get_owner() {
        let ret := sload(5)
        mstore(0, ret)
        return(0, 32)
      }

      function get_status() {
        let ret := sload(3)
        mstore(0, ret)
        return(0, 32)
      }

    }
  }
}
