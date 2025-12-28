// Contract: SystemsFeatures
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
      case 0x0825da4e { init() }
      case 0x1c9086a6 { process_list() }
      case 0x0f765a6f { check_status() }
      case 0x1563aa6a { complex_logic() }
      case 0x79947e83 { match_literals() }
      default { revert(0, 0) }

      function selector() -> s {
        s := div(calldataload(0), 0x100000000000000000000000000000000000000000000000000000000)
      }

      function init() {
        sstore(0, 0)
        sstore(1, Ok(100))
      }

      function process_list() {
        let items := calldataload(4)

        if eq(0, 0) {
          let ret := Err(0x456d707479206c69737400000000000000000000000000000000000000000000)
          mstore(0, ret)
          return(0, 32)
        }
        let ret := Ok(0)
        mstore(0, ret)
        return(0, 32)
      }

      function check_status() {
        let status := calldataload(4)

        let message := 0
        let ret := message
        mstore(0, ret)
        return(0, 32)
      }

      function complex_logic() {
        let id := calldataload(4)

        let val := process_list(sload(0))
        let ret := Ok(0x50726f636573736564204944207b69647d20776974682076616c7565207b7661)
        mstore(0, ret)
        return(0, 32)
      }

      function match_literals() {
        let x := calldataload(4)

        let ret := 0
        mstore(0, ret)
        return(0, 32)
      }

    }
  }
}
