# QUORLIN COMPILER: SEMANTIC ANALYSIS QUICK REFERENCE
# Multi-Backend Compilation Semantics

═══════════════════════════════════════════════════════════════════════════════
## WHAT IS SEMANTIC ANALYSIS IN QUORLIN?
═══════════════════════════════════════════════════════════════════════════════

Semantic analysis is the phase between parsing and code generation that:
✓ **Validates** the program is semantically correct
✓ **Infers** types for all expressions  
✓ **Checks** for security vulnerabilities
✓ **Resolves** symbols (variables, functions, types)
✓ **Ensures** backend compatibility

It runs BEFORE code generation, so all 5 backends get the same validated AST.

═══════════════════════════════════════════════════════════════════════════════
## KEY COMPONENTS
═══════════════════════════════════════════════════════════════════════════════

### 1. TYPE CHECKER (`quorlin-semantics/src/type_checker.rs`)
**What it does:**
- Infers types for every expression
- Checks type compatibility
- Validates numeric promotions
- Handles generic types (mapping, list, tuple)

**Example:**
```quorlin
x: uint256 = 42          # Type annotation → uint256
y = x + 100              # Type inference → uint256
z: uint8 = y             # TYPE ERROR: cannot assign uint256 to uint8
```

### 2. SYMBOL TABLE (`quorlin-semantics/src/symbol_table.rs`)
**What it does:**
- Tracks all variables, functions, contracts, events
- Manages scopes (global, contract, function, block)
- Detects duplicate definitions
- Resolves references

**Example:**
```quorlin
contract MyContract:
    value: uint256       # Contract scope - accessible as self.value
    
    fn set_value(x: uint256):
        value = x        # ERROR: undefined (should be self.value)
```

### 3. SECURITY ANALYZER (`quorlin-semantics/src/security_analyzer.rs`)
**What it does:**
- Detects reentrancy vulnerabilities
- Finds missing access control
- Identifies integer overflow risks
- Checks for common pitfalls

**Example:**
```quorlin
fn transfer(to: address, amount: uint256):
    # ⚠️  WARNING: Missing access control
    balance[to] = balance[to] + amount    # ⚠️  WARNING: Unchecked arithmetic
    external_call(to)                      # ⚠️  WARNING: Reentrancy risk
    balance[msg.sender] = balance[msg.sender] - amount  # ⚠️  State change after call
```

### 4. VALIDATOR (`quorlin-semantics/src/validator.rs`)
**What it does:**
- Validates decorator usage (@external, @view, etc.)
- Checks function signatures
- Ensures language rules are followed
- Validates contract structure

**Example:**
```quorlin
@view                    # ✓ Valid decorator
@external                # ✗ ERROR: Cannot combine @view and @external
fn get_balance() -> uint256:
    self.balance += 1    # ✗ ERROR: @view functions cannot modify state
    return self.balance
```

═══════════════════════════════════════════════════════════════════════════════
## HOW BACKENDS USE SEMANTIC ANALYSIS
═══════════════════════════════════════════════════════════════════════════════

All backends receive the SAME validated AST from semantic analysis, but interpret
it differently:

### EVM/Yul Backend
```
Type: uint256 → 256-bit EVM word
Storage: Sequential slots (0, 1, 2, ...)
Function: func_selector = keccak256("transfer(address,uint256)")[0:4]
Events: LOG1, LOG2, LOG3 opcodes
```

### Solana/Anchor Backend  
```
Type: uint256 → u128 (Solana doesn't have u256)
Storage: Account data with Borsh serialization
Function: Instruction enum variants
Events: emit! macro
```

### Polkadot/ink! Backend
```
Type: uint256 → u128 (ink! v5 uses u128)
Storage: Mapping<K, V> for maps, Vec<T> for arrays
Function: #[ink(message)] attribute
Events: #[ink(event)] structs with #[ink(topic)]
```

### Aptos/Move Backend
```
Type: uint256 → u128 or u256 (Move VM)
Storage: Resource<T> with global storage
Function: public entry fun
Events: event::emit<T>
```

