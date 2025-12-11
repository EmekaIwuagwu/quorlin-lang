# Quorlin Compiler Architecture Analysis

**Generated**: 2025-12-07  
**Purpose**: Complete architectural analysis for Phase 9 implementation (Additional Blockchain Backends + Standard Library Enhancement)

---

## Executive Summary

The Quorlin compiler is a multi-target smart contract compiler that translates `.ql` source files into:
- **EVM**: Yul intermediate representation → Solidity bytecode
- **Solana**: Anchor-compatible Rust programs
- **Polkadot**: ink! smart contracts (Rust/WASM)

**Current Status**:
- ✅ Core lexer, parser, and AST definitions complete
- ✅ Basic EVM, Solana, and ink! code generators implemented
- ✅ Initial standard library structure exists (`stdlib/`)
- ⚠️ **Build system requires Visual Studio Build Tools** (linker issue on Windows)
- 🔨 **Missing**: Aptos, StarkNet, Avalanche backends
- 🔨 **Missing**: Complete stdlib integration into compiler
- 🔨 **Missing**: Static analyzer with type checking and security analysis
- 🔨 **Missing**: Comprehensive reference contracts

---

## Directory Structure

```
quorlin-lang/
├── crates/                          # Rust workspace crates
│   ├── qlc/                         # Main CLI binary
│   │   └── src/
│   │       ├── main.rs              # Entry point (107 lines)
│   │       └── commands/            # CLI subcommands (7 modules)
│   ├── quorlin-lexer/               # Tokenization (logos-based)
│   ├── quorlin-parser/              # LALRPOP parser
│   │   └── src/
│   │       ├── ast.rs               # AST definitions (304 lines) ✅
│   │       ├── grammar.lalrpop      # Full grammar (20KB)
│   │       ├── grammar_minimal.lalrpop
│   │       ├── grammar_simple.lalrpop
│   │       ├── parser.rs            # Generated parser (33KB)
│   │       └── lib.rs
│   ├── quorlin-semantics/           # Type checking & validation
│   ├── quorlin-ir/                  # Intermediate representation
│   ├── quorlin-codegen-evm/         # EVM/Yul code generator
│   │   └── src/
│   │       ├── lib.rs               # Main codegen (35KB)
│   │       ├── yul_generator.rs     # Yul output (7KB)
│   │       ├── abi.rs               # ABI generation (5KB)
│   │       └── storage_layout.rs    # Storage layout (5KB)
│   ├── quorlin-codegen-solana/      # Solana/Anchor codegen
│   ├── quorlin-codegen-ink/         # Polkadot/ink! codegen
│   └── quorlin-common/              # Shared utilities
│
├── stdlib/                          # Standard library (Quorlin .ql files)
│   ├── README.md                    # Stdlib documentation (98 lines)
│   ├── math/
│   │   └── safe_math.ql             # Safe arithmetic (84 lines) ✅
│   ├── token/
│   │   └── erc20.ql                 # ERC-20 implementation (178 lines) ✅
│   ├── access/
│   │   ├── ownable.ql               # Ownership pattern (1.7KB)
│   │   └── access_control.ql        # Role-based access (3.4KB)
│   └── errors.ql                    # Standard errors (699 bytes)
│
├── examples/                        # Example contracts
│   ├── 00_counter_simple.ql
│   ├── 01_hello_world.ql
│   ├── 02_variables.ql
│   ├── 03_arithmetic.ql
│   ├── 04_functions.ql
│   ├── 05_control_flow.ql
│   ├── 06_data_structures.ql
│   ├── token.ql                     # Token example (4.5KB)
│   └── README.md
│
├── tests/                           # Test suite
│   ├── integration/
│   └── unit/
│
├── docs/                            # Documentation
├── output/                          # Compilation outputs
├── Cargo.toml                       # Workspace manifest
└── README.md

```

---

## Compilation Pipeline

