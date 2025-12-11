// Contract: Counter
object "Contract" {
  code {
    // Constructor (deployment) code
    // Execute constructor
    // Constructor parameters are appended to the bytecode
    let paramsStart := datasize("Contract")
    codecopy(0, add(paramsStart, 0), 32)
    let initial_count := mload(0)

    sstore(0, initial_count)
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

      function select(cond, a, b) -> result {
          switch cond
          case 0 { result := b }
          default { result := a }
      }

      // ========================================
      // Function dispatcher
      switch selector()
      case 0x8b241b58 { get_count() }
      case 0x0b4a949d { get_owner() }
      case 0x6c4866b9 { increment() }
      case 0xb441e1c4 { decrement() }
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

      function get_owner() {
        let ret := sload(1)
        mstore(0, ret)
        return(0, 32)
      }

      function increment() {
        sstore(0, checked_add(sload(0), 1))
        mstore(0, sload(0))
        log1(0, 32, 0x000000000000000000000000000000000000000000000000c264ae366e7d114f)
      }

      function decrement() {
        if iszero(gt(sload(0), 0)) { revert(0, 0) }
        sstore(0, checked_sub(sload(0), 1))
        mstore(0, sload(0))
        log1(0, 32, 0x000000000000000000000000000000000000000000000000d71c45f444055516)
      }

      function add() {
        let amount := calldataload(4)

        if iszero(eq(caller(), sload(1))) { revert(0, 0) }
        sstore(0, checked_add(sload(0), amount))
        mstore(0, sload(0))
        log1(0, 32, 0x000000000000000000000000000000000000000000000000c264ae366e7d114f)
      }

      function reset() {
        if iszero(eq(caller(), sload(1))) { revert(0, 0) }
        sstore(0, 0)
      }

    }
  }
}