### Quorlin Bytecode Backend
```
Type: Tagged values with type metadata
Storage: Slot-based like EVM
Function: Custom opcode set
Events: EMIT_EVENT opcode
```

═══════════════════════════════════════════════════════════════════════════════
## SEMANTIC ANALYSIS FLOW
═══════════════════════════════════════════════════════════════════════════════

```
Source Code (.ql)
      ↓
  Lexer → Tokens
      ↓
  Parser → AST
      ↓
╔═══════════════════════════════╗
║  SEMANTIC ANALYSIS (3 PASSES) ║
╚═══════════════════════════════╝
      ↓
  Pass 1: Definition Collection
    • Build symbol table
    • Record all functions, variables, events
    • Check for duplicates
      ↓
  Pass 2: Type Checking & Validation
    • Infer types for all expressions
    • Validate type compatibility
    • Check function signatures
    • Validate language rules
      ↓
  Pass 3: Security Analysis
    • Detect vulnerabilities
    • Generate warnings
    • Suggest best practices
      ↓
  Validated AST + Metadata
      ↓
      ├─→ EVM Codegen → Yul
      ├─→ Solana Codegen → Rust/Anchor
      ├─→ Polkadot Codegen → Rust/ink!
      ├─→ Aptos Codegen → Move
      └─→ Quorlin Codegen → Bytecode
```

═══════════════════════════════════════════════════════════════════════════════
## FOR YOUR EVM IMPLEMENTATION
═══════════════════════════════════════════════════════════════════════════════

### What You Need to Know:

1. **Quorlin compiler generates Yul code for EVM**
   - Yul is EVM assembly language
   - Your EVM must either:
     a) Parse and execute Yul directly, OR
     b) Compile Yul → EVM bytecode, then execute

2. **Semantic metadata is embedded in the Yul output**
   ```yul
   // Contract: MyContract
   // Storage layout:
   //   Slot 0: balance (uint256)
   //   Slot 1: owner (address)
   // Function signatures:
   //   0xa9059cbb: transfer(address,uint256)
   ```

3. **Your EVM must enforce the same semantics**
   - Type sizes (uint256 = 32 bytes)
   - Storage layout (sequential slots)
   - Function selectors (keccak256 first 4 bytes)
   - Checked arithmetic (revert on overflow)
   - Event encoding (LOG opcodes)

4. **Backend-specific adaptations**
   - If implementing Solana support: Use Anchor framework
   - If implementing Polkadot: Use ink! macros
   - If implementing Move: Follow Move's resource model
   - If implementing Quorlin bytecode: Define custom opcodes

═══════════════════════════════════════════════════════════════════════════════
## CRITICAL FILES IN QUORLIN COMPILER
═══════════════════════════════════════════════════════════════════════════════

**To understand semantic analysis:**
```
crates/quorlin-semantics/src/
├── lib.rs                    # Main orchestrator (3-pass analysis)
├── type_checker.rs           # Type inference and compatibility
├── security_analyzer.rs      # Vulnerability detection
├── symbol_table.rs           # Symbol tracking and scoping
├── validator.rs              # Language rule validation
└── backend_consistency.rs    # Cross-backend validation
```

**To understand code generation:**
```
crates/
├── quorlin-codegen-evm/     # Yul generation for EVM
├── quorlin-codegen-solana/  # Rust/Anchor for Solana
├── quorlin-codegen-ink/     # Rust/ink! for Polkadot
├── quorlin-codegen-aptos/   # Move for Aptos
└── quorlin-codegen-quorlin/ # Native bytecode
```

**To understand the language:**
```
crates/quorlin-parser/src/
├── ast.rs                   # AST definitions (Expr, Stmt, Type, etc.)
└── grammar.lalrpop          # Language grammar
```

═══════════════════════════════════════════════════════════════════════════════
## EXAMPLE: SEMANTIC ANALYSIS IN ACTION
═══════════════════════════════════════════════════════════════════════════════

