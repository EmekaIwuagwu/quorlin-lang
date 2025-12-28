# CLAUDE/ANTIGRAVITY PROMPTS FOR QUORLIN-EVM INTEGRATION
# Copy these prompts to implement Quorlin compiler semantics in your EVM

═══════════════════════════════════════════════════════════════════════════════
## PROMPT 1: ANALYZE QUORLIN SEMANTIC ANALYZER ARCHITECTURE
═══════════════════════════════════════════════════════════════════════════════

```
I have a Quorlin smart contract compiler at `c:\Users\emi\Desktop\Quorlin\quorlin-lang`.
This compiler successfully compiles contracts to 5 backends: EVM (Yul), Solana (Rust/Anchor),
Polkadot (Rust/ink!), Aptos (Move), and Quorlin Bytecode.

TASK: Analyze the semantic analysis implementation and create a comprehensive specification.

Please examine these files:
1. `crates/quorlin-semantics/src/lib.rs` - Main semantic analyzer
2. `crates/quorlin-semantics/src/type_checker.rs` - Type checking logic
3. `crates/quorlin-semantics/src/security_analyzer.rs` - Security analysis
4. `crates/quorlin-semantics/src/symbol_table.rs` - Symbol tracking
5. `crates/quorlin-semantics/src/validator.rs` - Validation rules
6. `crates/quorlin-parser/src/ast.rs` - AST definitions

Create a detailed document that explains:

**A. Type System Rules**
- How does the analyzer infer types?
- What type compatibility rules exist?
- How are generic types handled (mapping, list, tuple)?
- What numeric type promotions are allowed?

**B. Symbol Resolution**
- How are variables, functions, and contracts tracked?
- What scoping rules apply?
- How does it handle shadowing and redefinition?

**C. Security Checks**
- What security patterns does it detect?
- How does it identify reentrancy risks?
- What access control validations exist?

**D. Validation Rules**
- What are the constraint checking rules?
- How does it validate decorator usage?
- What function signature rules apply?

**E. Error Messages**
- What error categories exist?
- How are type mismatches reported?
- What context is provided in errors?

Output a complete specification with code examples from the actual implementation.
```

═══════════════════════════════════════════════════════════════════════════════
## PROMPT 2: EXTRACT BACKEND-SPECIFIC SEMANTIC REQUIREMENTS
═══════════════════════════════════════════════════════════════════════════════

```
Context: I have a working Quorlin compiler that targets 5 blockchain platforms.
I need to understand the semantic requirements for each backend.

TASK: Analyze how semantic analysis adapts for different backends.

Please examine these backend codegen files:
1. `crates/quorlin-codegen-evm/src/lib.rs` - EVM/Yul generator
2. `crates/quorlin-codegen-solana/src/lib.rs` - Solana/Anchor generator
3. `crates/quorlin-codegen-ink/src/lib.rs` - Polkadot/ink! generator
4. `crates/quorlin-codegen-aptos/src/move_gen.rs` - Aptos/Move generator
5. `crates/quorlin-codegen-quorlin/src/lib.rs` - Native bytecode generator

For each backend, document:

**EVM/Yul Backend:**
- What storage layout constraints exist?
- How are function selectors calculated?
- What gas estimation rules apply?
- How are events encoded?
- What checked arithmetic is required?

**Solana/Anchor Backend:**
- How are accounts structured?
- What are the state serialization requirements?
- How do PDAs (Program Derived Addresses) work?
- What instruction handlers are needed?
- What error codes must be supported?

**Polkadot/ink! Backend:**
- How is storage organized (Mapping vs Vec)?
- What are the message vs constructor differences?
- How are events emitted?
- What type restrictions apply (no u256)?
- How is AccountId different from address?

**Aptos/Move Backend:**
- How are structs/resources defined?
- What borrowing rules apply?
- How are generic types handled?
- What Move-specific constraints exist?
- How do capabilities work?

**Quorlin Bytecode Backend:**
- What is the instruction set?
- How are opcodes defined?
- What stack operations exist?
- How is memory managed?

Create a comparison table showing semantic differences across backends.
```

