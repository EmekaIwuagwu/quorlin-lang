# QUORLIN-TO-EVM INTEGRATION GUIDE
# Comprehensive Specification for EVM Support

## OVERVIEW
This document provides everything needed to integrate Quorlin language support 
into your custom EVM implementation. It covers semantic analysis alignment, 
bytecode generation, opcode mapping, and runtime requirements.

═══════════════════════════════════════════════════════════════════════════════
## PART 1: SEMANTIC ANALYSIS REQUIREMENTS
═══════════════════════════════════════════════════════════════════════════════

### 1.1 Type System
The Quorlin compiler performs static type checking. Your EVM must respect these types:

**Primitive Types:**
- uint8, uint16, uint32, uint64, uint128, uint256 (unsigned integers)
- int8, int16, int32, int64, int128, int256 (signed integers)
- bool (boolean)
- address (20-byte Ethereum address)
- bytes (dynamic byte array)
- bytes32 (fixed 32-byte array)
- str (dynamic string)

**Complex Types:**
- mapping[K, V] → EVM storage mapping
- list[T] → Dynamic array in storage
- tuple[(T1, T2, ...)] → Multiple return values
- T[N] → Fixed-size array

**Type Rules EVM Must Follow:**
1. All storage variables must be 256-bit aligned
2. Mappings cannot be in memory (storage only)
3. Integer operations must check for overflow/underflow
4. Address type enforces 20-byte length

### 1.2 Storage Layout
The Quorlin compiler assigns storage slots sequentially:

```
Slot 0: First state variable
Slot 1: Second state variable
...
Slot N: Nth state variable
```

**For Mappings:**
```
keccak256(key . slot) = storage location
```

**For Nested Mappings:**
```
keccak256(key2 . keccak256(key1 . slot))
```

**Your EVM Must:**
- Implement SLOAD/SSTORE opcodes for storage access
- Calculate mapping slots using keccak256
- Handle storage collision detection

### 1.3 Security Checks
The semantic analyzer provides these warnings that your EVM should enforce:

1. **Reentrancy Detection**: Flag functions with external calls before state changes
2. **Access Control**: Warn when state-modifying functions lack auth checks
3. **Integer Overflow**: Ensure checked arithmetic helpers are used
4. **Zero Address**: Validate non-zero addresses for critical operations

═══════════════════════════════════════════════════════════════════════════════
## PART 2: YUL INTERMEDIATE REPRESENTATION
═══════════════════════════════════════════════════════════════════════════════

The Quorlin compiler generates Yul code (EVM assembly). Your EVM needs to 
understand this format or provide a Yul-to-bytecode compiler.

### 2.1 Yul Function Structure
```yul
function functionName(param1, param2) -> ret1, ret2 {
    // Local variables
    let x := add(param1, param2)
    
    // Storage access
    sstore(0, x)
    
    // Return
    ret1 := x
    ret2 := mul(x, 2)
}
```

### 2.2 Required Yul Builtins Your EVM Must Support

**Arithmetic:**
- add(x, y) → x + y
- sub(x, y) → x - y  
- mul(x, y) → x * y
- div(x, y) → x / y
- mod(x, y) → x % y

**Logic:**
- and(x, y), or(x, y), xor(x, y), not(x)
- eq(x, y), lt(x, y), gt(x, y), iszero(x)

**Storage:**
- sload(slot) → Load from storage
- sstore(slot, value) → Store to storage

**Memory:**
- mload(ptr) → Load 32 bytes from memory
- mstore(ptr, value) → Store 32 bytes to memory
- mstore8(ptr, value) → Store 1 byte to memory

**Hashing:**
- keccak256(ptr, len) → Hash of memory region

**Call Data:**
- calldataload(offset) → Load 32 bytes from call data
- calldatacopy(destPtr, offset, len) → Copy call data to memory

**Logging (Events):**
- log0, log1, log2, log3, log4 → Emit events with topics

**Control Flow:**
- revert(ptr, len) → Revert with error data
- return(ptr, len) → Return with data
- stop() → Halt execution

