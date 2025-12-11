# Systems Quorlin Language Specification

**Version**: 1.0.0  
**Purpose**: Define the Quorlin language subset suitable for implementing the self-hosted compiler  
**Status**: Phase 1 - Foundation  
**Date**: 2025-12-11

---

## 1. Overview

**Systems Quorlin** is a subset and extension of the Quorlin smart contract language designed specifically for systems programming tasks like compiler implementation. It maintains Quorlin's Python-inspired syntax while adding features necessary for complex software development.

### Key Differences from Contract Quorlin

| Feature | Contract Quorlin | Systems Quorlin |
|---------|------------------|-----------------|
| **Primary Use** | Smart contracts | Compiler, tools, libraries |
| **Execution Model** | Blockchain VM | Native or bytecode VM |
| **Memory Model** | Persistent storage | Heap + stack |
| **I/O Operations** | None (deterministic) | File I/O, stdio |
| **Generic Types** | Limited | Full support |
| **Pattern Matching** | Basic | Advanced with guards |
| **Error Handling** | require/revert | Result/Option types |
| **Modules** | Single file | Multi-file projects |

---

## 2. Type System

### 2.1 Primitive Types

```quorlin
# Integers (same as contract Quorlin)
uint8, uint16, uint32, uint64, uint128, uint256
int8, int16, int32, int64, int128, int256

# Boolean
bool  # true, false

# Strings
str   # UTF-8 encoded strings

# Bytes
bytes  # Dynamic byte arrays
bytes32  # Fixed-size byte arrays

# Address (for compatibility)
address
```

### 2.2 Composite Types

#### Structs
```quorlin
struct SourceLocation:
    """Represents a location in source code."""
    file: str
    line: uint256
    column: uint256
    offset: uint256

struct Token:
    """A lexical token."""
    kind: TokenKind
    lexeme: str
    location: SourceLocation
```

#### Enums with Associated Data
```quorlin
enum TokenKind:
    """Token types with optional associated data."""
    Identifier
    IntLiteral(value: uint256)
    StringLiteral(value: str)
    Keyword(name: str)
    Operator(symbol: str)
    Indent(level: uint256)
    Dedent
    Newline
    EOF

enum Expr:
    """Expression AST nodes."""
    IntLit(value: uint256)
    StrLit(value: str)
    Ident(name: str)
    BinOp(left: Box[Expr], op: BinOp, right: Box[Expr])
    Call(func: Box[Expr], args: Vec[Expr])
    Attribute(obj: Box[Expr], attr: str)
```

#### Tuples
```quorlin
# Tuple types
let pair: (uint256, str) = (42, "hello")
let triple: (bool, uint256, address) = (true, 100, address(0))

# Tuple destructuring
let (x, y) = pair
let (flag, amount, owner) = triple
```

### 2.3 Generic Types

#### Generic Structs
```quorlin
struct Box[T]:
    """Heap-allocated value."""
    value: T

struct Pair[K, V]:
    """Key-value pair."""
    key: K
    value: V
```

#### Generic Enums
```quorlin
enum Option[T]:
    """Optional value."""
    Some(T)
    None

enum Result[T, E]:
    """Result of fallible operation."""
    Ok(T)
    Err(E)
```