```
┌─────────────────┐
│  Source (.ql)   │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Lexer (logos)  │  ← quorlin-lexer
│  Tokenization   │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Parser (LALRPOP)│  ← quorlin-parser
│  AST Generation │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Semantics      │  ← quorlin-semantics
│  Type Checking  │     (NEEDS ENHANCEMENT)
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  IR Generation  │  ← quorlin-ir
│  (Optional)     │
└────────┬────────┘
         │
         ├──────────────┬──────────────┬──────────────┬──────────────┬──────────────┐
         ▼              ▼              ▼              ▼              ▼              ▼
    ┌────────┐    ┌────────┐    ┌────────┐    ┌────────┐    ┌────────┐    ┌────────┐
    │  EVM   │    │ Solana │    │Polkadot│    │ Aptos  │    │StarkNet│    │Avalanche│
    │  Yul   │    │ Anchor │    │  ink!  │    │  Move  │    │ Cairo  │    │  EVM   │
    └────────┘    └────────┘    └────────┘    └────────┘    └────────┘    └────────┘
       ✅            ✅            ✅            🔨            🔨            🔨
```

**Legend**:
- ✅ = Implemented
- 🔨 = Needs implementation (Phase 9)

---

## AST Structure (Key Types)

From `crates/quorlin-parser/src/ast.rs`:

### Top-Level Items
```rust
pub enum Item {
    Import(ImportStmt),      // from std.math import safe_add
    Contract(ContractDecl),  // contract MyToken: ...
    Struct(StructDecl),      // struct Transaction: ...
    Enum(EnumDecl),          // enum Status: ...
    Interface(InterfaceDecl),// interface IERC20: ...
    Event(EventDecl),        // event Transfer(...)
    Error(ErrorDecl),        // error InsufficientBalance(...)
}
```

### Import Statement
```rust
pub struct ImportStmt {
    pub module: String,      // "std.math"
    pub items: Vec<String>,  // ["safe_add", "safe_sub"]
}
```

**Current Parser Support**: ✅ Import statements are already parsed!

### Contract Structure
```rust
pub struct ContractDecl {
    pub name: String,
    pub bases: Vec<String>,           // Inheritance
    pub body: Vec<ContractMember>,
    pub docstring: Option<String>,
}

pub enum ContractMember {
    StateVar(StateVar),    // balances: mapping[address, uint256]
    Function(Function),    // fn transfer(...): ...
    Constant(Constant),    // MAX_SUPPLY: uint256 = 1000000
}
```

### Type System
```rust
pub enum Type {
    Simple(String),                    // uint256, address, bool
    List(Box<Type>),                   // list[uint256]
    FixedArray(Box<Type>, usize),      // uint256[10]
    Mapping(Box<Type>, Box<Type>),     // mapping[address, uint256]
    Optional(Box<Type>),               // Optional[address]
    Tuple(Vec<Type>),                  // (uint256, address)
}
```

### Expressions
```rust
pub enum Expr {
    IntLiteral(String),
    HexLiteral(String),
    StringLiteral(String),
    BoolLiteral(bool),
    NoneLiteral,
    Ident(String),
    BinOp(Box<Expr>, BinOp, Box<Expr>),
    UnaryOp(UnaryOp, Box<Expr>),
    Call(Box<Expr>, Vec<Expr>),
    Attribute(Box<Expr>, String),      // self.balances
    Index(Box<Expr>, Box<Expr>),       // balances[owner]
    List(Vec<Expr>),
    Tuple(Vec<Expr>),
}
```

---

## Existing Standard Library

### Current Modules

#### 1. `stdlib/math/safe_math.ql` (84 lines)
```ql
fn safe_add(a: uint256, b: uint256) -> uint256
fn safe_sub(a: uint256, b: uint256) -> uint256
fn safe_mul(a: uint256, b: uint256) -> uint256
fn safe_div(a: uint256, b: uint256) -> uint256
fn safe_mod(a: uint256, b: uint256) -> uint256
fn safe_pow(base: uint256, exponent: uint256) -> uint256
fn min(a: uint256, b: uint256) -> uint256
fn max(a: uint256, b: uint256) -> uint256
fn average(a: uint256, b: uint256) -> uint256
```