═══════════════════════════════════════════════════════════════════════════════
## PROMPT 3: BUILD TYPE INFERENCE ENGINE
═══════════════════════════════════════════════════════════════════════════════

```
I need to implement a type inference system matching the Quorlin compiler.

Reference implementation: `crates/quorlin-semantics/src/type_checker.rs`

TASK: Create a production-ready type inference engine with these features:

**Requirements:**
1. Infer types for all expression types:
   - Literals (int, bool, string, hex)
   - Binary operations (arithmetic, comparison, logical)
   - Unary operations (not, neg, pos)
   - Function calls
   - Index access (arrays, mappings)
   - Attribute access (struct fields, contract state)
   - List/tuple construction
   - Ternary expressions (IfExp)

2. Type compatibility checking:
   - Exact type matches
   - Numeric type promotion (uint8 → uint256)
   - Tuple element-wise compatibility
   - Mapping key/value compatibility
   - Optional type handling

3. Function signature resolution:
   - Parameter type validation
   - Return type inference
   - Multiple return values (tuples)
   - View function restrictions

4. Built-in function support:
   - Type constructors (address, uint256, etc.)
   - Math functions (safe_add, safe_sub, safe_mul, safe_div)
   - Utility functions (require, assert, range)

Implementation should:
- Use Rust with the `thiserror` crate for error handling
- Follow the exact type hierarchy from `quorlin-parser::Type`
- Provide detailed error messages with expected vs found types
- Support unknown type for partial inference

Please implement with full documentation and unit tests.
```

═══════════════════════════════════════════════════════════════════════════════
## PROMPT 4: IMPLEMENT SECURITY ANALYZER
═══════════════════════════════════════════════════════════════════════════════

```
Reference: `crates/quorlin-semantics/src/security_analyzer.rs`

TASK: Build a security analysis module that detects common smart contract vulnerabilities.

**Detection Rules to Implement:**

1. **Reentrancy Vulnerabilities**
   - Detect external calls in functions
   - Check if state is modified after external calls
   - Flag violations of Checks-Effects-Interactions pattern
   - Track call depth and recursion

2. **Access Control Issues**
   - Identify functions that modify state without auth checks
   - Detect missing `msg.sender` validation
   - Find unprotected admin functions
   - Validate decorator usage (@external, @view, etc.)

3. **Integer Overflow/Underflow**
   - Ensure arithmetic operations use checked math
   - Detect unchecked conversions
   - Validate array index bounds
   - Check loop counters

4. **State Visibility**
   - Find sensitive data in public variables
   - Detect private keys or passwords in code
   - Check for unencrypted storage

5. **Gas Optimization**
   - Detect unbounded loops
   - Find redundant storage reads/writes
   - Identify expensive operations in loops

6. **Common Pitfalls**
   - tx.origin vs msg.sender usage
   - Delegatecall to untrusted contracts
   - Unchecked external call return values
   - Timestamp dependence

Output format: Security warnings with:
- Warning type (REENTRANCY, ACCESS_CONTROL, INTEGER_OVERFLOW, etc.)
- Location (function name, line number)
- Severity (CRITICAL, HIGH, MEDIUM, LOW)
- Remediation suggestion

Non-fatal warnings only - don't block compilation.
```

═══════════════════════════════════════════════════════════════════════════════
## PROMPT 5: CREATE SYMBOL TABLE AND SCOPE MANAGER
═══════════════════════════════════════════════════════════════════════════════

