# Quorlin Compiler Architecture

## High-Level Overview

```
┌──────────────┐
│ .ql Source   │
│   Files      │
└──────┬───────┘
       │
       ▼
┌─────────────────────────────────────────────────────────────┐
│                    COMPILER PIPELINE                         │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌─────────┐      ┌─────────┐      ┌──────────────┐       │
│  │ LEXER   │──►   │ PARSER  │──►   │  SEMANTIC    │       │
│  │         │      │         │      │   ANALYZER   │       │
│  │ Tokens  │      │   AST   │      │              │       │
│  └─────────┘      └─────────┘      └──────┬───────┘       │
│                                            │                │
│                                            ▼                │
│                             ┌──────────────────────┐       │
│                             │   CODE GENERATORS    │       │
│                             │   (Backends)         │       │
│                             └──────┬───────────────┘       │
│                                    │                        │
│                    ┌───────────────┼───────────────┐       │
│                    │               │               │        │
│                    ▼               ▼               ▼        │
│              ┌─────────┐     ┌─────────┐     ┌─────────┐  │
│              │   EVM   │     │ SOLANA  │     │  ink!   │  │
│              │  (Yul)  │     │ (Anchor)│     │(Polkadot)│ │
│              └─────────┘     └─────────┘     └─────────┘  │
└──────────────────────────────────────────────────────────────┘
       │               │               │
       ▼               ▼               ▼
  ┌────────┐      ┌────────┐      ┌────────┐
  │ .yul   │      │  .rs   │      │  .rs   │
  │ file   │      │ file   │      │ file   │
  └────────┘      └────────┘      └────────┘
```

## Compilation Flow

**Quorlin source (.ql) → Lexer → Parser → Semantic Analyzer → Backend Codegen → Target code**

### Phase 1: Lexical Analysis (Lexer)
- **Crate**: `quorlin-lexer`
- **Input**: Raw Quorlin source code (String)
- **Output**: Stream of tokens with span information
- **Key Responsibilities**:
  - Tokenization using logos-based lexer
  - Python-style indentation tracking (INDENT/DEDENT tokens)
  - Error reporting with line/column positions
- **Files**:
  - `crates/quorlin-lexer/src/lexer.rs` - Main lexer implementation
  - `crates/quorlin-lexer/src/token.rs` - Token definitions
  - `crates/quorlin-lexer/src/indent.rs` - Indentation processor

### Phase 2: Parsing (Parser)
- **Crate**: `quorlin-parser`
- **Input**: Token stream
- **Output**: Abstract Syntax Tree (AST/Module)
- **Key Responsibilities**:
  - Hand-written recursive descent parser
  - AST construction with type annotations
  - Basic syntax validation
- **Files**:
  - `crates/quorlin-parser/src/parser.rs` - Parser implementation
  - `crates/quorlin-parser/src/ast.rs` - AST node definitions
  - `crates/quorlin-parser/src/lib.rs` - Public API

### Phase 3: Semantic Analysis (Type Checker)
- **Crate**: `quorlin-semantics`
- **Input**: AST
- **Output**: Validated AST (side-effect: errors if invalid)
- **Key Responsibilities**:
  - Name resolution and scope analysis
  - Type checking and validation
  - Decorator validation
  - Symbol table management
- **Files**:
  - `crates/quorlin-semantics/src/lib.rs` - Main analyzer
  - `crates/quorlin-semantics/src/symbol_table.rs` - Symbol tracking
  - `crates/quorlin-semantics/src/type_checker.rs` - Type inference
  - `crates/quorlin-semantics/src/validator.rs` - Semantic validation

### Phase 4: Code Generation (Backends)
- **Crates**:
  - `quorlin-codegen-evm` (Ethereum/Yul)
  - `quorlin-codegen-solana` (Solana/Anchor)
  - `quorlin-codegen-ink` (Polkadot/ink!)
- **Input**: Validated AST
- **Output**: Platform-specific code
- **Key Responsibilities**:
  - Storage layout computation
  - Function dispatching logic
  - Type mapping (Quorlin types → platform types)
  - Security pattern implementation

## Crate Structure

### Core Compiler Crates

