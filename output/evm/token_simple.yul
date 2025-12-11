// Contract: SimpleToken
object "Contract" {
  code {
    // Constructor (deployment) code
    // Execute constructor
    // Constructor parameters are appended to the bytecode
    let paramsStart := datasize("Contract")
    codecopy(0, add(paramsStart, 0), 32)
    let name := mload(0)
    codecopy(32, add(paramsStart, 32), 32)
    let symbol := mload(32)
    codecopy(64, add(paramsStart, 64), 32)
    let decimals := mload(64)
    codecopy(96, add(paramsStart, 96), 32)
    let initial_supply := mload(96)

    sstore(0, name)
    sstore(1, symbol)
    sstore(2, decimals)
    sstore(4, caller())
    sstore(3, initial_supply)
    mstore(0, caller())
    mstore(32, 5)
    sstore(keccak256(0, 64), initial_supply)
    mstore(0, caller())
    mstore(32, initial_supply)
    log1(0, 64, 0x00000000000000000000000000000000000000000000000095d4a3c033b3fb2f)
    mstore(0, 0)
    mstore(32, caller())
    mstore(64, initial_supply)
    log1(0, 96, 0x000000000000000000000000000000000000000000000000108db840706d1b3e)

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
      case 0x8b3ca7c0 { name() }
      case 0xdc84ee84 { symbol() }
      case 0x638fd3d1 { decimals() }
      case 0x27c73820 { total_supply() }
      case 0x9ee49222 { balance_of() }
      case 0x87f2aa74 { allowance() }
      case 0xd44b3d19 { transfer() }
      case 0x0269620e { approve() }
      case 0x91fdf87d { transfer_from() }
      case 0xfb187116 { mint() }
      default { revert(0, 0) }

      function selector() -> s {
        s := div(calldataload(0), 0x100000000000000000000000000000000000000000000000000000000)
      }

      function name() {
        let ret := sload(0)
        mstore(0, ret)
        return(0, 32)
      }

      function symbol() {
        let ret := sload(1)
        mstore(0, ret)
        return(0, 32)
      }

      function decimals() {
        let ret := sload(2)
        mstore(0, ret)
        return(0, 32)
      }

      function total_supply() {
        let ret := sload(3)
        mstore(0, ret)
        return(0, 32)
      }

      function balance_of() {
        let account := calldataload(4)

        let ret := get_mapping(account, 5)
        mstore(0, ret)
        return(0, 32)
      }

      function allowance() {
        let owner := calldataload(4)
        let spender := calldataload(36)

        let ret := get_nested_mapping(owner, spender, 6)
        mstore(0, ret)
        return(0, 32)
      }

      function transfer() {
        let to := calldataload(4)
        let amount := calldataload(36)

        if iszero(iszero(eq(to, 0))) { revert(0, 0) }
        if iszero(iszero(lt(get_mapping(caller(), 5), amount))) { revert(0, 0) }
        mstore(0, caller())
        mstore(32, 5)
        sstore(keccak256(0, 64), checked_sub(get_mapping(caller(), 5), amount))
        mstore(0, to)
        mstore(32, 5)
        sstore(keccak256(0, 64), checked_add(get_mapping(to, 5), amount))
        mstore(0, caller())
        mstore(32, to)
        mstore(64, amount)
        log1(0, 96, 0x000000000000000000000000000000000000000000000000108db840706d1b3e)
      }

      function approve() {
        let spender := calldataload(4)
        let amount := calldataload(36)

        if iszero(iszero(eq(spender, 0))) { revert(0, 0) }
        // Nested mapping assignment
        mstore(0, caller())
        mstore(32, 6)
        let first_slot := keccak256(0, 64)
        mstore(0, spender)
        mstore(32, first_slot)
        sstore(keccak256(0, 64), amount)
        mstore(0, caller())
        mstore(32, spender)
        mstore(64, amount)
        log1(0, 96, 0x0000000000000000000000000000000000000000000000008dcc98571d80cc40)
      }

      function transfer_from() {
        let from_address := calldataload(4)
        let to := calldataload(36)
        let amount := calldataload(68)

        if iszero(iszero(eq(to, 0))) { revert(0, 0) }
        if iszero(iszero(lt(get_mapping(from_address, 5), amount))) { revert(0, 0) }
        if iszero(iszero(lt(get_nested_mapping(from_address, caller(), 6), amount))) { revert(0, 0) }
        mstore(0, from_address)
        mstore(32, 5)
        sstore(keccak256(0, 64), checked_sub(get_mapping(from_address, 5), amount))
        mstore(0, to)
        mstore(32, 5)
        sstore(keccak256(0, 64), checked_add(get_mapping(to, 5), amount))
        // Nested mapping assignment
        mstore(0, from_address)
        mstore(32, 6)
        let first_slot := keccak256(0, 64)
        mstore(0, caller())
        mstore(32, first_slot)
        sstore(keccak256(0, 64), checked_sub(get_nested_mapping(from_address, caller(), 6), amount))
        mstore(0, from_address)
        mstore(32, to)
        mstore(64, amount)
        log1(0, 96, 0x000000000000000000000000000000000000000000000000108db840706d1b3e)
      }

      function mint() {
        let to := calldataload(4)
        let amount := calldataload(36)

        if iszero(eq(caller(), sload(4))) { revert(0, 0) }
        if iszero(iszero(eq(to, 0))) { revert(0, 0) }
        sstore(3, checked_add(sload(3), amount))
        mstore(0, to)
        mstore(32, 5)
        sstore(keccak256(0, 64), checked_add(get_mapping(to, 5), amount))
        mstore(0, to)
        mstore(32, amount)
        log1(0, 64, 0x00000000000000000000000000000000000000000000000095d4a3c033b3fb2f)
        mstore(0, 0)
        mstore(32, to)
        mstore(64, amount)
        log1(0, 96, 0x000000000000000000000000000000000000000000000000108db840706d1b3e)
      }

    }
  }
}