**Status**: ✅ Implemented, uses `require()` for checks

#### 2. `stdlib/token/erc20.ql` (178 lines)
```ql
from std.math import safe_add, safe_sub

interface IERC20: ...
contract ERC20:
    _name: str
    _symbol: str
    _decimals: uint8
    _total_supply: uint256
    _balances: mapping[address, uint256]
    _allowances: mapping[address, mapping[address, uint256]]
    
    fn transfer(to: address, amount: uint256) -> bool
    fn approve(spender: address, amount: uint256) -> bool
    fn transfer_from(from_addr: address, to: address, amount: uint256) -> bool
    fn _mint(account: address, amount: uint256)
    fn _burn(account: address, amount: uint256)
```

**Status**: ✅ Implemented, imports from `std.math`

#### 3. `stdlib/access/ownable.ql` (1.7KB)
Single-owner access control pattern

#### 4. `stdlib/access/access_control.ql` (3.4KB)
Role-based access control

#### 5. `stdlib/errors.ql` (699 bytes)
Standard error definitions

---

## Backend Code Generators

### 1. EVM Backend (`quorlin-codegen-evm`)

**Files**:
- `lib.rs` (35KB) - Main code generator
- `yul_generator.rs` (7KB) - Yul IR generation
- `abi.rs` (5KB) - ABI JSON generation
- `storage_layout.rs` (5KB) - Storage slot allocation

**Output Format**: Yul (Solidity IR)

**Example Output**:
```yul
object "Counter" {
    code {
        datacopy(0, dataoffset("runtime"), datasize("runtime"))
        return(0, datasize("runtime"))
    }
    object "runtime" {
        code {
            // Contract runtime code
        }
    }
}
```

### 2. Solana Backend (`quorlin-codegen-solana`)

**Output Format**: Anchor Rust program

**Status**: ✅ Basic implementation exists

### 3. Polkadot Backend (`quorlin-codegen-ink`)

**Output Format**: ink! smart contract (Rust)

**Status**: ✅ Basic implementation exists

### 4. **NEW**: Aptos Backend (Phase 9)

**Target**: Move language
**Location**: `crates/quorlin-codegen-aptos/` (TO BE CREATED)

### 5. **NEW**: StarkNet Backend (Phase 9)

**Target**: Cairo language
**Location**: `crates/quorlin-codegen-starknet/` (TO BE CREATED)

### 6. **NEW**: Avalanche Backend (Phase 9)

**Target**: Solidity (EVM-compatible)
**Location**: `crates/quorlin-codegen-avalanche/` (TO BE CREATED)

---

## Import Resolution Mechanism

### Current State
- ✅ Parser recognizes `from std.math import safe_add` syntax
- ✅ AST has `ImportStmt` structure
- ❌ **No runtime resolution** - imports are parsed but not processed
- ❌ **No module loader** - stdlib files not read during compilation

### Required Implementation

**New Crate**: `crates/quorlin-resolver/`

```rust
pub struct StdlibResolver {
    stdlib_root: PathBuf,              // Path to stdlib/
    module_cache: HashMap<String, String>,
    stdlib_enabled: bool,
}

impl StdlibResolver {
    pub fn resolve_import(&mut self, module_path: &str) 
        -> Result<Option<String>, ResolverError>;
    
    fn module_path_to_file(&self, module_path: &str) 
        -> Result<PathBuf, ResolverError>;
}
```

**Integration Point**: `crates/quorlin-semantics/` or new `crates/quorlin-compiler/`

---

## Hook Points for Phase 9 Implementation

### 1. Add New Backend Crates

**Cargo.toml** additions:
```toml
[workspace]
members = [
    # ... existing ...
    "crates/quorlin-codegen-aptos",
    "crates/quorlin-codegen-starknet",
    "crates/quorlin-codegen-avalanche",
    "crates/quorlin-resolver",
    "crates/quorlin-analyzer",
]
```