**Source Contract:**
```quorlin
contract Token:
    balances: mapping[address, uint256]
    
    @external
    fn transfer(to: address, amount: uint256):
        require(balances[msg.sender] >= amount, "Insufficient balance")
        balances[msg.sender] = balances[msg.sender] - amount
        balances[to] = balances[to] + amount
```

**Semantic Analysis Output:**

```
✓ PASS 1: Definitions Collected
  - Contract: Token
  - State variable: balances (mapping[address, uint256]) → Slot 0
  - Function: transfer (address, uint256) → void
  
✓ PASS 2: Type Checking
  - balances[msg.sender] → uint256 (storage mapping access)
  - amount → uint256 (parameter type)
  - balances[msg.sender] >= amount → bool (comparison)
  - balances[msg.sender] - amount → uint256 (arithmetic)
  - All types valid ✓
  
⚠  PASS 3: Security Warnings
  - Missing access control in 'transfer'
  - Unchecked arithmetic: use safe_sub(balances[msg.sender], amount)
  - Consider reentrancy guard
```

**Generated Yul (EVM):**
```yul
function transfer(to, amount) {
    require(iszero(iszero(to)), "Zero address")
    
    let sender_slot := 0
    let sender_balance := sload(keccak256(sender, sender_slot))
    require(gte(sender_balance, amount), "Insufficient balance")
    
    let new_sender_balance := checked_sub(sender_balance, amount)
    sstore(keccak256(sender, sender_slot), new_sender_balance)
    
    let receiver_balance := sload(keccak256(to, sender_slot))
    let new_receiver_balance := checked_add(receiver_balance, amount)
    sstore(keccak256(to, sender_slot), new_receiver_balance)
}
```

═══════════════════════════════════════════════════════════════════════════════
## NEXT STEPS FOR YOUR EVM
═══════════════════════════════════════════════════════════════════════════════

1. **Read the Integration Spec**
   - `QUORLIN_EVM_INTEGRATION_SPEC.md` - Technical specification
   
2. **Use the Prompts**
   - `CLAUDE_PROMPTS_FOR_EVM_INTEGRATION.md` - Step-by-step prompts
   - Copy each prompt to Claude/Antigravity in order
   
3. **Implement Components**
   - Start with Prompt 1 (analyze architecture)
   - Build components with Prompts 3-7
   - Integrate with Prompt 8
   - Test with Prompt 9
   
4. **Test Against Quorlin Output**
   ```bash
   # Compile test contracts
   cd quorlin-lang
   cargo run --bin qlc -- compile examples/contracts/counter.ql --target evm
   cargo run --bin qlc -- compile examples/contracts/token_simple.ql --target evm
   
   # Generated files will be in output/evm/
   # Your EVM should execute these identically to standard EVM
   ```

5. **Verify Compatibility**
   - Run the same contract on both EVMs
   - Compare storage changes
   - Compare event emissions
   - Compare gas usage
   - Ensure identical behavior

═══════════════════════════════════════════════════════════════════════════════
## SUPPORT & RESOURCES
═══════════════════════════════════════════════════════════════════════════════

**Compiler Source:**
- Location: `c:\Users\emi\Desktop\Quorlin\quorlin-lang`
- Language: Rust
- Working Status: ✅ Fully operational (15/15 compilations successful)

**Documentation:**
- EVM Integration Spec: `QUORLIN_EVM_INTEGRATION_SPEC.md`
- Claude Prompts: `CLAUDE_PROMPTS_FOR_EVM_INTEGRATION.md`
- This Quick Reference: `SEMANTIC_ANALYSIS_QUICK_REFERENCE.md`

**Test Contracts:**
- `examples/contracts/counter.ql` - Simple state management
- `examples/contracts/token_simple.ql` - ERC20-style token
- `examples/contracts/voting_simple.ql` - Governance system

**Build & Run:**
```bash
# Build compiler
cargo build --release

# Compile a contract
cargo run --release --bin qlc -- compile <file.ql> --target <backend>

# Backends: evm, solana, polkadot, aptos, quorlin
```

Good luck with your implementation! 🚀