```
Reference: `crates/quorlin-semantics/src/symbol_table.rs`

TASK: Implement a symbol table with proper scoping for Quorlin contracts.

**Features Required:**

1. **Symbol Types**
   - Variables (local, parameter, state)
   - Functions (with signatures)
   - Contracts (with members)
   - Events (with parameters)
   - Types (user-defined types)

2. **Scoping Rules**
   - Global scope (module level)
   - Contract scope (contract members)
   - Function scope (local variables + parameters)
   - Block scope (if/while/for blocks)
   - Nested scope support

3. **Symbol Operations**
   ```rust
   fn define_variable(name: &str, type_: &Type) -> Result<()>
   fn lookup_variable(name: &str) -> Option<&Type>
   fn define_function(name: &str, params: Vec<Type>, return_type: Option<Type>) -> Result<()>
   fn lookup_function(name: &str) -> Option<&FunctionSignature>
   fn enter_scope()
   fn exit_scope()
   ```

4. **Error Detection**
   - Duplicate definition errors
   - Undefined reference errors
   - Scope violation errors
   - Shadowing warnings (optional)

5. **Lifetime Tracking**
   - Track where symbols are defined
   - Track where symbols are used
   - Detect unused variables/functions
   - Validate initialization before use

Implementation should use a stack-based approach for scopes and HashMap for symbol storage.
Include comprehensive error messages with line numbers.
```

═══════════════════════════════════════════════════════════════════════════════
## PROMPT 6: BUILD VALIDATION FRAMEWORK
═══════════════════════════════════════════════════════════════════════════════

```
Reference: `crates/quorlin-semantics/src/validator.rs`

TASK: Create validation rules for Quorlin language constructs.

**Validator Categories:**

1. **Decorator Validation**
   Valid decorators and their usage:
   - @constructor (only on __init__ function)
   - @external (state-modifying public functions)
   - @view (read-only public functions)
   - @payable (functions that accept value)
   - @internal (private functions)

   Rules:
   - __init__ must have @constructor
   - @view and @external are mutually exclusive
   - @view functions cannot modify state
   - @payable only valid with @external

2. **Function Signature Validation**
   - Constructor must be named __init__
   - No return type on constructor
   - Parameter types must be valid
   - Return types must match function body
   - View functions must have return values

3. **State Variable Validation**
   - Valid type annotations
   - No duplicate names
   - Constant variables must have initial values
   - Mapping keys must be primitive types

4. **Expression Validation**
   - Division by zero checks
   - Array bounds validation
   - Null pointer checks (for optional types)
   - Type consistency in operations

5. **Statement Validation**
   - Return statements in correct functions
   - Break/continue only in loops
   - Revert with valid error messages
   - Emit with defined events

6. **Contract Structure Validation**
   - At least one external function
   - Events declared at module level
   - No circular dependencies
   - Valid import paths

Create a validate() function that returns Vec<ValidationError> with all issues found.
```

═══════════════════════════════════════════════════════════════════════════════
## PROMPT 7: IMPLEMENT FULL SEMANTIC ANALYSIS PIPELINE
═══════════════════════════════════════════════════════════════════════════════

```
Context: I have all the individual components (type checker, security analyzer, 
symbol table, validator). Now I need to orchestrate them into a complete pipeline.

Reference: `crates/quorlin-semantics/src/lib.rs` (the main SemanticAnalyzer struct)

TASK: Create the main semantic analysis orchestrator.

**Pipeline Structure:**

```rust
pub struct SemanticAnalyzer {
    symbols: SymbolTable,
    type_env: HashMap<String, Type>,
    current_function: Option<FunctionContext>,
    initialized_vars: HashSet<String>,
    function_return_types: HashMap<String, Option<Type>>,
}