### 2. Extend CLI Commands

**File**: `crates/qlc/src/commands/compile.rs`

Add backend selection:
```rust
match target.as_str() {
    "evm" => /* existing */,
    "solana" => /* existing */,
    "ink" | "polkadot" => /* existing */,
    "aptos" | "move" => /* NEW */,
    "starknet" | "cairo" => /* NEW */,
    "avalanche" | "avax" => /* NEW */,
    _ => return Err(format!("Unknown target: {}", target)),
}
```

### 3. Add Analyzer Command

**File**: `crates/qlc/src/commands/analyze.rs` (TO BE CREATED)

```rust
pub fn run(file: PathBuf, options: AnalyzeOptions) -> Result<()> {
    // 1. Parse file
    // 2. Run type checker
    // 3. Run security analyzer
    // 4. Generate gas estimates
    // 5. Output results
}
```

### 4. Stdlib Integration

**Modification Point**: Compilation pipeline before semantic analysis

```rust
// In compiler main flow:
fn compile(source: &str, config: CompilerConfig) -> Result<Output> {
    let ast = parse(source)?;
    
    // NEW: Resolve imports
    if config.enable_stdlib {
        let mut resolver = StdlibResolver::new(&config.stdlib_path);
        let resolved_ast = resolver.resolve_imports(ast)?;
        
        // Continue with resolved AST
        let checked_ast = type_check(resolved_ast)?;
        // ...
    }
}
```

---

## Module Dependency Graph

```
qlc (CLI)
  ├─→ quorlin-lexer
  ├─→ quorlin-parser
  │     └─→ quorlin-common
  ├─→ quorlin-semantics
  │     ├─→ quorlin-parser (AST)
  │     └─→ quorlin-common
  ├─→ quorlin-ir
  │     └─→ quorlin-parser (AST)
  ├─→ quorlin-codegen-evm
  │     ├─→ quorlin-ir
  │     └─→ quorlin-parser (AST)
  ├─→ quorlin-codegen-solana
  │     └─→ quorlin-parser (AST)
  ├─→ quorlin-codegen-ink
  │     └─→ quorlin-parser (AST)
  │
  └─→ [NEW] quorlin-resolver
        ├─→ quorlin-parser (AST)
        └─→ stdlib/ (file system)
```

---

## Files Requiring Modification

### Phase 9 Implementation Checklist

#### ✅ Already Exists (No Changes Needed)
- `crates/quorlin-parser/src/ast.rs` - Import AST already defined
- `stdlib/math/safe_math.ql` - Core math functions exist
- `stdlib/token/erc20.ql` - ERC-20 implementation exists

#### 🔨 New Files to Create

**Backend Implementations**:
1. `crates/quorlin-codegen-aptos/Cargo.toml`
2. `crates/quorlin-codegen-aptos/src/lib.rs`
3. `crates/quorlin-codegen-starknet/Cargo.toml`
4. `crates/quorlin-codegen-starknet/src/lib.rs`
5. `crates/quorlin-codegen-avalanche/Cargo.toml`
6. `crates/quorlin-codegen-avalanche/src/lib.rs`

**Stdlib Resolver**:
7. `crates/quorlin-resolver/Cargo.toml`
8. `crates/quorlin-resolver/src/lib.rs`
9. `crates/quorlin-resolver/src/stdlib.rs`

**Static Analyzer**:
10. `crates/quorlin-analyzer/Cargo.toml`
11. `crates/quorlin-analyzer/src/lib.rs`
12. `crates/quorlin-analyzer/src/typeck.rs`
13. `crates/quorlin-analyzer/src/lints.rs`
14. `crates/quorlin-analyzer/src/gas.rs`
15. `crates/quorlin-analyzer/src/security.rs`