```
quorlin-lang/
├── crates/
│   ├── qlc/                    # CLI entry point
│   │   └── src/
│   │       ├── main.rs         # Command-line interface
│   │       └── commands/       # Subcommands (compile, check, etc.)
│   │
│   ├── quorlin-common/         # Shared utilities
│   │   └── src/
│   │       ├── diagnostics.rs  # Error reporting
│   │       └── span.rs         # Source location tracking
│   │
│   ├── quorlin-lexer/          # Tokenization
│   │   └── src/
│   │       ├── lexer.rs        # Main lexer
│   │       ├── token.rs        # Token types
│   │       └── indent.rs       # Indentation handling
│   │
│   ├── quorlin-parser/         # Parsing
│   │   └── src/
│   │       ├── parser.rs       # Recursive descent parser
│   │       ├── ast.rs          # AST definitions
│   │       └── lib.rs          # Public API
│   │
│   ├── quorlin-semantics/      # Type checking & validation
│   │   └── src/
│   │       ├── lib.rs          # Semantic analyzer
│   │       ├── symbol_table.rs # Symbol management
│   │       ├── type_checker.rs # Type inference
│   │       └── validator.rs    # Validation rules
│   │
│   ├── quorlin-ir/             # Intermediate representation (UNUSED)
│   │   └── src/lib.rs          # Currently empty/placeholder
│   │
│   ├── quorlin-codegen-evm/    # EVM backend
│   │   └── src/
│   │       ├── lib.rs          # Main generator
│   │       ├── yul_generator.rs
│   │       ├── storage_layout.rs
│   │       └── abi.rs
│   │
│   ├── quorlin-codegen-solana/ # Solana backend
│   │   └── src/lib.rs
│   │
│   └── quorlin-codegen-ink/    # Polkadot backend
│       └── src/lib.rs
│
├── stdlib/                     # Standard library (.ql files)
│   ├── math/
│   ├── access/
│   └── token/
│
├── examples/                   # Example contracts
│   └── token.ql
│
└── tests/                      # Integration tests
    └── integration_test.rs
```

## Data Flow Details

### 1. Lexer → Parser
```rust
// Lexer produces
Vec<Token> {
    Token { token_type: Contract, span: Span {...} },
    Token { token_type: Ident("Token"), span: Span {...} },
    ...
}

// Parser consumes tokens to produce AST
Module {
    items: vec![
        Item::Contract(ContractDecl {
            name: "Token",
            body: vec![...],
        })
    ]
}
```

### 2. Parser → Semantic Analyzer
```rust
// AST contains type annotations
StateVar {
    name: "balances",
    type_annotation: Type::Mapping(
        Box::new(Type::Simple("address")),
        Box::new(Type::Simple("uint256"))
    ),
}

// Analyzer validates types and builds symbol table
```

### 3. Semantic Analyzer → Backends
```rust
// Each backend receives validated AST
impl EvmCodegen {
    pub fn generate(&mut self, module: &Module) -> Result<String> {
        // Transform AST → Yul code
    }
}
```

## Type System

### Quorlin Types
- **Primitives**: `bool`, `uint8`, `uint16`, `uint32`, `uint64`, `uint128`, `uint256`, `int256`, `address`, `bytes32`, `str`
- **Compound**: `mapping[K, V]`, `list[T]`, `tuple`, `Optional[T]`

### Type Mapping Across Backends

| Quorlin Type | EVM (Yul) | Solana (Anchor) | Polkadot (ink!) |
|--------------|-----------|-----------------|-----------------|
| `uint256` | `uint256` | `u128` | `U256` (via type) |
| `address` | `address` | `Pubkey` | `AccountId` |
| `bool` | `bool` | `bool` | `bool` |
| `mapping[K,V]` | Storage slots | `HashMap<K,V>` | `Mapping<K,V>` |
| `str` | `string` | `String` | `String` |

## Missing/Incomplete Components

### 1. Intermediate Representation (IR)
- **Status**: Crate exists but is UNUSED
- **Impact**: Direct AST→Code transformation is fragile
- **Location**: `crates/quorlin-ir/`