impl SemanticAnalyzer {
    pub fn analyze(&mut self, module: &Module) -> SemanticResult<()> {
        // 1. First pass: collect all definitions
        // 2. Second pass: type check and validate
        // 3. Third pass: security analysis
    }
}
```

**Three-Pass Analysis:**

**Pass 1: Definition Collection**
- Scan for all contracts, functions, events
- Build initial symbol table
- Validate no duplicate definitions
- Record function signatures

**Pass 2: Type Checking & Validation**
- Enter each function scope
- Infer types for all expressions
- Validate type compatibility
- Check return statements match signatures
- Validate all language rules

**Pass 3: Security Analysis**
- Analyze control flow
- Detect vulnerability patterns
- Generate warnings (non-fatal)
- Suggest best practices

**Error Handling:**
- Collect all errors, don't stop on first
- Provide helpful error messages
- Include source location context
- Suggest fixes where possible

**Output:**
- Return Result<(), SemanticError> for fatal errors
- Print security warnings to stderr (non-fatal)
- Track analysis statistics (functions checked, warnings, etc.)

Implement with proper error recovery - analyze as much as possible even with errors.
```

═══════════════════════════════════════════════════════════════════════════════
## PROMPT 8: MAP SEMANTIC ANALYSIS TO EVM EXECUTION
═══════════════════════════════════════════════════════════════════════════════

```
Now that I understand Quorlin's semantic analysis, I need to implement it in my custom EVM.

TASK: Create a bridge between Quorlin semantics and EVM runtime execution.

**Context:**
- I have a custom EVM implementation
- I want to execute Quorlin-compiled contracts
- Semantic analysis must enforce runtime behavior

**Requirements:**

1. **Type System → EVM Types**
   Map Quorlin types to EVM stack/storage representations:
   ```
   uint256 → 256-bit word (native EVM)
   uint8 → 256-bit word (padded)
   address → 160-bit value (right-aligned in 256-bit)
   bool → 0 or 1 (256-bit)
   bytes32 → 256-bit value
   mapping[K,V] → Storage slot calculation via keccak256
   list[T] → Dynamic array in storage
   ```

2. **Storage Layout → SLOAD/SSTORE**
   ```rust
   // Sequential slot assignment from semantic analysis
   state_var_0 → slot 0
   state_var_1 → slot 1
   mapping[K,V] → keccak256(key . slot)
   ```

3. **Function Signatures → Dispatcher**
   ```rust
   // From semantic analysis function definitions
   fn transfer(to: address, amount: uint256)
   
   // Generate selector
   selector = keccak256("transfer(address,uint256)")[0..4]
   = 0xa9059cbb
   
   // EVM dispatcher checks selector and routes
   ```

4. **Security Checks → Runtime Assertions**
   - Reentrancy detection → Reentrancy guard in storage
   - Access control → require(msg.sender == owner)
   - Integer overflow → Use checked_add/sub/mul helpers
   - Null checks → require(address != 0)

5. **Type Inference → ABI Encoding**
   ```rust
   // Example: return (uint256, address)
   // Semantic analysis infers tuple return
   // EVM encodes as: [32 bytes uint][32 bytes address]
   ```

**Implementation Steps:**

A. Parse Yul output from Quorlin compiler
B. Extract semantic metadata (types, storage layout, function sigs)
C. Build EVM bytecode with proper type handling
D. Implement runtime type checks where needed
E. Map function selectors to implementations
F. Handle storage correctly based on type
G. Enforce security constraints at runtime

Please provide code for:
1. Yul parser to extract semantic info
2. EVM bytecode generator respecting semantics
3. Runtime type enforcement helpers
4. Function dispatcher implementation
5. Storage accessor functions (getters/setters with types)

Output should be production-ready Rust code for my EVM.
```

═══════════════════════════════════════════════════════════════════════════════
## PROMPT 9: CREATE COMPREHENSIVE TEST SUITE
═══════════════════════════════════════════════════════════════════════════════