**Enhanced Stdlib**:
16. `stdlib/std/crypto.ql`
17. `stdlib/std/time.ql`
18. `stdlib/std/log.ql`
19. `stdlib/std/token/qspl.ql` (Solana SPL)
20. `stdlib/std/token/qpsp22.ql` (Polkadot PSP22)
21. `stdlib/std/token/standard_token.ql` (Universal)

**Reference Contracts**:
22. `examples/contracts/nft.ql`
23. `examples/contracts/multisig.ql`
24. `examples/contracts/amm.ql`
25. `examples/contracts/staking.ql`
26. `examples/contracts/governance.ql`
27. `examples/contracts/marketplace.ql`

**CLI Commands**:
28. `crates/qlc/src/commands/analyze.rs`
29. `crates/qlc/src/commands/lint.rs`

**Tests**:
30. `tests/stdlib/test_math.rs`
31. `tests/stdlib/test_token.rs`
32. `tests/stdlib/test_crypto.rs`
33. `tests/analyzer/test_typeck.rs`
34. `tests/analyzer/test_security.rs`
35. `tests/contracts/test_nft.rs`
36. `tests/contracts/test_multisig.rs`
37. `tests/contracts/test_amm.rs`
38. `tests/integration/test_compilation.rs`
39. `tests/integration/test_full_compilation.rs`

**Documentation**:
40. `docs/STDLIB.md`
41. `docs/ANALYZER.md`
42. `docs/CONTRACTS.md`
43. `docs/BACKENDS.md`

**CI/CD**:
44. `.github/workflows/full_test_suite.yml`

#### 📝 Files to Modify

1. **`Cargo.toml`** (root workspace)
   - Add new crate members
   - Add dependencies for analyzer

2. **`crates/qlc/src/main.rs`**
   - Add `analyze` and `lint` commands

3. **`crates/qlc/src/commands/compile.rs`**
   - Add Aptos, StarkNet, Avalanche backend selection
   - Integrate stdlib resolver

4. **`crates/quorlin-semantics/src/lib.rs`**
   - Integrate import resolution
   - Call analyzer before codegen

5. **`stdlib/README.md`**
   - Update with new modules

---

## Quorlin Language Syntax Reference

Based on existing examples and parser:

### Basic Contract
```ql
contract Counter:
    count: uint256
    
    @constructor
    fn __init__():
        self.count = 0
    
    @external
    fn increment():
        self.count = self.count + 1
    
    @view
    fn get_count() -> uint256:
        return self.count
```

### Imports
```ql
from std.math import safe_add, safe_sub
from std.token import ERC20
from std.access import Ownable
```

### State Variables
```ql
contract MyContract:
    owner: address
    balances: mapping[address, uint256]
    total_supply: uint256
    is_paused: bool
```

### Functions
```ql
@external
fn transfer(to: address, amount: uint256) -> bool:
    require(to != address(0), "Invalid address")
    self.balances[msg.sender] = safe_sub(self.balances[msg.sender], amount)
    self.balances[to] = safe_add(self.balances[to], amount)
    emit Transfer(msg.sender, to, amount)
    return True
```

### Control Flow
```ql
if condition:
    # then branch
elif other_condition:
    # elif branch
else:
    # else branch

while i < 10:
    i = i + 1

for item in items:
    process(item)
```

### Events
```ql
event Transfer(from_addr: address, to: address, value: uint256)

# Emit
emit Transfer(msg.sender, recipient, amount)
```

### Errors
```ql
error InsufficientBalance(available: uint256, needed: uint256)

# Raise
raise InsufficientBalance(balance, amount)
```

---

## Build System Notes

### Current Issue
**Error**: `linker 'link.exe' not found`

**Cause**: Windows MSVC toolchain requires Visual Studio Build Tools

**Solution**:
```powershell
# Install Visual Studio Build Tools
# OR use rustup to switch to GNU toolchain:
rustup default stable-x86_64-pc-windows-gnu
```