### 2. Optimization Passes
- **Status**: `--optimize` flag exists but UNIMPLEMENTED
- **Impact**: No dead code elimination, constant folding, etc.

### 3. Complete Type Checker
- **Status**: PARTIAL implementation with many TODOs
- **Impact**: Type errors may pass through to code generation
- **Missing**:
  - Binary operation type checking
  - Function return type validation
  - Assignment compatibility checking
  - Attribute type lookup
  - Index type validation

### 4. Security Analysis
- **Status**: NOT IMPLEMENTED
- **Impact**: No static detection of:
  - Reentrancy vulnerabilities
  - Integer overflow (despite safe_math in stdlib)
  - Uninitialized storage
  - Access control issues

### 5. Standard Library Resolution
- **Status**: Import statements IGNORED
- **Impact**: Cannot verify stdlib usage
- **Location**: `semantics/lib.rs:83` - "TODO: Handle imports"

## Security Patterns

### Current Implementation
1. **Safe Math**: Generated code uses checked arithmetic in backends
2. **Storage Layout**: Deterministic slot allocation
3. **Function Dispatching**: Proper selector generation

### Missing Security Features
1. **Reentrancy Guards**: No `@nonreentrant` implementation
2. **Access Control Validation**: Decorators parsed but not enforced
3. **Integer Overflow Detection**: Reliance on runtime checks only
4. **Uninitialized Variable Detection**: No static analysis
5. **External Call Safety**: No checks for return value handling

## Backend Parity Analysis

### Feature Support Matrix

| Feature | EVM | Solana | ink! | Notes |
|---------|-----|--------|------|-------|
| Basic Types | ✓ | ✓ | ✓ | All working |
| Mappings | ✓ | ✓ | ✓ | Nested mappings supported |
| Events | ✓ | ✓ | ✓ | Different implementations |
| Require | ✓ | ✓ | ✓ | Platform-specific revert |
| For Loops | ⚠️ | ✓ | ✓ | EVM has TODO comment |
| Arithmetic | ⚠️ | ✓ | ✓ | EVM lacks overflow checks |
| Structs | ❌ | ❌ | ❌ | Parsed but not codegen |
| Inheritance | ❌ | ❌ | ❌ | AST supports, no codegen |

## Testing Infrastructure

### Current State
- **Unit Tests**: Minimal (only basic smoke tests)
- **Integration Tests**: One test file with limited coverage
- **Fuzzing**: NOT IMPLEMENTED
- **CI/CD**: NOT CONFIGURED

### Test Coverage Gaps
1. **Lexer**: No comprehensive token tests
2. **Parser**: No AST validation tests
3. **Semantics**: No type checking regression tests
4. **Backends**: No code generation correctness tests
5. **End-to-End**: No deployment/execution tests

## Build & Usage

### Building the Compiler
```bash
cargo build --release
# Binary: ./target/release/qlc
```

### Compilation Commands
```bash
# Tokenize only
qlc tokenize examples/token.ql

# Parse only (show AST)
qlc parse examples/token.ql --json

# Full compilation
qlc compile examples/token.ql --target evm -o output.yul
qlc compile examples/token.ql --target solana -o output.rs
qlc compile examples/token.ql --target ink -o output.rs
```

### Running Tests
```bash
# Unit tests
cargo test

# Integration test script
bash test_all.sh
```

## Critical Production Gaps

### High Priority
1. **Complete type checker** - Prevent type errors at runtime
2. **Proper error handling** - Remove unwraps in production code
3. **Comprehensive tests** - Prevent regressions
4. **Security analysis** - Static vulnerability detection
5. **Backend parity** - Ensure consistent semantics

### Medium Priority
6. **IR layer** - Enable optimizations and better codegen
7. **Standard library resolution** - Validate imports
8. **Optimizer** - Reduce gas costs
9. **Better diagnostics** - Improve developer experience
10. **Fuzzing** - Find edge cases

### Low Priority
11. **LSP support** - IDE integration
12. **Formatter** - Code style enforcement
13. **Package manager** - Dependency management
14. **Documentation generator** - Auto-generate docs

## Next Steps for Production Readiness

See `PRODUCTION_READINESS_REPORT.md` for detailed gap analysis and implementation plan.