#### Generic Contracts (Collections)
```quorlin
contract Vec[T]:
    """Dynamic array."""
    _items: list[T]
    _len: uint256
    _capacity: uint256
    
    @constructor
    fn __init__():
        self._items = []
        self._len = 0
        self._capacity = 0
    
    @external
    fn push(item: T):
        if self._len == self._capacity:
            self._grow()
        self._items[self._len] = item
        self._len = self._len + 1
    
    @external
    fn pop() -> Option[T]:
        if self._len == 0:
            return Option.None
        self._len = self._len - 1
        return Option.Some(self._items[self._len])
    
    @view
    fn get(index: uint256) -> Option[T]:
        if index >= self._len:
            return Option.None
        return Option.Some(self._items[index])
    
    @view
    fn len() -> uint256:
        return self._len
    
    @internal
    fn _grow():
        let new_capacity = if self._capacity == 0: 4 else: self._capacity * 2
        # Reallocate logic
        self._capacity = new_capacity

contract HashMap[K, V]:
    """Hash map implementation."""
    _buckets: list[list[Pair[K, V]]]
    _len: uint256
    
    @constructor
    fn __init__():
        self._buckets = []
        self._len = 0
        self._init_buckets(16)
    
    @external
    fn insert(key: K, value: V):
        let hash = self._hash(key)
        let bucket_idx = hash % len(self._buckets)
        
        # Check if key exists
        for i in range(len(self._buckets[bucket_idx])):
            if self._buckets[bucket_idx][i].key == key:
                self._buckets[bucket_idx][i].value = value
                return
        
        # Add new entry
        self._buckets[bucket_idx].push(Pair(key, value))
        self._len = self._len + 1
    
    @view
    fn get(key: K) -> Option[V]:
        let hash = self._hash(key)
        let bucket_idx = hash % len(self._buckets)
        
        for i in range(len(self._buckets[bucket_idx])):
            if self._buckets[bucket_idx][i].key == key:
                return Option.Some(self._buckets[bucket_idx][i].value)
        
        return Option.None
    
    @view
    fn contains(key: K) -> bool:
        return self.get(key).is_some()
    
    @internal
    fn _hash(key: K) -> uint256:
        # Hash function implementation
        pass
    
    @internal
    fn _init_buckets(size: uint256):
        for i in range(size):
            self._buckets.push([])
```

---

## 3. Pattern Matching

### 3.1 Match Expressions

```quorlin
fn process_token(token: Token) -> Result[ASTNode, ParseError]:
    """Process a token based on its kind."""
    match token.kind:
        TokenKind.Identifier:
            return Ok(ASTNode.Ident(token.lexeme))
        
        TokenKind.IntLiteral(value):
            return Ok(ASTNode.IntLit(value))
        
        TokenKind.StringLiteral(value):
            return Ok(ASTNode.StrLit(value))
        
        TokenKind.Keyword(kw):
            if kw == "fn":
                return self.parse_function()
            elif kw == "contract":
                return self.parse_contract()
            elif kw == "if":
                return self.parse_if_statement()
            else:
                return Err(ParseError.UnexpectedKeyword(kw))
        
        TokenKind.EOF:
            return Err(ParseError.UnexpectedEOF)
        
        _:
            return Err(ParseError.UnexpectedToken(token))
```

### 3.2 Option and Result Matching

```quorlin
fn safe_divide(a: uint256, b: uint256) -> Option[uint256]:
    if b == 0:
        return Option.None
    return Option.Some(a / b)

fn use_division():
    let result = safe_divide(10, 2)
    match result:
        Option.Some(value):
            print(f"Result: {value}")
        Option.None:
            print("Division by zero!")

fn parse_file(path: str) -> Result[AST, CompilerError]:
    let content = read_file(path)?  # Early return on error
    let tokens = tokenize(content)?
    let ast = parse(tokens)?
    return Ok(ast)
```

### 3.3 Guards in Pattern Matching

```quorlin
fn classify_number(n: int256) -> str:
    match n:
        x if x < 0:
            return "negative"
        0:
            return "zero"
        x if x > 0 and x <= 10:
            return "small positive"
        x if x > 10:
            return "large positive"
        _:
            return "unknown"
```

---

## 4. Error Handling

### 4.1 Result Type

```quorlin
enum Result[T, E]:
    Ok(T)
    Err(E)

# Result methods
impl Result[T, E]:
    fn is_ok() -> bool
    fn is_err() -> bool
    fn unwrap() -> T  # Panics if Err
    fn unwrap_or(default: T) -> T
    fn map[U](f: fn(T) -> U) -> Result[U, E]
    fn and_then[U](f: fn(T) -> Result[U, E]) -> Result[U, E]
```

### 4.2 Option Type

```quorlin
enum Option[T]:
    Some(T)
    None

# Option methods
impl Option[T]:
    fn is_some() -> bool
    fn is_none() -> bool
    fn unwrap() -> T  # Panics if None
    fn unwrap_or(default: T) -> T
    fn map[U](f: fn(T) -> U) -> Option[U]
    fn and_then[U](f: fn(T) -> Option[U]) -> Option[U]
```

### 4.3 Error Propagation

