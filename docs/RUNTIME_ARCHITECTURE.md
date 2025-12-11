# Quorlin Runtime Architecture

**Version**: 1.0.0  
**Purpose**: Define the runtime system for the self-hosted Quorlin compiler  
**Status**: Phase 1 - Foundation  
**Date**: 2025-12-11

---

## 1. Executive Summary

The **Quorlin Runtime** is the execution environment for the self-hosted compiler. It provides:

1. **Bytecode VM** (primary approach) - Portable, flexible, meta-programmable
2. **Standard Library** - Collections, I/O, string operations
3. **Memory Management** - Garbage collection or reference counting
4. **FFI Layer** - Interface with host system (file I/O, etc.)

### Decision: Bytecode VM Approach

**Rationale:**
- ✅ Maximum portability (works on any platform)
- ✅ Enables meta-programming (compiler can introspect itself)
- ✅ Easier debugging and profiling
- ✅ Simpler bootstrap process
- ✅ Can JIT-compile hot paths later
- ⚠️ Slightly slower than native (acceptable for compiler)

---

## 2. Architecture Overview

```
┌──────────────────────────────────────────────────────────────┐
│                    Quorlin Compiler (Self-Hosted)             │
│                    Written in Quorlin (.ql files)             │
└────────────────────────┬─────────────────────────────────────┘
                         │
                         ▼
┌──────────────────────────────────────────────────────────────┐
│                  Quorlin Bytecode (.qbc)                      │
│          Portable intermediate format                         │
└────────────────────────┬─────────────────────────────────────┘
                         │
                         ▼
┌──────────────────────────────────────────────────────────────┐
│                  Quorlin Virtual Machine                      │
│  ┌────────────┬────────────┬────────────┬────────────┐       │
│  │  Bytecode  │   Memory   │  Garbage   │    FFI     │       │
│  │ Interpreter│  Manager   │ Collector  │   Layer    │       │
│  └────────────┴────────────┴────────────┴────────────┘       │
└────────────────────────┬─────────────────────────────────────┘
                         │
                         ▼
┌──────────────────────────────────────────────────────────────┐
│                    Host Operating System                      │
│              (Windows, Linux, macOS)                          │
└──────────────────────────────────────────────────────────────┘
```

---

## 3. Bytecode Format

### 3.1 Instruction Set Architecture

**Design**: Stack-based VM (simpler than register-based)

```quorlin
enum Opcode:
    """Bytecode opcodes."""
    
    # Stack manipulation
    PUSH_CONST(const_id: uint32)  # Push constant from pool
    POP                            # Pop top of stack
    DUP                            # Duplicate top of stack
    SWAP                           # Swap top two values
    
    # Local variables
    LOAD_LOCAL(index: uint32)      # Load local variable
    STORE_LOCAL(index: uint32)     # Store to local variable
    
    # Global variables
    LOAD_GLOBAL(name_id: uint32)   # Load global variable
    STORE_GLOBAL(name_id: uint32)  # Store to global variable
    
    # Arithmetic
    ADD                            # Pop two, push sum
    SUB                            # Pop two, push difference
    MUL                            # Pop two, push product
    DIV                            # Pop two, push quotient
    MOD                            # Pop two, push remainder
    POW                            # Pop two, push power
    NEG                            # Negate top of stack
    
    # Comparison
    EQ                             # Equal
    NE                             # Not equal
    LT                             # Less than
    LE                             # Less than or equal
    GT                             # Greater than
    GE                             # Greater than or equal
    
    # Logical
    AND                            # Logical AND
    OR                             # Logical OR
    NOT                            # Logical NOT
    
    # Control flow
    JUMP(offset: int32)            # Unconditional jump
    JUMP_IF_FALSE(offset: int32)   # Jump if top is false
    JUMP_IF_TRUE(offset: int32)    # Jump if top is true
    CALL(num_args: uint32)         # Call function
    RETURN                         # Return from function
    
    # Object operations
    NEW_STRUCT(type_id: uint32)    # Create struct instance
    GET_FIELD(field_id: uint32)    # Get struct field
    SET_FIELD(field_id: uint32)    # Set struct field
    
    # Array operations
    NEW_ARRAY(size: uint32)        # Create array
    ARRAY_GET                      # Get array element
    ARRAY_SET                      # Set array element
    ARRAY_LEN                      # Get array length
    
    # String operations
    CONCAT                         # Concatenate strings
    STRING_LEN                     # String length
    SUBSTRING                      # Extract substring
    
    # Type operations
    CAST(type_id: uint32)          # Type cast
    INSTANCEOF(type_id: uint32)    # Type check
    
    # FFI calls
    FFI_CALL(ffi_id: uint32, num_args: uint32)  # Call native function
    
    # Debug
    PRINT                          # Print top of stack
    DEBUG_BREAK                    # Debugger breakpoint
```