═══════════════════════════════════════════════════════════════════════════════
## PART 3: OPCODE MAPPING
═══════════════════════════════════════════════════════════════════════════════

### 3.1 Standard EVM Opcodes Required

| Opcode | Hex | Name | Description |
|--------|-----|------|-------------|
| 0x00 | STOP | Halt execution |
| 0x01 | ADD | Addition |
| 0x02 | MUL | Multiplication |
| 0x03 | SUB | Subtraction |
| 0x04 | DIV | Integer division |
| 0x05 | SDIV | Signed integer division |
| 0x06 | MOD | Modulo remainder |
| 0x08 | ADDMOD | Modulo addition |
| 0x09 | MULMOD | Modulo multiplication |
| 0x0A | EXP | Exponential |
| 0x10 | LT | Less-than comparison |
| 0x11 | GT | Greater-than comparison |
| 0x12 | SLT | Signed less-than |
| 0x13 | SGT | Signed greater-than |
| 0x14 | EQ | Equality |
| 0x15 | ISZERO | Is zero |
| 0x16 | AND | Bitwise AND |
| 0x17 | OR | Bitwise OR |
| 0x18 | XOR | Bitwise XOR |
| 0x19 | NOT | Bitwise NOT |
| 0x1A | BYTE | Retrieve single byte |
| 0x1B | SHL | Shift left |
| 0x1C | SHR | Shift right |
| 0x1D | SAR | Arithmetic shift right |
| 0x20 | SHA3 (KECCAK256) | Keccak-256 hash |
| 0x30 | ADDRESS | Get address of current contract |
| 0x31 | BALANCE | Get balance of account |
| 0x32 | ORIGIN | Get transaction origin |
| 0x33 | CALLER | Get caller address (msg.sender) |
| 0x34 | CALLVALUE | Get deposited value (msg.value) |
| 0x35 | CALLDATALOAD | Load call data |
| 0x36 | CALLDATASIZE |Get size of call data |
| 0x37 | CALLDATACOPY | Copy call data |
| 0x38 | CODESIZE | Get code size |
| 0x39 | CODECOPY | Copy code |
| 0x3A | GASPRICE | Get transaction gas price |
| 0x3B | EXTCODESIZE | Get external code size |
| 0x3C | EXTCODECOPY | Copy external code |
| 0x3D | RETURNDATASIZE | Get return data size |
| 0x3E | RETURNDATACOPY | Copy return data |
| 0x3F | EXTCODEHASH | Get code hash |
| 0x40 | BLOCKHASH | Get block hash |
| 0x41 | COINBASE | Get block miner |
| 0x42 | TIMESTAMP | Get block timestamp |
| 0x43 | NUMBER | Get block number |
| 0x44 | DIFFICULTY | Get block difficulty |
| 0x45 | GASLIMIT | Get block gas limit |
| 0x50 | POP | Remove top stack item |
| 0x51 | MLOAD | Load word from memory |
| 0x52 | MSTORE | Store word to memory |
| 0x53 | MSTORE8 | Store byte to memory |
| 0x54 | SLOAD | Load from storage |
| 0x55 | SSTORE | Store to storage |
| 0x56 | JUMP | Jump to location |
| 0x57 | JUMPI | Conditional jump |
| 0x58 | PC | Program counter |
| 0x59 | MSIZE | Get memory size |
| 0x5A | GAS | Get available gas |
| 0x5B | JUMPDEST | Valid jump destination |
| 0x60-0x7F | PUSH1-PUSH32 | Push 1-32 bytes onto stack |
| 0x80-0x8F | DUP1-DUP16 | Duplicate stack item |
| 0x90-0x9F | SWAP1-SWAP16 | Swap stack items |
| 0xA0 | LOG0 | Emit log (0 topics) |
| 0xA1 | LOG1 | Emit log (1 topic) |
| 0xA2 | LOG2 | Emit log (2 topics) |
| 0xA3 | LOG3 | Emit log (3 topics) |
| 0xA4 | LOG4 | Emit log (4 topics) |
| 0xF0 | CREATE | Create contract |
| 0xF1 | CALL | Call another contract |
| 0xF2 | CALLCODE | Call with different code |
| 0xF3 | RETURN | Return from contract |
| 0xF4 | DELEGATECALL | Delegate call |
| 0xF5 | CREATE2 | Create contract with salt |
| 0xFA | STATICCALL | Static call (no state change) |
| 0xFD | REVERT | Revert state changes |
| 0xFE | INVALID | Invalid opcode |
| 0xFF | SELFDESTRUCT | Destroy contract |