```quorlin
# The ? operator for early return
fn compile_file(path: str) -> Result[Output, CompilerError]:
    let source = read_file(path)?  # Returns Err if read_file fails
    let tokens = tokenize(source)?
    let ast = parse(tokens)?
    let checked_ast = type_check(ast)?
    let ir = generate_ir(checked_ast)?
    let output = codegen(ir)?
    return Ok(output)
```

---

## 5. File I/O and System Interaction

### 5.1 File Operations

```quorlin
# Read entire file
fn read_file(path: str) -> Result[str, IOError]:
    """Read entire file contents as string."""
    # Native implementation
    pass

# Write entire file
fn write_file(path: str, content: str) -> Result[(), IOError]:
    """Write string to file."""
    # Native implementation
    pass

# Read file as bytes
fn read_bytes(path: str) -> Result[bytes, IOError]:
    """Read file as byte array."""
    pass

# Write bytes to file
fn write_bytes(path: str, data: bytes) -> Result[(), IOError]:
    """Write bytes to file."""
    pass

# Check if file exists
fn file_exists(path: str) -> bool:
    """Check if file exists."""
    pass

# Get file metadata
struct FileMetadata:
    size: uint256
    modified: uint256  # Unix timestamp
    is_dir: bool

fn metadata(path: str) -> Result[FileMetadata, IOError]:
    """Get file metadata."""
    pass
```

### 5.2 Directory Operations

```quorlin
# List directory contents
fn read_dir(path: str) -> Result[Vec[str], IOError]:
    """List files in directory."""
    pass

# Create directory
fn create_dir(path: str) -> Result[(), IOError]:
    """Create directory."""
    pass

# Remove file
fn remove_file(path: str) -> Result[(), IOError]:
    """Delete file."""
    pass
```

### 5.3 Standard I/O

```quorlin
# Print to stdout
fn print(s: str):
    """Print string to stdout."""
    pass

fn println(s: str):
    """Print string with newline."""
    pass

# Read from stdin
fn read_line() -> Result[str, IOError]:
    """Read line from stdin."""
    pass

# Error output
fn eprint(s: str):
    """Print to stderr."""
    pass

fn eprintln(s: str):
    """Print to stderr with newline."""
    pass
```

### 5.4 Command Line Arguments

```quorlin
# Get command line arguments
fn args() -> Vec[str]:
    """Get command line arguments."""
    pass

# Environment variables
fn env(key: str) -> Option[str]:
    """Get environment variable."""
    pass

fn set_env(key: str, value: str):
    """Set environment variable."""
    pass
```

---

## 6. String Operations

### 6.1 String Methods

```quorlin
# String manipulation
fn len(s: str) -> uint256
fn is_empty(s: str) -> bool
fn contains(s: str, substr: str) -> bool
fn starts_with(s: str, prefix: str) -> bool
fn ends_with(s: str, suffix: str) -> bool

# String transformation
fn to_lowercase(s: str) -> str
fn to_uppercase(s: str) -> str
fn trim(s: str) -> str
fn trim_start(s: str) -> str
fn trim_end(s: str) -> str

# String splitting and joining
fn split(s: str, delimiter: str) -> Vec[str]
fn split_lines(s: str) -> Vec[str]
fn join(parts: Vec[str], separator: str) -> str

# String slicing
fn substring(s: str, start: uint256, end: uint256) -> str
fn char_at(s: str, index: uint256) -> Option[str]

# String formatting
fn format(template: str, args: Vec[str]) -> str

# Example usage
let name = "Alice"
let age = 30
let message = format("Hello, {}! You are {} years old.", [name, str(age)])
# Result: "Hello, Alice! You are 30 years old."
```

### 6.2 String Interpolation

```quorlin
# F-string style interpolation
let name = "Bob"
let count = 42
let msg = f"User {name} has {count} items"
# Result: "User Bob has 42 items"

# Multi-line strings
let code = """
contract Counter:
    count: uint256
    
    fn increment():
        self.count = self.count + 1
"""
```

---

## 7. Module System

### 7.1 Module Declaration

```quorlin
# File: compiler/frontend/lexer.ql
module compiler.frontend.lexer

from compiler.frontend.ast import Token, TokenKind
from compiler.common.error import CompilerError
from std.collections import Vec

contract Lexer:
    # Implementation
    pass
```

### 7.2 Import Statements