### 3.2 Bytecode File Format

```
Quorlin Bytecode File (.qbc):

┌─────────────────────────────────────────────────────────┐
│ Header                                                   │
├─────────────────────────────────────────────────────────┤
│ Magic Number: "QBC\0" (4 bytes)                         │
│ Version: uint32 (4 bytes)                               │
│ Flags: uint32 (4 bytes)                                 │
│   - Bit 0: Debug info present                           │
│   - Bit 1: Optimized                                    │
│   - Bit 2-31: Reserved                                  │
├─────────────────────────────────────────────────────────┤
│ Constant Pool                                            │
├─────────────────────────────────────────────────────────┤
│ Num Constants: uint32                                    │
│ Constants: [Constant]*                                   │
│   - Type tag: uint8                                      │
│     0x01 = Integer                                       │
│     0x02 = Float                                         │
│     0x03 = String                                        │
│     0x04 = Boolean                                       │
│     0x05 = Null                                          │
│   - Data: varies by type                                 │
├─────────────────────────────────────────────────────────┤
│ String Table                                             │
├─────────────────────────────────────────────────────────┤
│ Num Strings: uint32                                      │
│ Strings: [String]*                                       │
│   - Length: uint32                                       │
│   - UTF-8 Data: [byte]*                                  │
├─────────────────────────────────────────────────────────┤
│ Type Table                                               │
├─────────────────────────────────────────────────────────┤
│ Num Types: uint32                                        │
│ Types: [TypeDescriptor]*                                 │
├─────────────────────────────────────────────────────────┤
│ Function Table                                           │
├─────────────────────────────────────────────────────────┤
│ Num Functions: uint32                                    │
│ Functions: [Function]*                                   │
│   - Name ID: uint32 (index into string table)           │
│   - Num Params: uint32                                   │
│   - Num Locals: uint32                                   │
│   - Code Size: uint32                                    │
│   - Bytecode: [byte]*                                    │
│   - Exception Table: [ExceptionHandler]*                 │
├─────────────────────────────────────────────────────────┤
│ Debug Info (optional)                                    │
├─────────────────────────────────────────────────────────┤
│ Source File Mapping                                      │
│ Line Number Table                                        │
│ Local Variable Names                                     │
└─────────────────────────────────────────────────────────┘
```

---

## 4. Virtual Machine Implementation

### 4.1 VM State

```quorlin
contract QuorlinVM:
    """Quorlin bytecode virtual machine."""
    
    # Execution state
    stack: Vec[Value]              # Operand stack
    call_stack: Vec[CallFrame]     # Call frames
    globals: HashMap[str, Value]   # Global variables
    
    # Bytecode
    bytecode: bytes                # Current bytecode
    ip: uint256                    # Instruction pointer
    
    # Memory management
    heap: Heap                     # Heap allocator
    gc: GarbageCollector           # GC instance
    
    # Constant pools
    constants: Vec[Value]          # Constant pool
    strings: Vec[str]              # String table
    types: Vec[TypeDescriptor]     # Type table
    functions: Vec[Function]       # Function table
    
    # FFI
    ffi_registry: HashMap[str, FFIFunction]
    
    # Debug
    debug_mode: bool
    breakpoints: Vec[uint256]

struct CallFrame:
    """Function call frame."""
    function_id: uint256
    return_address: uint256
    locals: Vec[Value]
    base_pointer: uint256  # Stack base pointer

struct Value:
    """Runtime value."""
    ty: ValueType
    data: ValueData

enum ValueType:
    Null
    Bool
    Int
    Float
    String
    Array
    Struct
    Function
    NativePointer

union ValueData:
    bool_val: bool
    int_val: uint256
    float_val: float64
    string_val: str
    array_val: Array
    struct_val: Struct
    function_val: FunctionRef
    native_ptr: uint256
```

### 4.2 Execution Loop

