# Quorlin Examples & Tutorials

This directory contains example Quorlin smart contracts to help you learn the language.

## ⚠️ Note on Tutorial Examples

The tutorial examples (01-06) are educational resources showing Quorlin syntax and features.
**For working, compilable examples, see token.ql** which is a complete, production-ready ERC-20 token.

The tutorial examples use some features (like `let` bindings and simple state variable assignment in constructors)
that are planned for future releases but not yet fully implemented in all backends.

## 📚 Tutorial Examples (Start Here!)

Learn Quorlin step-by-step with these annotated examples:

### 1. [Hello World](01_hello_world.ql)
**Your first Quorlin contract**
- Basic contract structure
- Constructor pattern
- View functions (read-only)
- Events and emit statements
- String storage

### 2. [Variables](02_variables.ql)
**Working with variables and types**
- Different data types (uint256, int256, bool, address, string, bytes)
- State variables vs local variables
- Type annotations
- Special variables (msg.sender, msg.value, block.timestamp)
- Variable assignments and updates

### 3. [Arithmetic](03_arithmetic.ql)
**Arithmetic operations and overflow protection**
- Basic operations (+, -, *, /, %)
- Safe arithmetic (built-in overflow protection)
- Comparison operations (==, !=, <, >, <=, >=)
- Order of operations
- Compound assignments (+=, -=, *=, /=)

### 4. [Functions](04_functions.ql)
**Functions, parameters, and return values**
- Function definitions with `fn` keyword
- Function parameters and return types
- Decorators (@external, @view, @constructor)
- Public vs internal functions
- Function calls and validation
- Require statements

### 5. [Control Flow](05_control_flow.ql)
**Conditional logic and loops**
- if/elif/else statements
- Boolean logic (and, or, not)
- for loops with range()
- while loops
- Input validation with require
- Practical examples (factorial, prime numbers)

### 6. [Data Structures](06_data_structures.ql)
**Working with complex data structures**
- Mappings (key-value stores)
- Nested mappings
- Accessing and updating mappings
- Practical example: Token-like system with balances and allowances

## 🚀 Production Examples

Complete, production-ready smart contracts:

### [Token](token.ql)
**Full ERC-20 compatible token**
- Complete fungible token implementation
- Compatible with ERC-20 (EVM), SPL (Solana), and PSP22 (Polkadot)
- Transfer, approve, and allowance functionality
- Events and error handling
- Security best practices

## 📖 How to Use These Examples

### 1. **Read the code**
Each example is heavily commented. Start with the tutorial examples in order (01-06).

### 2. **Compile an example**
```bash
# Compile for EVM (Ethereum)
qlc compile examples/01_hello_world.ql --target evm -o output.yul

# Compile for Solana
qlc compile examples/01_hello_world.ql --target solana -o output.rs

# Compile for Polkadot (ink!)
qlc compile examples/01_hello_world.ql --target ink -o output.rs
```

### 3. **Understand the output**
Each example includes "Expected behavior" comments showing what should happen when you call the functions.

### 4. **Experiment**
Try modifying the examples to learn more:
- Change parameters and see what happens
- Add new functions
- Combine features from different examples

## 🎯 Learning Path

**Beginner** (Start here!)
1. Hello World - Understand basic structure
2. Variables - Learn about types
3. Arithmetic - Practice with numbers and operators

**Intermediate**
4. Functions - Write reusable code
5. Control Flow - Add logic to your contracts
6. Data Structures - Store and organize data

**Advanced**
- Token - Study a complete production contract
- Build your own smart contracts!

## 💡 Key Concepts

### Decorators
- `@constructor` - Runs once when contract is deployed
- `@external` - Can be called from outside (costs gas)
- `@view` - Read-only, doesn't modify state (free to call)

### Safety Features
- **Checked arithmetic** - All operations automatically check for overflow/underflow
- **Type safety** - Strong typing prevents bugs
- **Require statements** - Validate inputs and revert on errors

### Multi-Chain
Every Quorlin contract compiles to three blockchains:
- **EVM** (Ethereum, Polygon, BSC, etc.)
- **Solana** (via Anchor)
- **Polkadot** (via ink!)

## 📚 Additional Resources

- [Language Reference](../docs/Language_Reference.md) - Complete syntax guide
- [Standard Library](../docs/Standard_Library.md) - Built-in functions
- [Production Readiness](../docs/PRODUCTION_READINESS_REPORT.md) - Best practices
- [Security Guide](../docs/SECURITY_AUDIT_PREP.md) - Write secure contracts

## 🤝 Need Help?

- Read the comments in each example carefully
- Check the "Expected behavior" section at the bottom of each file
- Review the Language Reference for syntax details
- Look at token.ql for a complete, real-world example

Happy coding! 🎉