```quorlin
# Import specific items
from std.collections import Vec, HashMap
from compiler.frontend.ast import Token, Expr, Stmt

# Import entire module
import compiler.frontend.parser
import std.io

# Use imported items
let tokens = Vec[Token]()
let ast = compiler.frontend.parser.parse(tokens)
std.io.println("Parsing complete")

# Import with alias
from compiler.frontend.parser import Parser as SyntaxParser
let parser = SyntaxParser()
```

### 7.3 Module Visibility

```quorlin
# Public items (exported)
@public
contract Lexer:
    pass

@public
fn tokenize(source: str) -> Vec[Token]:
    pass

# Private items (module-only)
@private
fn is_whitespace(ch: str) -> bool:
    pass

# Internal items (package-only)
@internal
struct TokenizerState:
    pass
```

---

## 8. Memory Management

### 8.1 Ownership and Borrowing

```quorlin
# Move semantics (default)
let s1 = "hello"
let s2 = s1  # s1 is moved to s2, s1 is no longer valid

# Borrowing (references)
fn print_string(s: &str):
    """Borrow string without taking ownership."""
    println(s)

let message = "Hello, world!"
print_string(&message)  # Borrow
println(message)  # Still valid

# Mutable borrowing
fn append_exclamation(s: &mut str):
    """Mutably borrow string."""
    s.push_str("!")

let mut greeting = "Hello"
append_exclamation(&mut greeting)
println(greeting)  # "Hello!"
```

### 8.2 Box Type (Heap Allocation)

```quorlin
# Heap allocation for recursive types
enum Expr:
    IntLit(uint256)
    BinOp(Box[Expr], BinOp, Box[Expr])  # Box prevents infinite size

# Create boxed value
let left = Box.new(Expr.IntLit(10))
let right = Box.new(Expr.IntLit(20))
let expr = Expr.BinOp(left, BinOp.Add, right)

# Dereference box
let value = *boxed_value
```

---

## 9. Traits and Implementations

### 9.1 Trait Definition

```quorlin
trait Display:
    """Trait for types that can be displayed as strings."""
    fn to_string() -> str

trait Clone:
    """Trait for types that can be cloned."""
    fn clone() -> Self

trait Iterator[T]:
    """Trait for iterators."""
    fn next() -> Option[T]
    fn has_next() -> bool
```

### 9.2 Trait Implementation

```quorlin
struct Token:
    kind: TokenKind
    lexeme: str
    location: SourceLocation

impl Display for Token:
    fn to_string() -> str:
        return f"Token({self.kind}, '{self.lexeme}')"

impl Clone for Token:
    fn clone() -> Token:
        return Token(
            kind: self.kind.clone(),
            lexeme: self.lexeme.clone(),
            location: self.location.clone()
        )
```

### 9.3 Generic Trait Implementations

```quorlin
impl[T] Display for Vec[T] where T: Display:
    fn to_string() -> str:
        let parts = Vec[str]()
        for item in self:
            parts.push(item.to_string())
        return "[" + join(parts, ", ") + "]"
```

---

## 10. Advanced Features

### 10.1 Closures

```quorlin
# Simple closure
let add_one = |x: uint256| -> uint256 { x + 1 }
let result = add_one(5)  # 6

# Closure capturing environment
let multiplier = 10
let multiply = |x: uint256| -> uint256 { x * multiplier }
let result = multiply(5)  # 50

# Higher-order functions
fn map[T, U](items: Vec[T], f: fn(T) -> U) -> Vec[U]:
    let result = Vec[U]()
    for item in items:
        result.push(f(item))
    return result

let numbers = vec![1, 2, 3, 4, 5]
let doubled = map(numbers, |x| x * 2)  # [2, 4, 6, 8, 10]
```

### 10.2 Macros (Future)

```quorlin
# Declarative macros
macro vec:
    ($($x:expr),*) => {
        {
            let mut temp_vec = Vec::new()
            $(temp_vec.push($x);)*
            temp_vec
        }
    }

# Usage
let v = vec![1, 2, 3, 4, 5]
```

---

## 11. Compiler-Specific Constructs

### 11.1 Unsafe Blocks

```quorlin
# For low-level operations
unsafe:
    # Direct memory access
    let ptr = raw_pointer(address)
    let value = *ptr
    
    # Unchecked arithmetic
    let result = unchecked_add(a, b)
```

### 11.2 Inline Assembly (Future)