```quorlin
impl QuorlinVM:
    @external
    fn execute() -> Result[Value, VMError]:
        """Main execution loop."""
        while self.ip < len(self.bytecode):
            let opcode = self.fetch_opcode()
            
            match opcode:
                Opcode.PUSH_CONST(const_id):
                    let value = self.constants[const_id]
                    self.stack.push(value)
                
                Opcode.POP:
                    self.stack.pop()?
                
                Opcode.ADD:
                    let b = self.stack.pop()?
                    let a = self.stack.pop()?
                    self.stack.push(self.add(a, b)?)
                
                Opcode.CALL(num_args):
                    self.call_function(num_args)?
                
                Opcode.RETURN:
                    return self.return_from_function()
                
                Opcode.JUMP(offset):
                    self.ip = (self.ip as int256 + offset) as uint256
                
                Opcode.JUMP_IF_FALSE(offset):
                    let condition = self.stack.pop()?
                    if not condition.as_bool():
                        self.ip = (self.ip as int256 + offset) as uint256
                
                # ... handle all other opcodes
                
                _:
                    return Err(VMError.UnknownOpcode(opcode))
        
        return Ok(Value.Null)
    
    @internal
    fn fetch_opcode() -> Opcode:
        """Fetch next opcode and advance IP."""
        let opcode_byte = self.bytecode[self.ip]
        self.ip = self.ip + 1
        return Opcode.from_byte(opcode_byte)
    
    @internal
    fn call_function(num_args: uint256) -> Result[(), VMError]:
        """Call a function."""
        let func_value = self.stack.pop()?
        
        match func_value.ty:
            ValueType.Function:
                let func_ref = func_value.data.function_val
                let function = self.functions[func_ref.id]
                
                # Create call frame
                let frame = CallFrame(
                    function_id: func_ref.id,
                    return_address: self.ip,
                    locals: Vec[Value](),
                    base_pointer: len(self.stack) - num_args
                )
                
                # Initialize locals with arguments
                for i in range(num_args):
                    frame.locals.push(self.stack.pop()?)
                
                self.call_stack.push(frame)
                
                # Jump to function code
                self.ip = function.code_offset
                
                return Ok(())
            
            _:
                return Err(VMError.NotCallable)
    
    @internal
    fn return_from_function() -> Result[Value, VMError]:
        """Return from current function."""
        let frame = self.call_stack.pop()?
        
        # Get return value (top of stack)
        let return_value = if len(self.stack) > frame.base_pointer:
            self.stack.pop()?
        else:
            Value.Null
        
        # Restore stack
        while len(self.stack) > frame.base_pointer:
            self.stack.pop()?
        
        # Restore IP
        self.ip = frame.return_address
        
        # Push return value
        self.stack.push(return_value)
        
        return Ok(return_value)
    
    @internal
    fn add(a: Value, b: Value) -> Result[Value, VMError]:
        """Add two values."""
        match (a.ty, b.ty):
            (ValueType.Int, ValueType.Int):
                return Ok(Value(
                    ty: ValueType.Int,
                    data: ValueData(int_val: a.data.int_val + b.data.int_val)
                ))
            
            (ValueType.String, ValueType.String):
                return Ok(Value(
                    ty: ValueType.String,
                    data: ValueData(string_val: a.data.string_val + b.data.string_val)
                ))
            
            _:
                return Err(VMError.TypeError("Cannot add these types"))
```

---

## 5. Memory Management

### 5.1 Heap Allocator

```quorlin
contract Heap:
    """Heap memory allocator."""
    
    memory: bytes
    free_list: Vec[FreeBlock]
    allocated: HashMap[uint256, AllocationInfo]
    
    @constructor
    fn __init__(size: uint256):
        self.memory = bytes(size)
        self.free_list = Vec[FreeBlock]()
        self.free_list.push(FreeBlock(offset: 0, size: size))
        self.allocated = HashMap[uint256, AllocationInfo]()
    
    @external
    fn allocate(size: uint256) -> Result[uint256, HeapError]:
        """Allocate memory block."""
        # Find suitable free block
        for i in range(len(self.free_list)):
            let block = self.free_list[i]
            if block.size >= size:
                # Allocate from this block
                let offset = block.offset
                
                # Update free list
                if block.size > size:
                    self.free_list[i].offset = offset + size
                    self.free_list[i].size = block.size - size
                else:
                    self.free_list.remove(i)
                
                # Track allocation
                self.allocated.insert(offset, AllocationInfo(
                    size: size,
                    marked: false
                ))
                
                return Ok(offset)
        
        return Err(HeapError.OutOfMemory)
    
    @external
    fn deallocate(offset: uint256):
        """Free memory block."""
        let info = self.allocated.get(offset)?
        self.allocated.remove(offset)
        
        # Add to free list
        self.free_list.push(FreeBlock(offset: offset, size: info.size))
        
        # Coalesce adjacent free blocks
        self.coalesce_free_blocks()
    
    @internal
    fn coalesce_free_blocks():
        """Merge adjacent free blocks."""
        # Sort free list by offset
        self.free_list.sort_by(|a, b| a.offset < b.offset)
        
        # Merge adjacent blocks
        let i = 0
        while i < len(self.free_list) - 1:
            let current = self.free_list[i]
            let next = self.free_list[i + 1]
            
            if current.offset + current.size == next.offset:
                # Merge blocks
                self.free_list[i].size = current.size + next.size
                self.free_list.remove(i + 1)
            else:
                i = i + 1

struct FreeBlock:
    offset: uint256
    size: uint256

struct AllocationInfo:
    size: uint256
    marked: bool  # For GC mark phase
```

