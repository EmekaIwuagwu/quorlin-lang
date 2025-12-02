// Contract: DataStructuresExample
object "Contract" {
  code {
    // Constructor (deployment) code
    // Execute constructor
    sstore(4, caller())
    sstore(3, 0)

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
      case 0xea38e31a { set_balance() }
      case 0xb82c8b31 { increase_balance() }
      case 0x56befa42 { transfer_balance() }
      case 0x5b148b58 { get_balance() }
      case 0x0269620e { approve() }
      case 0xf2100bc1 { increase_allowance() }
      case 0x68a13592 { decrease_allowance() }
      case 0x1d62e289 { get_allowance() }
      case 0xa0f00646 { spend_allowance() }
      case 0xfc102e54 { set_approval_status() }
      case 0x301b1585 { check_approval() }
      case 0xfb187116 { mint() }
      case 0xd9e46957 { burn() }
      case 0x29a76db3 { get_total_supply() }
      default { revert(0, 0) }

      function selector() -> s {
        s := div(calldataload(0), 0x100000000000000000000000000000000000000000000000000000000)
      }

      function set_balance() {
        let account := calldataload(4)
        let amount := calldataload(36)

        if iszero(eq(caller(), sload(4))) { revert(0, 0) }
        mstore(0, account)
        mstore(32, 0)
        sstore(keccak256(0, 64), amount)
        mstore(0, account)
        mstore(32, amount)
        log1(0, 64, 0x000000000000000000000000000000000000000000000000bbe37ba9e0ef6239)
      }

      function increase_balance() {
        let account := calldataload(4)
        let amount := calldataload(36)

        let current := get_mapping(account, 0)
        mstore(0, account)
        mstore(32, 0)
        sstore(keccak256(0, 64), checked_add(current, amount))
        mstore(0, account)
        mstore(32, get_mapping(account, 0))
        log1(0, 64, 0x000000000000000000000000000000000000000000000000bbe37ba9e0ef6239)
      }

      function transfer_balance() {
        let from_addr := calldataload(4)
        let to_addr := calldataload(36)
        let amount := calldataload(68)

        if iszero(eq(caller(), sload(4))) { revert(0, 0) }
        if iszero(iszero(lt(get_mapping(from_addr, 0), amount))) { revert(0, 0) }
        mstore(0, from_addr)
        mstore(32, 0)
        sstore(keccak256(0, 64), checked_sub(get_mapping(from_addr, 0), amount))
        mstore(0, to_addr)
        mstore(32, 0)
        sstore(keccak256(0, 64), checked_add(get_mapping(to_addr, 0), amount))
        mstore(0, from_addr)
        mstore(32, to_addr)
        mstore(64, amount)
        log1(0, 96, 0x00000000000000000000000000000000000000000000000029d1f533a86ea62f)
      }

      function get_balance() {
        let account := calldataload(4)

        let ret := get_mapping(account, 0)
        mstore(0, ret)
        return(0, 32)
      }

      function approve() {
        let spender := calldataload(4)
        let amount := calldataload(36)

        // Nested mapping assignment
        mstore(0, caller())
        mstore(32, 1)
        let first_slot := keccak256(0, 64)
        mstore(0, spender)
        mstore(32, first_slot)
        sstore(keccak256(0, 64), amount)
      }

      function increase_allowance() {
        let spender := calldataload(4)
        let added_value := calldataload(36)

        let current := get_nested_mapping(caller(), spender, 1)
        // Nested mapping assignment
        mstore(0, caller())
        mstore(32, 1)
        let first_slot := keccak256(0, 64)
        mstore(0, spender)
        mstore(32, first_slot)
        sstore(keccak256(0, 64), checked_add(current, added_value))
      }

      function decrease_allowance() {
        let spender := calldataload(4)
        let subtracted_value := calldataload(36)

        let current := get_nested_mapping(caller(), spender, 1)
        if iszero(iszero(lt(current, subtracted_value))) { revert(0, 0) }
        // Nested mapping assignment
        mstore(0, caller())
        mstore(32, 1)
        let first_slot := keccak256(0, 64)
        mstore(0, spender)
        mstore(32, first_slot)
        sstore(keccak256(0, 64), checked_sub(current, subtracted_value))
      }

      function get_allowance() {
        let owner_addr := calldataload(4)
        let spender := calldataload(36)

        let ret := get_nested_mapping(owner_addr, spender, 1)
        mstore(0, ret)
        return(0, 32)
      }

      function spend_allowance() {
        let owner_addr := calldataload(4)
        let spender := calldataload(36)
        let amount := calldataload(68)

        let allowed := get_nested_mapping(owner_addr, spender, 1)
        if iszero(iszero(lt(allowed, amount))) { revert(0, 0) }
        if iszero(iszero(lt(get_mapping(owner_addr, 0), amount))) { revert(0, 0) }
        // Nested mapping assignment
        mstore(0, owner_addr)
        mstore(32, 1)
        let first_slot := keccak256(0, 64)
        mstore(0, spender)
        mstore(32, first_slot)
        sstore(keccak256(0, 64), checked_sub(allowed, amount))
        mstore(0, owner_addr)
        mstore(32, 0)
        sstore(keccak256(0, 64), checked_sub(get_mapping(owner_addr, 0), amount))
        mstore(0, spender)
        mstore(32, 0)
        sstore(keccak256(0, 64), checked_add(get_mapping(spender, 0), amount))
      }

      function set_approval_status() {
        let account := calldataload(4)
        let approved := calldataload(36)

        if iszero(eq(caller(), sload(4))) { revert(0, 0) }
        mstore(0, account)
        mstore(32, 2)
        sstore(keccak256(0, 64), approved)
      }

      function check_approval() {
        let account := calldataload(4)

        let ret := get_mapping(account, 2)
        mstore(0, ret)
        return(0, 32)
      }

      function mint() {
        let to := calldataload(4)
        let amount := calldataload(36)

        if iszero(eq(caller(), sload(4))) { revert(0, 0) }
        if iszero(iszero(eq(to, 0))) { revert(0, 0) }
        mstore(0, to)
        mstore(32, 0)
        sstore(keccak256(0, 64), checked_add(get_mapping(to, 0), amount))
        sstore(3, checked_add(sload(3), amount))
        mstore(0, to)
        mstore(32, get_mapping(to, 0))
        log1(0, 64, 0x000000000000000000000000000000000000000000000000bbe37ba9e0ef6239)
      }

      function burn() {
        let from_addr := calldataload(4)
        let amount := calldataload(36)

        if iszero(eq(caller(), sload(4))) { revert(0, 0) }
        if iszero(iszero(lt(get_mapping(from_addr, 0), amount))) { revert(0, 0) }
        mstore(0, from_addr)
        mstore(32, 0)
        sstore(keccak256(0, 64), checked_sub(get_mapping(from_addr, 0), amount))
        sstore(3, checked_sub(sload(3), amount))
        mstore(0, from_addr)
        mstore(32, get_mapping(from_addr, 0))
        log1(0, 64, 0x000000000000000000000000000000000000000000000000bbe37ba9e0ef6239)
      }

      function get_total_supply() {
        let ret := sload(3)
        mstore(0, ret)
        return(0, 32)
      }

    }
  }
}