```quorlin
# For performance-critical code
fn fast_hash(data: bytes) -> uint256:
    let result: uint256
    asm:
        # Assembly code here
        result = keccak256(data)
    return result
```

---

## 12. Standard Library for Compiler

### 12.1 Collections

```quorlin
from std.collections import Vec, HashMap, HashSet, LinkedList, BTreeMap
```

### 12.2 I/O

```quorlin
from std.io import (
    read_file, write_file, read_bytes, write_bytes,
    print, println, eprint, eprintln,
    read_line, read_dir, file_exists
)
```

### 12.3 String Operations

```quorlin
from std.string import (
    split, join, trim, to_lowercase, to_uppercase,
    format, substring, contains, starts_with, ends_with
)
```

### 12.4 Error Types

```quorlin
from std.error import (
    Result, Option, IOError, ParseError, CompilerError
)
```

### 12.5 Path Operations

```quorlin
from std.path import Path

let path = Path.new("/home/user/project/src/main.ql")
let filename = path.filename()  # "main.ql"
let extension = path.extension()  # "ql"
let parent = path.parent()  # "/home/user/project/src"
let absolute = path.absolute()
```

---

## 13. Differences from Contract Quorlin

### Features REMOVED in Systems Quorlin:
- `msg.sender`, `msg.value` (blockchain-specific)
- `block.timestamp`, `block.number`
- `emit` statements (events)
- `mapping` type (use HashMap instead)
- `@payable`, `@view` decorators (use different semantics)
- Gas-related constructs

### Features ADDED in Systems Quorlin:
- File I/O operations
- Generic types with full support
- Pattern matching with guards
- Result/Option error handling
- Module system
- Traits and implementations
- Closures
- Heap allocation (Box)
- Ownership and borrowing
- Standard I/O
- Command-line argument parsing

---

## 14. Example: Lexer Implementation

```quorlin
module compiler.frontend.lexer

from std.collections import Vec
from std.string import split_lines, trim, char_at
from compiler.frontend.ast import Token, TokenKind, SourceLocation
from compiler.common.error import Result, CompilerError

contract Lexer:
    """Tokenizes Quorlin source code."""
    
    source: str
    position: uint256
    line: uint256
    column: uint256
    indent_stack: Vec[uint256]
    
    @constructor
    fn __init__(source: str):
        self.source = source
        self.position = 0
        self.line = 1
        self.column = 1
        self.indent_stack = Vec[uint256]()
        self.indent_stack.push(0)
    
    @external
    fn tokenize() -> Result[Vec[Token], CompilerError]:
        """Tokenize the entire source."""
        let tokens = Vec[Token]()
        
        while not self.is_at_end():
            let token = self.next_token()?
            tokens.push(token)
        
        # Add EOF token
        tokens.push(Token(
            kind: TokenKind.EOF,
            lexeme: "",
            location: self.current_location()
        ))
        
        return Ok(tokens)
    
    @internal
    fn next_token() -> Result[Token, CompilerError]:
        """Get the next token."""
        self.skip_whitespace()
        
        if self.is_at_end():
            return Ok(self.make_token(TokenKind.EOF, ""))
        
        let ch = self.current_char()
        
        # Handle different token types
        if ch.is_digit():
            return self.tokenize_number()
        elif ch.is_alpha() or ch == "_":
            return self.tokenize_identifier()
        elif ch == '"' or ch == "'":
            return self.tokenize_string()
        elif ch == "#":
            self.skip_comment()
            return self.next_token()
        else:
            return self.tokenize_operator()
    
    @internal
    fn tokenize_number() -> Result[Token, CompilerError]:
        """Tokenize a number literal."""
        let start = self.position
        
        while not self.is_at_end() and self.current_char().is_digit():
            self.advance()
        
        let lexeme = self.source[start:self.position]
        let value = parse_uint(lexeme)?
        
        return Ok(self.make_token(
            TokenKind.IntLiteral(value),
            lexeme
        ))
    
    @internal
    fn tokenize_identifier() -> Result[Token, CompilerError]:
        """Tokenize an identifier or keyword."""
        let start = self.position
        
        while not self.is_at_end():
            let ch = self.current_char()
            if not (ch.is_alphanumeric() or ch == "_"):
                break
            self.advance()
        
        let lexeme = self.source[start:self.position]
        let kind = self.keyword_or_identifier(lexeme)
        
        return Ok(self.make_token(kind, lexeme))
    
    @internal
    fn keyword_or_identifier(lexeme: str) -> TokenKind:
        """Check if lexeme is a keyword."""
        match lexeme:
            "fn": return TokenKind.Keyword("fn")
            "contract": return TokenKind.Keyword("contract")
            "if": return TokenKind.Keyword("if")
            "elif": return TokenKind.Keyword("elif")
            "else": return TokenKind.Keyword("else")
            "while": return TokenKind.Keyword("while")
            "for": return TokenKind.Keyword("for")
            "return": return TokenKind.Keyword("return")
            "let": return TokenKind.Keyword("let")
            "mut": return TokenKind.Keyword("mut")
            _: return TokenKind.Identifier
    
    @internal
    fn current_char() -> str:
        """Get current character."""
        return char_at(self.source, self.position).unwrap_or("")
    
    @internal
    fn advance() -> str:
        """Advance position and return current character."""
        let ch = self.current_char()
        self.position = self.position + 1
        self.column = self.column + 1
        if ch == "\n":
            self.line = self.line + 1
            self.column = 1
        return ch
    
    @internal
    fn is_at_end() -> bool:
        """Check if at end of source."""
        return self.position >= len(self.source)
    
    @internal
    fn skip_whitespace():
        """Skip whitespace characters."""
        while not self.is_at_end():
            let ch = self.current_char()
            if ch == " " or ch == "\t" or ch == "\r":
                self.advance()
            else:
                break
    
    @internal
    fn skip_comment():
        """Skip comment line."""
        while not self.is_at_end() and self.current_char() != "\n":
            self.advance()
    
    @internal
    fn current_location() -> SourceLocation:
        """Get current source location."""
        return SourceLocation(
            file: "",  # Set by caller
            line: self.line,
            column: self.column,
            offset: self.position
        )
    
    @internal
    fn make_token(kind: TokenKind, lexeme: str) -> Token:
        """Create a token."""
        return Token(
            kind: kind,
            lexeme: lexeme,
            location: self.current_location()
        )
```