### 5.2 Garbage Collector

```quorlin
contract GarbageCollector:
    """Mark-and-sweep garbage collector."""
    
    heap: Heap
    vm: QuorlinVM
    
    @external
    fn collect():
        """Run garbage collection."""
        # Mark phase
        self.mark_phase()
        
        # Sweep phase
        self.sweep_phase()
    
    @internal
    fn mark_phase():
        """Mark all reachable objects."""
        # Mark from stack
        for value in self.vm.stack:
            self.mark_value(value)
        
        # Mark from call frames
        for frame in self.vm.call_stack:
            for local in frame.locals:
                self.mark_value(local)
        
        # Mark from globals
        for (name, value) in self.vm.globals:
            self.mark_value(value)
    
    @internal
    fn mark_value(value: Value):
        """Mark a value and its children."""
        match value.ty:
            ValueType.Array:
                let array = value.data.array_val
                if not array.marked:
                    array.marked = true
                    for element in array.elements:
                        self.mark_value(element)
            
            ValueType.Struct:
                let struct_val = value.data.struct_val
                if not struct_val.marked:
                    struct_val.marked = true
                    for (field, field_value) in struct_val.fields:
                        self.mark_value(field_value)
            
            _:
                # Primitive types don't need marking
                pass
    
    @internal
    fn sweep_phase():
        """Sweep unmarked objects."""
        let to_free = Vec[uint256]()
        
        for (offset, info) in self.heap.allocated:
            if not info.marked:
                to_free.push(offset)
            else:
                # Unmark for next collection
                info.marked = false
        
        # Free unmarked objects
        for offset in to_free:
            self.heap.deallocate(offset)
```

---

## 6. Foreign Function Interface (FFI)

### 6.1 FFI Layer

```quorlin
contract FFIRegistry:
    """Registry for native functions."""
    
    functions: HashMap[str, FFIFunction]
    
    @external
    fn register(name: str, func: FFIFunction):
        """Register a native function."""
        self.functions.insert(name, func)
    
    @external
    fn call(name: str, args: Vec[Value]) -> Result[Value, FFIError]:
        """Call a native function."""
        let func = self.functions.get(name)?
        return func.call(args)

trait FFIFunction:
    """Native function interface."""
    fn call(args: Vec[Value]) -> Result[Value, FFIError]

# Example FFI implementations
contract FileReadFFI:
    """FFI for reading files."""
    
    @external
    fn call(args: Vec[Value]) -> Result[Value, FFIError]:
        if len(args) != 1:
            return Err(FFIError.WrongNumArgs)
        
        let path = args[0].as_string()?
        
        # Call native file read
        let content = native_read_file(path)?
        
        return Ok(Value.String(content))

contract FilePrintFFI:
    """FFI for printing to stdout."""
    
    @external
    fn call(args: Vec[Value]) -> Result[Value, FFIError]:
        for arg in args:
            let s = arg.to_string()
            native_print(s)
        
        return Ok(Value.Null)
```

### 6.2 Native Bindings

```rust
// Native implementation (in Rust for bootstrap)
// This will be the minimal Rust code needed

#[no_mangle]
pub extern "C" fn native_read_file(path: *const u8, path_len: usize) -> *const u8 {
    let path_str = unsafe {
        std::str::from_utf8_unchecked(std::slice::from_raw_parts(path, path_len))
    };
    
    match std::fs::read_to_string(path_str) {
        Ok(content) => {
            let bytes = content.into_bytes();
            let ptr = bytes.as_ptr();
            std::mem::forget(bytes);
            ptr
        }
        Err(_) => std::ptr::null()
    }
}

#[no_mangle]
pub extern "C" fn native_print(data: *const u8, len: usize) {
    let s = unsafe {
        std::str::from_utf8_unchecked(std::slice::from_raw_parts(data, len))
    };
    print!("{}", s);
}
```

---

## 7. Standard Library for Compiler

### 7.1 Collections

```quorlin
# Implemented in Quorlin, compiled to bytecode

contract Vec[T]:
    """Dynamic array."""
    _data: Array[T]
    _len: uint256
    _capacity: uint256
    
    # Implementation as shown in LANGUAGE_SUBSET.md

contract HashMap[K, V]:
    """Hash map."""
    # Implementation as shown in LANGUAGE_SUBSET.md
```

