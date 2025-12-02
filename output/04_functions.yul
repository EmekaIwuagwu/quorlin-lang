// Contract: FunctionsExample
object "Contract" {
  code {
    // Constructor (deployment) code
    // Execute constructor
    let initial_value := calldataload(0)

    sstore(0, initial_value)
    sstore(1, caller())

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
      // STORAGE ACCESS HELPERS
      // Clean mapping/array access without block expressions
      // ========================================

      function get_mapping(key, slot) -> result {
          mstore(0, key)
          mstore(32, slot)
          result := sload(keccak256(0, 64))
      }

      function get_nested_mapping(key1, key2, slot) -> result {
          mstore(0, key1)
          mstore(32, slot)
          let first_slot := keccak256(0, 64)
          mstore(0, key2)
          mstore(32, first_slot)
          result := sload(keccak256(0, 64))
      }

      // ========================================
      // Function dispatcher
      switch selector()
      case 0x30bc55b7 { set_value() }
      case 0x19a9f771 { add() }
      case 0x412c0b76 { multiply() }
      case 0x11204977 { complex_calculation() }
      case 0x361f7cb4 { get_value() }
      case 0x0b4a949d { get_owner() }
      case 0x0d0a58cf { calculate_without_storing() }
      case 0x8853ab41 { is_owner() }
      case 0xfaa905af { _internal_add() }
      case 0xeda0b0ec { _internal_multiply() }
      case 0x3a5023c4 { _validate_positive() }
      case 0xe48d95b7 { transfer_ownership() }
      case 0xc1689712 { safe_divide() }
      case 0x5a8d4cda { conditional_operation() }
      case 0xb92ea022 { sum_range() }
      default { revert(0, 0) }

      function selector() -> s {
        s := div(calldataload(0), 0x100000000000000000000000000000000000000000000000000000000)
      }

      function set_value() {
        let new_value := calldataload(4)

        if iszero(eq(caller(), sload(1))) { revert(0, 0) }
        sstore(0, new_value)
      }

      function add() {
        let amount := calldataload(4)

        sstore(0, checked_add(sload(0), amount))
        mstore(0, 0x6164640000000000000000000000000000000000000000000000000000000000)
        mstore(32, amount)
        mstore(64, sload(0))
        log1(0, 96, 0x0000000000000000000000000000000000000000000000004424ec59e2266e73)
        let ret := sload(0)
        mstore(0, ret)
        return(0, 32)
      }

      function multiply() {
        let multiplier := calldataload(4)

        sstore(0, checked_mul(sload(0), multiplier))
        mstore(0, 0x6d756c7469706c79000000000000000000000000000000000000000000000000)
        mstore(32, multiplier)
        mstore(64, sload(0))
        log1(0, 96, 0x0000000000000000000000000000000000000000000000004424ec59e2266e73)
        let ret := sload(0)
        mstore(0, ret)
        return(0, 32)
      }

      function complex_calculation() {
        let a := calldataload(4)
        let b := calldataload(36)
        let c := calldataload(68)

        let step1 := _internal_add(a, b)
        let step2 := _internal_multiply(step1, c)
        sstore(0, step2)
        let ret := step2
        mstore(0, ret)
        return(0, 32)
      }

      function get_value() {
        let ret := sload(0)
        mstore(0, ret)
        return(0, 32)
      }

      function get_owner() {
        let ret := sload(1)
        mstore(0, ret)
        return(0, 32)
      }

      function calculate_without_storing() {
        let a := calldataload(4)
        let b := calldataload(36)

        let ret := checked_mul(checked_add(a, b), 2)
        mstore(0, ret)
        return(0, 32)
      }

      function is_owner() {
        let address_to_check := calldataload(4)

        let ret := eq(address_to_check, sload(1))
        mstore(0, ret)
        return(0, 32)
      }

      function _internal_add() {
        let a := calldataload(4)
        let b := calldataload(36)

        let ret := checked_add(a, b)
        mstore(0, ret)
        return(0, 32)
      }

      function _internal_multiply() {
        let a := calldataload(4)
        let b := calldataload(36)

        let ret := checked_mul(a, b)
        mstore(0, ret)
        return(0, 32)
      }

      function _validate_positive() {
        let amount := calldataload(4)

        if iszero(gt(amount, 0)) { revert(0, 0) }
      }

      function transfer_ownership() {
        let new_owner := calldataload(4)

        if iszero(eq(caller(), sload(1))) { revert(0, 0) }
        if iszero(iszero(eq(new_owner, 0)))) { revert(0, 0) }
        sstore(1, new_owner)
      }

      function safe_divide() {
        let numerator := calldataload(4)
        let denominator := calldataload(36)

        if iszero(iszero(eq(denominator, 0)))) { revert(0, 0) }
        if iszero(iszero(lt(numerator, denominator)))) { revert(0, 0) }
        let result := checked_div(numerator, denominator)
        let ret := result
        mstore(0, ret)
        return(0, 32)
      }

      function conditional_operation() {
        let amount := calldataload(4)

        if gt(amount, 100) {
          sstore(0, checked_mul(amount, 2))
          let ret := 0x6c61726765000000000000000000000000000000000000000000000000000000
          mstore(0, ret)
          return(0, 32)
        }
        // else
        {
          sstore(0, amount)
          let ret := 0x736d616c6c000000000000000000000000000000000000000000000000000000
          mstore(0, ret)
          return(0, 32)
        }
      }

      function sum_range() {
        let n := calldataload(4)

        let total := 0
        for { let i := 0 } lt(i, checked_add(n, 1)) { i := add(i, 1) }
        {
         let total := checked_add(total, i)
        }
        sstore(0, total)
        let ret := total
        mstore(0, ret)
        return(0, 32)
      }

    }
  }
}