### 3.2 Gas Costs (Per Opcode)

Your EVM should track gas consumption:

| Operation | Base Gas | Notes |
|-----------|----------|-------|
| ADD, SUB, MUL | 3 | Arithmetic |
| DIV, MOD | 5 | Division |
| EXP | 10 | Exponential |
| SLOAD | 200 | Cold storage read |
| SSTORE (new) | 20,000 | First write to slot |
| SSTORE (modify) | 5,000 | Modify existing value |
| SSTORE (delete) | -15,000 | Refund for clearing |
| KECCAK256 | 30 + 6/word | Hashing |
| LOG0-LOG4 | 375 + 375*topics + 8*data_size | Events |
| CALL | 700 + transfer_cost | External calls |
| CREATE | 32,000 | Contract creation |

═══════════════════════════════════════════════════════════════════════════════
## PART 4: FUNCTION DISPATCHER
═══════════════════════════════════════════════════════════════════════════════

### 4.1 Function Selector Generation
```
selector = keccak256("functionName(uint256,address)")[:4]
```

**Example:**
```solidity
transfer(address,uint256) → 0xa9059cbb
```

### 4.2 Dispatcher Logic
```yul
// 1. Load function selector from calldata
let selector := shr(224, calldataload(0))

// 2. Match against known functions
switch selector
case 0xa9059cbb { transfer() }
case 0x095ea7b3 { approve() }
default { revert(0, 0) }
```

═══════════════════════════════════════════════════════════════════════════════
## PART 5: RUNTIME ENVIRONMENT
═══════════════════════════════════════════════════════════════════════════════

### 5.1 Required Global Variables

```
msg.sender → CALLER opcode (0x33)
msg.value → CALLVALUE opcode (0x34)
block.timestamp → TIMESTAMP opcode (0x42)
block.number → NUMBER opcode (0x43)
tx.origin → ORIGIN opcode (0x32)
```

### 5.2 Memory Layout

```
0x00-0x3F: Scratch space for hashing
0x40-0x5F: Free memory pointer
0x60-0x7F: Zero slot
0x80+: Free memory
```

### 5.3 Call Data Layout

```
[0:4]   Function selector
[4:36]  First parameter (padded to 32 bytes)
[36:68] Second parameter (padded to 32 bytes)
...
```

═══════════════════════════════════════════════════════════════════════════════
## PART 6: EVENT LOGGING
═══════════════════════════════════════════════════════════════════════════════

### 6.1 Event Signature
```
event_signature = keccak256("Transfer(address,address,uint256)")
```

### 6.2 Logging Format
```yul
// Emit Transfer event
mstore(0x00, amount)  // Store data in memory
log3(
    0x00,             // Memory offset
    0x20,             // Data length
    0xddf252...,      // Event signature (topic0)
    from,             // Indexed parameter (topic1)
    to                // Indexed parameter (topic2)
)
```

═══════════════════════════════════════════════════════════════════════════════
## PART 7: CHECKED ARITHMETIC
═══════════════════════════════════════════════════════════════════════════════

The Quorlin compiler generates safe math helpers. Your EVM must support or inline:

```yul
function checked_add(x, y) -> sum {
    sum := add(x, y)
    if lt(sum, x) { revert(0, 0) }  // Overflow check
}

function checked_sub(x, y) -> diff {
    if lt(x, y) { revert(0, 0) }    // Underflow check
    diff := sub(x, y)
}

function checked_mul(x, y) -> product {
    product := mul(x, y)
    if iszero(or(iszero(x), eq(div(product, x), y))) {
        revert(0, 0)  // Overflow check
    }
}
```

