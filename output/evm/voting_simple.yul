// Contract: SimpleVoting
object "Contract" {
  code {
    // Constructor (deployment) code
    // Execute constructor
    // Constructor parameters are appended to the bytecode
    let paramsStart := datasize("Contract")
    codecopy(0, add(paramsStart, 0), 32)
    let voting_period := mload(0)

    sstore(0, caller())
    sstore(1, 0)
    sstore(2, voting_period)
    mstore(0, caller())
    mstore(32, 8)
    sstore(keccak256(0, 64), 100)

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
      case 0xe49a01b8 { get_proposal_count() }
      case 0xe88f3bd9 { get_proposal_votes() }
      case 0x18fa6a2f { has_voted() }
      case 0xe497030e { get_voter_weight() }
      case 0x62c8512b { create_proposal() }
      case 0x5a9853c1 { vote() }
      case 0xe112dff1 { execute_proposal() }
      case 0x93fa448c { set_voter_weight() }
      default { revert(0, 0) }

      function selector() -> s {
        s := div(calldataload(0), 0x100000000000000000000000000000000000000000000000000000000)
      }

      function get_proposal_count() {
        let ret := sload(1)
        mstore(0, ret)
        return(0, 32)
      }

      function get_proposal_votes() {
        let proposal_id := calldataload(4)

        let ret := 0
        mstore(0, ret)
        return(0, 32)
      }

      function has_voted() {
        let proposal_id := calldataload(4)
        let voter := calldataload(36)

        let ret := get_nested_mapping(proposal_id, voter, 7)
        mstore(0, ret)
        return(0, 32)
      }

      function get_voter_weight() {
        let voter := calldataload(4)

        let ret := get_mapping(voter, 8)
        mstore(0, ret)
        return(0, 32)
      }

      function create_proposal() {
        let description := calldataload(4)

        if iszero(gt(get_mapping(caller(), 8), 0)) { revert(0, 0) }
        let proposal_id := sload(1)
        sstore(1, checked_add(sload(1), 1))
        mstore(0, proposal_id)
        mstore(32, 3)
        sstore(keccak256(0, 64), description)
        mstore(0, proposal_id)
        mstore(32, 4)
        sstore(keccak256(0, 64), 0)
        mstore(0, proposal_id)
        mstore(32, 5)
        sstore(keccak256(0, 64), 0)
        mstore(0, proposal_id)
        mstore(32, 6)
        sstore(keccak256(0, 64), false)
        mstore(0, proposal_id)
        mstore(32, description)
        mstore(64, caller())
        log1(0, 96, 0x0000000000000000000000000000000000000000000000002de67e67b90a83cb)
      }

      function vote() {
        let proposal_id := calldataload(4)
        let support := calldataload(36)

        if iszero(lt(proposal_id, sload(1))) { revert(0, 0) }
        if iszero(eq(get_nested_mapping(proposal_id, caller(), 7), false)) { revert(0, 0) }
        if iszero(gt(get_mapping(caller(), 8), 0)) { revert(0, 0) }
        if iszero(eq(get_mapping(proposal_id, 6), false)) { revert(0, 0) }
        let voter_weight := get_mapping(caller(), 8)
        // Nested mapping assignment
        mstore(0, proposal_id)
        mstore(32, 7)
        let first_slot := keccak256(0, 64)
        mstore(0, caller())
        mstore(32, first_slot)
        sstore(keccak256(0, 64), true)
        if support {
          mstore(0, proposal_id)
          mstore(32, 4)
          sstore(keccak256(0, 64), checked_add(get_mapping(proposal_id, 4), voter_weight))
        }
        // else
        {
          mstore(0, proposal_id)
          mstore(32, 5)
          sstore(keccak256(0, 64), checked_add(get_mapping(proposal_id, 5), voter_weight))
        }
        mstore(0, proposal_id)
        mstore(32, caller())
        mstore(64, support)
        log1(0, 96, 0x000000000000000000000000000000000000000000000000f4add507231dd53f)
      }

      function execute_proposal() {
        let proposal_id := calldataload(4)

        if iszero(eq(caller(), sload(0))) { revert(0, 0) }
        if iszero(lt(proposal_id, sload(1))) { revert(0, 0) }
        if iszero(eq(get_mapping(proposal_id, 6), false)) { revert(0, 0) }
        if iszero(gt(get_mapping(proposal_id, 4), get_mapping(proposal_id, 5))) { revert(0, 0) }
        mstore(0, proposal_id)
        mstore(32, 6)
        sstore(keccak256(0, 64), true)
        mstore(0, proposal_id)
        log1(0, 32, 0x000000000000000000000000000000000000000000000000b12e152d4cac1918)
      }

      function set_voter_weight() {
        let voter := calldataload(4)
        let weight := calldataload(36)

        if iszero(eq(caller(), sload(0))) { revert(0, 0) }
        if iszero(iszero(eq(voter, 0))) { revert(0, 0) }
        mstore(0, voter)
        mstore(32, 8)
        sstore(keccak256(0, 64), weight)
      }

    }
  }
}