```
I need to verify that my EVM correctly implements Quorlin semantic analysis.

TASK: Create comprehensive test cases covering all semantic analysis features.

**Test Categories:**

1. **Type Checking Tests**
   - Valid type assignments
   - Invalid type mismatches
   - Type inference accuracy
   - Generic type handling
   - Numeric promotions

2. **Symbol Resolution Tests**
   - Variable scoping
   - Function lookups
   - Shadowing behavior
   - Duplicate definitions
   - Undefined references

3. **Security Analysis Tests**
   - Reentrancy detection
   - Access control validation
   - Integer overflow scenarios
   - Common vulnerability patterns

4. **Validation Tests**
   - Decorator usage
   - Function signatures
   - Return type matching
   - Statement validity

5. **Backend Compatibility Tests**
   For each backend (EVM, Solana, Polkadot, Aptos, Quorlin):
   - Compile sample contracts
   - Verify semantic analysis passes
   - Check generated code correctness
   - Test runtime behavior

**Test Contracts:**
Use these from the Quorlin repo:
- `examples/contracts/counter.ql`
- `examples/contracts/token_simple.ql`
- `examples/contracts/voting_simple.ql`

**Test Format:**
```rust
#[test]
fn test_type_inference_uint256() {
    let source = "let x: uint256 = 42";
    let analyzer = SemanticAnalyzer::new();
    let result = analyzer.analyze(parse(source));
    assert!(result.is_ok());
    assert_eq!(analyzer.get_type("x"), Type::Simple("uint256"));
}
```

Create at least 50 test cases covering edge cases and error conditions.
Include both positive tests (should pass) and negative tests (should fail).
```

═══════════════════════════════════════════════════════════════════════════════
## PROMPT 10: FINAL INTEGRATION GUIDE
═══════════════════════════════════════════════════════════════════════════════

```
I have implemented all components. Now I need step-by-step integration instructions.

TASK: Provide a clear integration checklist and implementation order.

**Integration Steps:**

1. **Setup Phase**
   □ Install Rust toolchain
   □ Set up project structure
   □ Add dependencies (thiserror, etc.)
   □ Copy AST definitions from quorlin-parser

2. **Core Implementation** (in order)
   □ Implement symbol table (PROMPT 5)
   □ Implement type checker (PROMPT 3)
   □ Implement validator (PROMPT 6)
   □ Implement security analyzer (PROMPT 4)
   □ Implement main orchestrator (PROMPT 7)

3. **EVM Integration**
   □ Analyze backend-specific requirements (PROMPT 2)
   □ Map semantics to EVM execution (PROMPT 8)
   □ Implement Yul parser
   □ Build EVM bytecode generator
   □ Add runtime type enforcement

4. **Testing & Validation**
   □ Run test suite (PROMPT 9)
   □ Compile example contracts
   □ Verify EVM execution matches other backends
   □ Performance benchmarking

5. **Documentation**
   □ API documentation
   □ Integration guide
   □ Error message reference
   □ Security best practices guide

**Verification Checklist:**

Test your implementation against Quorlin compiler outputs:
```bash
# Compile with Quorlin compiler
cd quorlin-lang
cargo run --bin qlc -- compile examples/contracts/counter.ql --target evm

# Your EVM should:
✓ Parse the generated Yul code
✓ Extract semantic metadata
✓ Generate compatible bytecode
✓ Execute with identical behavior
✓ Produce same events/storage changes
```

**Common Issues & Solutions:**
- Type mismatch errors → Check type compatibility logic
- Storage corruption → Verify slot calculation
- Function not found → Check selector generation
- Reentrancy failures → Review call order
- Gas estimation wrong → Update cost constants

Provide debugging strategies and troubleshooting steps for each component.
```

═══════════════════════════════════════════════════════════════════════════════
## USAGE INSTRUCTIONS
═══════════════════════════════════════════════════════════════════════════════

**How to use these prompts:**

1. Start with PROMPT 1 to understand the architecture
2. Use PROMPT 2 to understand backend differences
3. Implement components using PROMPTS 3-7 in order
4. Integrate with your EVM using PROMPT 8
5. Validate using PROMPT 9
6. Follow PROMPT 10 for final integration

**Each prompt should be given to Claude/Antigravity separately**
**Wait for completion before moving to the next prompt**

Good luck with your EVM implementation! 🚀