### Build Commands
```bash
# Full release build
cargo build --release

# Check without building
cargo check --all

# Run tests
cargo test --all

# Build specific crate
cargo build -p quorlin-codegen-evm

# Run compiler
./target/release/qlc compile examples/token.ql --target evm --output output/
```

---

## Testing Strategy

### Test Categories

1. **Unit Tests** (`tests/unit/`)
   - Lexer tests
   - Parser tests
   - AST tests
   - Type checker tests

2. **Stdlib Tests** (`tests/stdlib/`)
   - Math operations
   - Token standards
   - Crypto functions
   - Access control

3. **Contract Tests** (`tests/contracts/`)
   - NFT functionality
   - Multisig wallet
   - AMM/DEX
   - Staking
   - Governance

4. **Integration Tests** (`tests/integration/`)
   - End-to-end compilation
   - Multi-backend compilation
   - Import resolution
   - Gas profiling

5. **Backend Tests**
   - EVM bytecode validation
   - Solana program validation
   - ink! contract validation
   - Aptos Move validation
   - StarkNet Cairo validation

---

## Gas Estimation Strategy

### Per-Backend Metrics

**EVM**:
- Deployment gas
- Function call gas (min/avg/max)
- Storage operations cost

**Solana**:
- Compute units
- Instruction count
- Account size

**Polkadot**:
- Weight (ref_time)
- Proof size

**Aptos**:
- Gas units
- Storage fees

**StarkNet**:
- Cairo steps
- L1 data cost

---

## Security Analysis Patterns

### Checks to Implement

1. **Reentrancy Detection**
   - External calls before state changes
   - Checks-Effects-Interactions pattern

2. **Arithmetic Safety**
   - Unchecked operations
   - Division by zero
   - Overflow/underflow

3. **Access Control**
   - Missing authorization checks
   - Privilege escalation

4. **State Consistency**
   - Uninitialized variables
   - Race conditions

5. **Gas Optimization**
   - Unbounded loops
   - Expensive storage operations

---

## Next Steps (Phase 9 Execution)

### Priority 1: Core Infrastructure
1. ✅ Create `ARCHITECTURE_ANALYSIS.md` (this document)
2. 🔨 Validate base compiler works without stdlib
3. 🔨 Create `quorlin-resolver` crate
4. 🔨 Create `quorlin-analyzer` crate
5. 🔨 Integrate resolver into compilation pipeline

### Priority 2: New Backends
6. 🔨 Implement Aptos backend
7. 🔨 Implement StarkNet backend
8. 🔨 Implement Avalanche backend
9. 🔨 Update CLI for new backends

### Priority 3: Enhanced Stdlib
10. 🔨 Create `stdlib/std/crypto.ql`
11. 🔨 Create `stdlib/std/time.ql`
12. 🔨 Create `stdlib/std/log.ql`
13. 🔨 Create cross-chain token standards

### Priority 4: Reference Contracts
14. 🔨 Implement NFT contract
15. 🔨 Implement Multisig wallet
16. 🔨 Implement AMM/DEX
17. 🔨 Implement Staking contract
18. 🔨 Implement Governance contract

### Priority 5: Testing & CI
19. 🔨 Write comprehensive tests
20. 🔨 Set up GitHub Actions CI
21. 🔨 Generate documentation
22. 🔨 Create final validation suite

---

## Conclusion

The Quorlin compiler has a solid foundation with:
- ✅ Complete lexer and parser
- ✅ Well-defined AST
- ✅ Three working backends (EVM, Solana, Polkadot)
- ✅ Initial stdlib modules

**Phase 9 will add**:
- 3 new blockchain backends (Aptos, StarkNet, Avalanche)
- Complete stdlib integration with import resolution
- Static analyzer with security checks
- 6+ production-ready reference contracts
- Comprehensive testing and CI/CD

**Estimated Implementation**: ~40-50 new files, ~15,000 lines of code

**Key Success Metric**: All reference contracts compile to all 6 backends without errors.

---

**End of Architecture Analysis**
