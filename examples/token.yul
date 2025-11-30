// Contract: Token
object "Contract" {
  code {
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
        if iszero(iszero(lt({
          mstore(0, caller())
          mstore(32, 4)
          sload(keccak256(0, 64))
        }, amount)))) { revert(0, 0) }
        if iszero(iszero(eq(to, address(0))))) { revert(0, 0) }
        mstore(0, caller())
        mstore(32, 4)
        sstore(keccak256(0, 64), safe_sub({
          mstore(0, caller())
          mstore(32, 4)
          sload(keccak256(0, 64))
        }, amount))
        mstore(0, to)
        mstore(32, 4)
        sstore(keccak256(0, 64), safe_add({
          mstore(0, to)
          mstore(32, 4)
          sload(keccak256(0, 64))
        }, amount))
        // emit statement (not implemented)
        let ret := 1
        mstore(0, ret)
        return(0, 32)
      }

      function approve() {
        if iszero(iszero(eq(spender, address(0))))) { revert(0, 0) }
        // Nested mapping assignment
        mstore(0, caller())
        mstore(32, 5)
        let first_slot := keccak256(0, 64)
        mstore(0, spender)
        mstore(32, first_slot)
        sstore(keccak256(0, 64), amount)
        // emit statement (not implemented)
        let ret := 1
        mstore(0, ret)
        return(0, 32)
      }

      function transfer_from() {
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
        if iszero(iszero(eq(to, address(0))))) { revert(0, 0) }
        mstore(0, from_addr)
        mstore(32, 4)
        sstore(keccak256(0, 64), safe_sub({
          mstore(0, from_addr)
          mstore(32, 4)
          sload(keccak256(0, 64))
        }, amount))
        mstore(0, to)
        mstore(32, 4)
        sstore(keccak256(0, 64), safe_add({
          mstore(0, to)
          mstore(32, 4)
          sload(keccak256(0, 64))
        }, amount))
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
        // emit statement (not implemented)
        let ret := 1
        mstore(0, ret)
        return(0, 32)
      }

      function balance_of() {
        let ret := {
          mstore(0, owner)
          mstore(32, 4)
          sload(keccak256(0, 64))
        }
        mstore(0, ret)
        return(0, 32)
      }

      function allowance() {
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