### 7.2 I/O Operations

```quorlin
# Thin wrappers around FFI

fn read_file(path: str) -> Result[str, IOError]:
    """Read file contents."""
    return ffi_call("read_file", [Value.String(path)])

fn write_file(path: str, content: str) -> Result[(), IOError]:
    """Write file contents."""
    return ffi_call("write_file", [Value.String(path), Value.String(content)])

fn print(s: str):
    """Print to stdout."""
    ffi_call("print", [Value.String(s)])
```

---

## 8. Bootstrap Process

### 8.1 Stage 0: Rust Bootstrap

```rust
// Minimal Rust code to bootstrap the VM

fn main() {
    // 1. Load Quorlin compiler bytecode
    let bytecode = std::fs::read("compiler.qbc").unwrap();
    
    // 2. Create VM instance
    let mut vm = QuorlinVM::new();
    
    // 3. Register FFI functions
    vm.register_ffi("read_file", Box::new(FileReadFFI));
    vm.register_ffi("write_file", Box::new(FileWriteFFI));
    vm.register_ffi("print", Box::new(PrintFFI));
    
    // 4. Load bytecode
    vm.load_bytecode(&bytecode).unwrap();
    
    // 5. Execute main function
    let args = std::env::args().collect::<Vec<_>>();
    let result = vm.call_function("main", &args).unwrap();
    
    // 6. Exit with result code
    std::process::exit(result.as_int() as i32);
}
```

### 8.2 Stage 1: Self-Compilation

```bash
# Use Rust-bootstrapped VM to compile compiler sources
./qlc-vm compiler.qbc compile compiler/main.ql --target quorlin -o compiler-stage1.qbc

# Now we have a compiler compiled by itself!
```

---

## 9. Performance Considerations

### 9.1 Optimization Strategies

**Bytecode Optimizations:**
- Constant folding at compile time
- Dead code elimination
- Peephole optimization (combine adjacent instructions)

**Runtime Optimizations:**
- Inline caching for method calls
- JIT compilation for hot paths (future)
- Efficient stack management
- Lazy GC (only collect when needed)

### 9.2 Benchmarks

**Target Performance:**
- Compilation speed: Within 2x of Rust compiler
- Memory usage: Within 3x of Rust compiler
- VM startup: < 100ms
- GC pause: < 10ms for typical workloads

---

## 10. Debugging Support

### 10.1 Debug Info

```quorlin
struct DebugInfo:
    """Debug information in bytecode."""
    source_map: HashMap[uint256, SourceLocation]
    local_names: HashMap[uint256, Vec[str]]
    function_names: HashMap[uint256, str]

# Emit debug info during compilation
fn emit_debug_info(location: SourceLocation):
    emit_opcode(Opcode.DEBUG_INFO)
    emit_uint32(location.line)
    emit_uint32(location.column)
```

### 10.2 Debugger

```quorlin
contract Debugger:
    """Interactive debugger for Quorlin VM."""
    
    vm: QuorlinVM
    breakpoints: Vec[uint256]
    
    @external
    fn step():
        """Execute one instruction."""
        self.vm.execute_one()
        self.print_state()
    
    @external
    fn continue_execution():
        """Continue until breakpoint."""
        while not self.at_breakpoint():
            self.vm.execute_one()
    
    @external
    fn print_stack():
        """Print current stack."""
        for value in self.vm.stack:
            println(value.to_string())
```

---

## 11. Distribution

### 11.1 Standalone Executable

```
quorlin-compiler-v2.0.0/
├── qlc.exe              # VM + embedded bytecode
├── stdlib/              # Standard library bytecode
│   ├── collections.qbc
│   ├── io.qbc
│   └── string.qbc
└── README.md
```

### 11.2 Separate VM + Bytecode

```
quorlin-compiler-v2.0.0/
├── qlc-vm.exe           # Quorlin VM
├── compiler.qbc         # Compiler bytecode
├── stdlib/              # Standard library
└── README.md

# Usage:
./qlc-vm compiler.qbc compile mycontract.ql --target evm
```

---

## 12. Future Enhancements

### Planned Features:
- [ ] JIT compilation for hot paths
- [ ] Parallel GC
- [ ] Incremental GC
- [ ] Profile-guided optimization
- [ ] Native code generation (LLVM backend)
- [ ] WebAssembly target for browser execution
- [ ] Remote debugging protocol

---

**Status**: Phase 1 - Foundation  
**Next**: Begin implementation  
**Last Updated**: 2025-12-11
