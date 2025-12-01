// Contract: Token
object "Contract" {
  code {
    // Constructor (deployment) code
    // Execute constructor
    let initial_supply := calldataload(0)

    sstore(3, initial_supply)
    mstore(0, caller())
    mstore(32, 4)
    sstore(keccak256(0, 64), initial_supply)
    mstore(0, 0)
    mstore(32, caller())
    mstore(64, initial_supply)
    log1(0, 96, 0x000000000000000000000000000000000000000000000000b40fa3947a0a069d)

    // Copy runtime code to memory and return it
    datacopy(0, dataoffset("runtime"), datasize("runtime"))
    return(0, datasize("runtime"))
  }
  object "runtime" {
    code {
      // Function dispatcher
      switch selector()
      case 0xd44b3d19 { transfer() }
      case 0x0269620e { approve() }
      case 0xcd9f4dee { transfer_from() }
      case 0x50525c86 { balance_of() }
      case 0x87f2aa74 { allowance() }
      case 0x29a76db3 { get_total_supply() }
      default { revert(0, 0) }

      function selector() -> s {
        s := div(calldataload(0), 0x100000000000000000000000000000000000000000000000000000000)
      }

      function transfer() {
        let to := calldataload(4)
        let amount := calldataload(36)

        if iszero(iszero(lt({
          mstore(0, caller())
          mstore(32, 4)
          sload(keccak256(0, 64))
        }, amount)))) { revert(0, 0) }
        if iszero(iszero(eq(to, 0)))) { revert(0, 0) }
        mstore(0, caller())
        mstore(32, 4)
        sstore(keccak256(0, 64), {
          if lt({
          mstore(0, caller())
          mstore(32, 4)
          sload(keccak256(0, 64))
        }, amount) { revert(0, 0) }
          sub({
          mstore(0, caller())
          mstore(32, 4)
          sload(keccak256(0, 64))
        }, amount)
        })
        mstore(0, to)
        mstore(32, 4)
        sstore(keccak256(0, 64), {
          let result := add({
          mstore(0, to)
          mstore(32, 4)
          sload(keccak256(0, 64))
        }, amount)
          if lt(result, {
          mstore(0, to)
          mstore(32, 4)
          sload(keccak256(0, 64))
        }) { revert(0, 0) }
          result
        })
        mstore(0, caller())
        mstore(32, to)
        mstore(64, amount)
        log1(0, 96, 0x000000000000000000000000000000000000000000000000b40fa3947a0a069d)
        let ret := 1
        mstore(0, ret)
        return(0, 32)
      }

      function approve() {
        let spender := calldataload(4)
        let amount := calldataload(36)

        if iszero(iszero(eq(spender, 0)))) { revert(0, 0) }
        // Nested mapping assignment
        mstore(0, caller())
        mstore(32, 5)
        let first_slot := keccak256(0, 64)
        mstore(0, spender)
        mstore(32, first_slot)
        sstore(keccak256(0, 64), amount)
        mstore(0, caller())
        mstore(32, spender)
        mstore(64, amount)
        log1(0, 96, 0x0000000000000000000000000000000000000000000000007d20bd6ffcb8b1a8)
        let ret := 1
        mstore(0, ret)
        return(0, 32)
      }

      function transfer_from() {
        let from_addr := calldataload(4)
        let to := calldataload(36)
        let amount := calldataload(68)

        if iszero(iszero(lt({
          mstore(0, from_addr)
          mstore(32, 4)
          sload(keccak256(0, 64))
        }, amount)))) { revert(0, 0) }
        if iszero(iszero(lt({
          mstore(0, from_addr)
          mstore(32, 5)
          let first_slot := keccak256(0, 64)
          mstore(0, caller())
          mstore(32, first_slot)
          sload(keccak256(0, 64))
        }, amount)))) { revert(0, 0) }
        if iszero(iszero(eq(to, 0)))) { revert(0, 0) }
        mstore(0, from_addr)
        mstore(32, 4)
        sstore(keccak256(0, 64), {
          if lt({
          mstore(0, from_addr)
          mstore(32, 4)
          sload(keccak256(0, 64))
        }, amount) { revert(0, 0) }
          sub({
          mstore(0, from_addr)
          mstore(32, 4)
          sload(keccak256(0, 64))
        }, amount)
        })
        mstore(0, to)
        mstore(32, 4)
        sstore(keccak256(0, 64), {
          let result := add({
          mstore(0, to)
          mstore(32, 4)
          sload(keccak256(0, 64))
        }, amount)
          if lt(result, {
          mstore(0, to)
          mstore(32, 4)
          sload(keccak256(0, 64))
        }) { revert(0, 0) }
          result
        })
        // Nested mapping assignment
        mstore(0, from_addr)
        mstore(32, 5)
        let first_slot := keccak256(0, 64)
        mstore(0, caller())
        mstore(32, first_slot)
        sstore(keccak256(0, 64), sub({
          mstore(0, from_addr)
          mstore(32, 5)
          let first_slot := keccak256(0, 64)
          mstore(0, caller())
          mstore(32, first_slot)
          sload(keccak256(0, 64))
        }, amount))
        mstore(0, from_addr)
        mstore(32, to)
        mstore(64, amount)
        log1(0, 96, 0x000000000000000000000000000000000000000000000000b40fa3947a0a069d)
        let ret := 1
        mstore(0, ret)
        return(0, 32)
      }

      function balance_of() {
        let owner := calldataload(4)

        let ret := {
          mstore(0, owner)
          mstore(32, 4)
          sload(keccak256(0, 64))
        }
        mstore(0, ret)
        return(0, 32)
      }

      function allowance() {
        let owner := calldataload(4)
        let spender := calldataload(36)

        let ret := {
          mstore(0, owner)
          mstore(32, 5)
          let first_slot := keccak256(0, 64)
          mstore(0, spender)
          mstore(32, first_slot)
          sload(keccak256(0, 64))
        }
        mstore(0, ret)
        return(0, 32)
      }

      function get_total_supply() {
        let ret := 3
        mstore(0, ret)
        return(0, 32)
      }

    }
  }
}