---

## 15. Compatibility Matrix

| Feature | Contract Quorlin | Systems Quorlin | Notes |
|---------|------------------|-----------------|-------|
| Basic types | ✅ | ✅ | Same |
| Structs | ✅ | ✅ | Same |
| Enums | ✅ | ✅ | Systems adds associated data |
| Generics | ⚠️ Limited | ✅ Full | Systems has full generic support |
| Pattern matching | ❌ | ✅ | New in Systems |
| File I/O | ❌ | ✅ | New in Systems |
| Mappings | ✅ | ❌ | Use HashMap in Systems |
| Events | ✅ | ❌ | Blockchain-specific |
| msg.sender | ✅ | ❌ | Blockchain-specific |
| Modules | ⚠️ Single file | ✅ Multi-file | Enhanced in Systems |
| Traits | ❌ | ✅ | New in Systems |
| Closures | ❌ | ✅ | New in Systems |

---

## 16. Migration Guide

### Converting Contract Quorlin to Systems Quorlin

**Before (Contract):**
```quorlin
contract Counter:
    count: uint256
    owner: address
    
    @constructor
    fn __init__():
        self.count = 0
        self.owner = msg.sender
    
    @external
    fn increment():
        require(msg.sender == self.owner, "Not owner")
        self.count = self.count + 1
```

**After (Systems):**
```quorlin
contract Counter:
    count: uint256
    owner: str  # Use string for owner identifier
    
    @constructor
    fn __init__(owner: str):
        self.count = 0
        self.owner = owner
    
    @external
    fn increment(caller: str) -> Result[(), str]:
        if caller != self.owner:
            return Err("Not owner")
        self.count = self.count + 1
        return Ok(())
```

---

## 17. Future Extensions

### Planned Features:
- [ ] Async/await for concurrent operations
- [ ] Procedural macros
- [ ] Inline assembly
- [ ] SIMD operations
- [ ] Foreign function interface (FFI)
- [ ] Reflection and metaprogramming
- [ ] Custom allocators

---

**Status**: Phase 1 - Foundation  
**Next**: IR Specification  
**Last Updated**: 2025-12-11