═══════════════════════════════════════════════════════════════════════════════
## PART 8: EXTERNAL CALLS
═══════════════════════════════════════════════════════════════════════════════

When Quorlin contracts call external contracts:

```yul
// Prepare call data
mstore(0x00, selector)
mstore(0x04, param1)

// Execute call
let success := call(
    gas(),           // Gas to forward
    target_address,  // Target contract
    0,               // Value to send
    0x00,            // Input data offset
    0x24,            // Input data size (4 + 32)
    0x00,            // Output data offset
    0x20             // Output data size
)

// Check success
if iszero(success) { revert(0, 0) }
```

═══════════════════════════════════════════════════════════════════════════════
## PART 9: INTEGRATION CHECKLIST
═══════════════════════════════════════════════════════════════════════════════

For your EVM to properly execute Quorlin-compiled contracts:

✅ **1. Opcode Support**
   - Implement all opcodes in Part 3.1
   - Correct stack behavior (push/pop)
   - Proper gas accounting

✅ **2. Storage Model**
   - 256-bit word-aligned storage
   - Mapping storage calculation (keccak256)
   - SLOAD/SSTORE opcodes

✅ **3. Memory Model**
   - Byte-addressable memory
   - Memory expansion cost
   - MLOAD/MSTORE opcodes

✅ **4. Call Data Handling**
   - Function selector extraction
   - Parameter decoding
   - ABI encoding/decoding

✅ **5. Event System**
   - LOG0-LOG4 opcodes
   - Topic indexing
   - Event signature hashing

✅ **6. External Calls**
   - CALL, STATICCALL, DELEGATECALL
   - Gas forwarding
   - Return data handling

✅ **7. Error Handling**
   - REVERT opcode with reason
   - require() statement support
   - Stack unwinding

✅ **8. Global Variables**
   - msg.sender, msg.value
   - block.timestamp, block.number
   - Correct opcode mapping

═══════════════════════════════════════════════════════════════════════════════
## PART 10: TESTING CONTRACTS
═══════════════════════════════════════════════════════════════════════════════

Use these Quorlin contracts to test your EVM:

**Test 1: Basic Storage**
```quorlin
contract StorageTest:
    value: uint256
    
    @constructor
    fn __init__(initial: uint256):
        self.value = initial
    
    @external
    fn set(new_value: uint256):
        self.value = new_value
    
    @view
    fn get() -> uint256:
        return self.value
```

**Expected Bytecode Flow:**
1. Constructor: SSTORE slot 0 with initial value
2. set(): Load calldata, SSTORE slot 0
3. get(): SLOAD slot 0, RETURN

═══════════════════════════════════════════════════════════════════════════════
## APPENDIX: QUORLIN BYTECODE FORMAT (Optional)
═══════════════════════════════════════════════════════════════════════════════

If you want native Quorlin bytecode instead of Yul:

### Bytecode Structure
```
[Magic: "QBC\0" (4 bytes)]
[Version: 1.0.0 (4 bytes)]
[Contract Count: N (4 bytes)]
For each contract:
  [Name Length (2 bytes)]
  [Name (UTF-8)]
  [State Variable Count (2 bytes)]
  For each state variable:
    [Name, Type, Slot]
  [Function Count (2 bytes)]
  For each function:
    [Selector (4 bytes)]
    [Code Length (4 bytes)]
    [Bytecode]
```

### Custom Opcodes (Optional Extension)
```
0x00: NOP
0x01: LOAD_LOCAL <index>
0x02: STORE_LOCAL <index>
0x03: LOAD_STATE <slot>
0x04: STORE_STATE <slot>
0x05: PUSH_CONST <value>
0x06: ADD
0x07: SUB
0x08: MUL
0x09: DIV
0x0A: CALL_FUNCTION <selector>
0x0B: RETURN
0x0C: REVERT
0x0D: EMIT_EVENT <signature>
```

═══════════════════════════════════════════════════════════════════════════════
END OF SPECIFICATION
═══════════════════════════════════════════════════════════════════════════════
