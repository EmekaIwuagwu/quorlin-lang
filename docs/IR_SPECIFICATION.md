# Quorlin Intermediate Representation (QIR) Specification

**Version**: 1.0.0  
**Purpose**: Define the target-agnostic intermediate representation for the Quorlin compiler  
**Status**: Phase 1 - Foundation  
**Date**: 2025-12-11

---

## 1. Overview

The **Quorlin Intermediate Representation (QIR)** is a low-level, target-agnostic representation that sits between the frontend (AST) and backend (code generation). It enables:

1. **Target Independence**: Single IR for all backends (EVM, Solana, Polkadot, Aptos, Quorlin)
2. **Optimization**: Common optimization passes work on IR
3. **Security Analysis**: Analyze IR for vulnerabilities
4. **Caching**: Serialize IR for incremental compilation
5. **Debugging**: Generate debug info from IR

### Design Principles

- **SSA Form**: Static Single Assignment for optimization
- **Type Preservation**: Full type information retained
- **Security Metadata**: Track reentrancy, state access patterns
- **Control Flow Graph**: Explicit CFG representation
- **Serializable**: Can be saved/loaded from disk

---

## 2. IR Structure

### 2.1 Module

```quorlin
struct QIRModule:
    """Top-level compilation unit."""
    name: str
    contracts: Vec[QIRContract]
    functions: Vec[QIRFunction]  # Free functions
    types: Vec[QIRType]
    constants: Vec[QIRConstant]
    imports: Vec[QIRImport]
    metadata: QIRMetadata

struct QIRMetadata:
    """Module metadata."""
    source_file: str
    compiler_version: str
    optimization_level: uint8
    target_platform: str
    security_checks: Vec[SecurityCheck]
```

### 2.2 Contract

```quorlin
struct QIRContract:
    """Smart contract representation."""
    name: str
    state_vars: Vec[QIRStateVar]
    functions: Vec[QIRFunction]
    events: Vec[QIREvent]
    errors: Vec[QIRError]
    storage_layout: StorageLayout
    constructor: Optional[QIRFunction]
    interfaces: Vec[str]  # Implemented interfaces
    metadata: ContractMetadata

struct QIRStateVar:
    """Contract state variable."""
    name: str
    ty: QIRType
    storage_slot: uint256
    visibility: Visibility
    is_constant: bool
    initial_value: Optional[QIRValue]

enum Visibility:
    Public
    Private
    Internal
    External
```

### 2.3 Function

```quorlin
struct QIRFunction:
    """Function representation in IR."""
    name: str
    params: Vec[QIRParam]
    return_type: Optional[QIRType]
    body: QIRBasicBlock  # Entry block
    local_vars: HashMap[str, QIRType]
    attributes: FunctionAttributes
    security_metadata: SecurityMetadata
    
struct QIRParam:
    """Function parameter."""
    name: str
    ty: QIRType
    is_mutable: bool

struct FunctionAttributes:
    """Function attributes."""
    visibility: Visibility
    is_constructor: bool
    is_view: bool  # Read-only
    is_pure: bool  # No state access
    is_payable: bool
    is_internal: bool
    selector: Optional[bytes4]  # Function selector for EVM
```

---

## 3. Type System

### 3.1 QIR Types

```quorlin
enum QIRType:
    """IR type representation."""
    # Primitive types
    Unit  # void/()
    Bool
    Int(width: uint16, signed: bool)  # Int(256, false) = uint256
    Address
    Bytes(size: Optional[uint256])  # Bytes(32) or Bytes(None) for dynamic
    String
    
    # Composite types
    Struct(name: str, fields: Vec[StructField])
    Enum(name: str, variants: Vec[EnumVariant])
    Tuple(elements: Vec[QIRType])
    Array(element_ty: Box[QIRType], size: Optional[uint256])
    Mapping(key_ty: Box[QIRType], value_ty: Box[QIRType])
    
    # Generic types
    Generic(name: str, type_params: Vec[QIRType])
    TypeParam(name: str)  # For generic type parameters
    
    # Function types
    Function(params: Vec[QIRType], return_ty: Box[QIRType])
    
    # Reference types
    Ref(inner: Box[QIRType], is_mutable: bool)
    Box(inner: Box[QIRType])

struct StructField:
    name: str
    ty: QIRType
    offset: uint256  # For layout

struct EnumVariant:
    name: str
    discriminant: uint256
    data: Optional[QIRType]
```

---

## 4. Control Flow

### 4.1 Basic Blocks

```quorlin
struct QIRBasicBlock:
    """Basic block in control flow graph."""
    label: str
    instructions: Vec[QIRInstruction]
    terminator: QIRTerminator
    predecessors: Vec[str]  # Labels of predecessor blocks
    successors: Vec[str]  # Labels of successor blocks
    metadata: BlockMetadata

struct BlockMetadata:
    """Block metadata for analysis."""
    dominates: Vec[str]  # Blocks dominated by this block
    post_dominates: Vec[str]
    loop_header: bool
    loop_depth: uint256
```

### 4.2 Terminators

```quorlin
enum QIRTerminator:
    """Block terminator (control flow)."""
    Return(value: Optional[QIRValue])
    Jump(target: str)  # Unconditional jump to label
    Branch(condition: QIRValue, true_target: str, false_target: str)
    Switch(value: QIRValue, cases: Vec[SwitchCase], default: str)
    Unreachable  # Panic/abort

struct SwitchCase:
    value: QIRValue
    target: str
```

---

## 5. Instructions

### 5.1 Instruction Set

```quorlin
enum QIRInstruction:
    """IR instructions."""
    
    # Assignment
    Assign(dest: Register, value: QIRValue)
    
    # Arithmetic
    Add(dest: Register, left: QIRValue, right: QIRValue, checked: bool)
    Sub(dest: Register, left: QIRValue, right: QIRValue, checked: bool)
    Mul(dest: Register, left: QIRValue, right: QIRValue, checked: bool)
    Div(dest: Register, left: QIRValue, right: QIRValue, checked: bool)
    Mod(dest: Register, left: QIRValue, right: QIRValue, checked: bool)
    Pow(dest: Register, base: QIRValue, exp: QIRValue, checked: bool)
    Neg(dest: Register, value: QIRValue)
    
    # Bitwise
    And(dest: Register, left: QIRValue, right: QIRValue)
    Or(dest: Register, left: QIRValue, right: QIRValue)
    Xor(dest: Register, left: QIRValue, right: QIRValue)
    Not(dest: Register, value: QIRValue)
    Shl(dest: Register, value: QIRValue, shift: QIRValue)
    Shr(dest: Register, value: QIRValue, shift: QIRValue)
    
    # Comparison
    Eq(dest: Register, left: QIRValue, right: QIRValue)
    Ne(dest: Register, left: QIRValue, right: QIRValue)
    Lt(dest: Register, left: QIRValue, right: QIRValue)
    Le(dest: Register, left: QIRValue, right: QIRValue)
    Gt(dest: Register, left: QIRValue, right: QIRValue)
    Ge(dest: Register, left: QIRValue, right: QIRValue)
    
    # Logical
    LogicalAnd(dest: Register, left: QIRValue, right: QIRValue)
    LogicalOr(dest: Register, left: QIRValue, right: QIRValue)
    LogicalNot(dest: Register, value: QIRValue)
    
    # Memory operations
    Load(dest: Register, address: QIRValue)
    Store(address: QIRValue, value: QIRValue)
    
    # Storage operations (blockchain-specific)
    StorageLoad(dest: Register, slot: uint256)
    StorageStore(slot: uint256, value: QIRValue)
    
    # Mapping operations
    MappingGet(dest: Register, mapping: str, key: QIRValue)
    MappingSet(mapping: str, key: QIRValue, value: QIRValue)
    
    # Function calls
    Call(dest: Optional[Register], function: str, args: Vec[QIRValue])
    ExternalCall(dest: Optional[Register], contract: QIRValue, function: str, args: Vec[QIRValue], value: QIRValue)
    
    # Type conversions
    Cast(dest: Register, value: QIRValue, target_ty: QIRType)
    
    # Struct/tuple operations
    StructGet(dest: Register, struct_val: QIRValue, field: str)
    StructSet(struct_val: QIRValue, field: str, value: QIRValue)
    TupleGet(dest: Register, tuple_val: QIRValue, index: uint256)
    
    # Array operations
    ArrayGet(dest: Register, array: QIRValue, index: QIRValue)
    ArraySet(array: QIRValue, index: QIRValue, value: QIRValue)
    ArrayLen(dest: Register, array: QIRValue)
    
    # Event emission
    EmitEvent(event_id: uint256, args: Vec[QIRValue])
    
    # Error handling
    Revert(message: str)
    Require(condition: QIRValue, message: str)
    Assert(condition: QIRValue, message: str)
    
    # Blockchain-specific
    GetCaller(dest: Register)  # msg.sender
    GetValue(dest: Register)  # msg.value
    GetTimestamp(dest: Register)  # block.timestamp
    GetBlockNumber(dest: Register)  # block.number
    
    # Debug/metadata
    DebugInfo(info: str)
    SourceLocation(location: SourceLocation)
```

### 5.2 Values

```quorlin
enum QIRValue:
    """Values in IR."""
    Register(id: uint256, ty: QIRType)
    Constant(value: QIRConstant)
    GlobalVar(name: str)
    LocalVar(name: str)
    Parameter(index: uint256)

enum QIRConstant:
    """Constant values."""
    Int(value: uint256, ty: QIRType)
    Bool(value: bool)
    String(value: str)
    Bytes(value: bytes)
    Address(value: address)
    Null(ty: QIRType)
    Struct(fields: HashMap[str, QIRConstant])
    Array(elements: Vec[QIRConstant])
    Tuple(elements: Vec[QIRConstant])

struct Register:
    """Virtual register (SSA)."""
    id: uint256
    ty: QIRType
    name: Optional[str]  # For debugging
```

---

## 6. Security Metadata

### 6.1 Security Annotations

```quorlin
struct SecurityMetadata:
    """Security analysis metadata."""
    reentrancy_depth: uint256
    state_mutations: Vec[StateMutation]
    external_calls: Vec[ExternalCallInfo]
    access_checks: Vec[AccessCheck]
    arithmetic_checks: Vec[ArithmeticCheck]
    
struct StateMutation:
    """State variable mutation."""
    variable: str
    location: SourceLocation
    before_external_call: bool

struct ExternalCallInfo:
    """External call information."""
    location: SourceLocation
    target: str
    function: str
    state_before: Vec[str]  # State vars accessed before
    state_after: Vec[str]  # State vars mutated after
    
struct AccessCheck:
    """Access control check."""
    location: SourceLocation
    checked_caller: bool
    required_role: Optional[str]
    
struct ArithmeticCheck:
    """Arithmetic operation check."""
    location: SourceLocation
    operation: str
    checked: bool  # Using safe math?
```

---

## 7. Storage Layout

### 7.1 Storage Allocation

```quorlin
struct StorageLayout:
    """Contract storage layout."""
    slots: HashMap[str, StorageSlot]
    next_slot: uint256
    
struct StorageSlot:
    """Storage slot information."""
    variable: str
    slot: uint256
    offset: uint256  # Offset within slot
    size: uint256  # Size in bytes
    ty: QIRType
```

---

## 8. Events and Errors

### 8.1 Events

```quorlin
struct QIREvent:
    """Event declaration."""
    name: str
    params: Vec[EventParam]
    event_id: uint256  # Keccak256 hash of signature
    
struct EventParam:
    """Event parameter."""
    name: str
    ty: QIRType
    indexed: bool
```

### 8.2 Errors

```quorlin
struct QIRError:
    """Custom error declaration."""
    name: str
    params: Vec[ErrorParam]
    error_id: uint256  # Selector
    
struct ErrorParam:
    """Error parameter."""
    name: str
    ty: QIRType
```

---

## 9. Optimization Passes

### 9.1 Common Optimizations

```quorlin
# Constant folding
Add(r1, Constant(10), Constant(20)) => Assign(r1, Constant(30))

# Dead code elimination
r1 = Add(r2, r3)  # r1 never used
# => removed

# Common subexpression elimination
r1 = Add(r2, r3)
r4 = Add(r2, r3)
# => r1 = Add(r2, r3); r4 = r1

# Copy propagation
r1 = r2
r3 = Add(r1, r4)
# => r3 = Add(r2, r4)

# Strength reduction
r1 = Mul(r2, Constant(8))
# => r1 = Shl(r2, Constant(3))
```

### 9.2 Blockchain-Specific Optimizations

```quorlin
# Storage access coalescing
StorageLoad(r1, slot_0)
StorageLoad(r2, slot_0)
# => StorageLoad(r1, slot_0); r2 = r1

# Event batching
EmitEvent(event1, [arg1])
EmitEvent(event1, [arg2])
# => EmitEvent(event1, [arg1, arg2])  # If possible

# Gas optimization
# Prefer memory over storage for temporary data
```

---

## 10. IR Generation

### 10.1 AST to IR Lowering

```quorlin
contract IRBuilder:
    """Builds IR from AST."""
    
    current_block: QIRBasicBlock
    blocks: HashMap[str, QIRBasicBlock]
    next_register: uint256
    next_label: uint256
    
    @external
    fn build_module(ast: Module) -> QIRModule:
        """Build IR module from AST."""
        let qir_module = QIRModule(
            name: ast.name,
            contracts: Vec[QIRContract](),
            functions: Vec[QIRFunction](),
            types: Vec[QIRType](),
            constants: Vec[QIRConstant](),
            imports: Vec[QIRImport](),
            metadata: self.build_metadata()
        )
        
        for contract in ast.contracts:
            qir_module.contracts.push(self.build_contract(contract))
        
        return qir_module
    
    @internal
    fn build_contract(ast: ContractDecl) -> QIRContract:
        """Build IR contract from AST."""
        let qir_contract = QIRContract(
            name: ast.name,
            state_vars: Vec[QIRStateVar](),
            functions: Vec[QIRFunction](),
            events: Vec[QIREvent](),
            errors: Vec[QIRError](),
            storage_layout: self.compute_storage_layout(ast),
            constructor: None,
            interfaces: ast.bases,
            metadata: ContractMetadata()
        )
        
        # Build state variables
        for state_var in ast.state_vars:
            qir_contract.state_vars.push(self.build_state_var(state_var))
        
        # Build functions
        for function in ast.functions:
            let qir_func = self.build_function(function)
            if function.is_constructor:
                qir_contract.constructor = Some(qir_func)
            else:
                qir_contract.functions.push(qir_func)
        
        return qir_contract
    
    @internal
    fn build_function(ast: Function) -> QIRFunction:
        """Build IR function from AST."""
        self.reset_builder()
        
        let entry_block = self.create_block("entry")
        self.current_block = entry_block
        
        # Build function body
        for stmt in ast.body:
            self.build_statement(stmt)
        
        return QIRFunction(
            name: ast.name,
            params: self.build_params(ast.params),
            return_type: ast.return_type,
            body: entry_block,
            local_vars: self.local_vars.clone(),
            attributes: self.build_attributes(ast),
            security_metadata: self.security_metadata.clone()
        )
    
    @internal
    fn build_statement(stmt: Stmt):
        """Build IR from statement."""
        match stmt:
            Stmt.Assign(target, value):
                let val_reg = self.build_expr(value)
                self.emit(QIRInstruction.Assign(target, val_reg))
            
            Stmt.If(condition, then_body, else_body):
                self.build_if(condition, then_body, else_body)
            
            Stmt.While(condition, body):
                self.build_while(condition, body)
            
            Stmt.Return(value):
                let val_reg = if value: self.build_expr(value) else: None
                self.emit_terminator(QIRTerminator.Return(val_reg))
            
            Stmt.Emit(event, args):
                self.build_emit(event, args)
            
            _:
                # Handle other statement types
                pass
    
    @internal
    fn build_expr(expr: Expr) -> Register:
        """Build IR from expression."""
        match expr:
            Expr.IntLit(value):
                let reg = self.new_register(QIRType.Int(256, false))
                self.emit(QIRInstruction.Assign(reg, QIRValue.Constant(QIRConstant.Int(value))))
                return reg
            
            Expr.BinOp(left, op, right):
                let left_reg = self.build_expr(left)
                let right_reg = self.build_expr(right)
                let result_reg = self.new_register(left_reg.ty)
                
                match op:
                    BinOp.Add:
                        self.emit(QIRInstruction.Add(result_reg, left_reg, right_reg, checked: true))
                    BinOp.Sub:
                        self.emit(QIRInstruction.Sub(result_reg, left_reg, right_reg, checked: true))
                    # ... other operators
                
                return result_reg
            
            Expr.Call(func, args):
                return self.build_call(func, args)
            
            _:
                # Handle other expression types
                pass
    
    @internal
    fn build_if(condition: Expr, then_body: Vec[Stmt], else_body: Optional[Vec[Stmt]]):
        """Build IR for if statement."""
        let cond_reg = self.build_expr(condition)
        
        let then_label = self.new_label("then")
        let else_label = self.new_label("else")
        let merge_label = self.new_label("merge")
        
        # Emit branch
        self.emit_terminator(QIRTerminator.Branch(
            cond_reg,
            then_label,
            else_label if else_body else merge_label
        ))
        
        # Build then block
        self.current_block = self.create_block(then_label)
        for stmt in then_body:
            self.build_statement(stmt)
        self.emit_terminator(QIRTerminator.Jump(merge_label))
        
        # Build else block if present
        if else_body:
            self.current_block = self.create_block(else_label)
            for stmt in else_body:
                self.build_statement(stmt)
            self.emit_terminator(QIRTerminator.Jump(merge_label))
        
        # Continue at merge point
        self.current_block = self.create_block(merge_label)
    
    @internal
    fn new_register(ty: QIRType) -> Register:
        """Allocate new virtual register."""
        let reg = Register(
            id: self.next_register,
            ty: ty,
            name: None
        )
        self.next_register = self.next_register + 1
        return reg
    
    @internal
    fn new_label(prefix: str) -> str:
        """Generate new block label."""
        let label = f"{prefix}_{self.next_label}"
        self.next_label = self.next_label + 1
        return label
    
    @internal
    fn create_block(label: str) -> QIRBasicBlock:
        """Create new basic block."""
        let block = QIRBasicBlock(
            label: label,
            instructions: Vec[QIRInstruction](),
            terminator: QIRTerminator.Unreachable,
            predecessors: Vec[str](),
            successors: Vec[str](),
            metadata: BlockMetadata()
        )
        self.blocks.insert(label, block)
        return block
    
    @internal
    fn emit(instr: QIRInstruction):
        """Emit instruction to current block."""
        self.current_block.instructions.push(instr)
    
    @internal
    fn emit_terminator(term: QIRTerminator):
        """Emit terminator for current block."""
        self.current_block.terminator = term
```

---

## 11. IR Serialization

### 11.1 Binary Format

```
QIR Binary Format:
┌─────────────────────────────────────┐
│ Magic Number: "QIR\0" (4 bytes)     │
├─────────────────────────────────────┤
│ Version: uint32                     │
├─────────────────────────────────────┤
│ Module Name Length: uint32          │
│ Module Name: UTF-8 string           │
├─────────────────────────────────────┤
│ Num Contracts: uint32               │
│ Contracts: [Contract]*              │
├─────────────────────────────────────┤
│ Num Functions: uint32               │
│ Functions: [Function]*              │
├─────────────────────────────────────┤
│ Num Types: uint32                   │
│ Types: [Type]*                      │
├─────────────────────────────────────┤
│ Metadata: Metadata                  │
└─────────────────────────────────────┘
```

### 11.2 JSON Format (for debugging)

```json
{
  "module": {
    "name": "MyContract",
    "contracts": [
      {
        "name": "Counter",
        "state_vars": [
          {
            "name": "count",
            "type": {"Int": [256, false]},
            "storage_slot": 0
          }
        ],
        "functions": [
          {
            "name": "increment",
            "params": [],
            "return_type": null,
            "body": {
              "label": "entry",
              "instructions": [
                {
                  "StorageLoad": {
                    "dest": {"id": 0, "type": {"Int": [256, false]}},
                    "slot": 0
                  }
                },
                {
                  "Add": {
                    "dest": {"id": 1, "type": {"Int": [256, false]}},
                    "left": {"Register": 0},
                    "right": {"Constant": {"Int": [1, {"Int": [256, false]}]}},
                    "checked": true
                  }
                },
                {
                  "StorageStore": {
                    "slot": 0,
                    "value": {"Register": 1}
                  }
                }
              ],
              "terminator": {"Return": null}
            }
          }
        ]
      }
    ]
  }
}
```

---

## 12. Example: Counter Contract IR

### 12.1 Source Code

```quorlin
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

### 12.2 Generated IR

```quorlin
QIRModule(
    name: "Counter",
    contracts: [
        QIRContract(
            name: "Counter",
            state_vars: [
                QIRStateVar(
                    name: "count",
                    ty: QIRType.Int(256, false),
                    storage_slot: 0,
                    visibility: Visibility.Private,
                    is_constant: false,
                    initial_value: None
                )
            ],
            functions: [
                # increment function
                QIRFunction(
                    name: "increment",
                    params: [],
                    return_type: None,
                    body: QIRBasicBlock(
                        label: "entry",
                        instructions: [
                            StorageLoad(
                                dest: Register(0, QIRType.Int(256, false)),
                                slot: 0
                            ),
                            Add(
                                dest: Register(1, QIRType.Int(256, false)),
                                left: QIRValue.Register(0),
                                right: QIRValue.Constant(QIRConstant.Int(1)),
                                checked: true
                            ),
                            StorageStore(
                                slot: 0,
                                value: QIRValue.Register(1)
                            )
                        ],
                        terminator: QIRTerminator.Return(None)
                    ),
                    attributes: FunctionAttributes(
                        visibility: Visibility.External,
                        is_view: false,
                        selector: Some(0x12345678)
                    )
                ),
                # get_count function
                QIRFunction(
                    name: "get_count",
                    params: [],
                    return_type: Some(QIRType.Int(256, false)),
                    body: QIRBasicBlock(
                        label: "entry",
                        instructions: [
                            StorageLoad(
                                dest: Register(0, QIRType.Int(256, false)),
                                slot: 0
                            )
                        ],
                        terminator: QIRTerminator.Return(Some(QIRValue.Register(0)))
                    ),
                    attributes: FunctionAttributes(
                        visibility: Visibility.External,
                        is_view: true,
                        selector: Some(0x87654321)
                    )
                )
            ]
        )
    ]
)
```

---

## 13. Backend Consumption

### 13.1 EVM Backend

```quorlin
contract EVMBackend:
    """Generate Yul code from QIR."""
    
    @external
    fn generate(ir: QIRModule) -> str:
        let yul_code = YulEmitter()
        
        for contract in ir.contracts:
            yul_code.emit_contract(contract)
        
        return yul_code.to_string()
    
    @internal
    fn emit_function(func: QIRFunction) -> str:
        let code = f"function {func.name}() {{"
        
        for instr in func.body.instructions:
            match instr:
                QIRInstruction.StorageLoad(dest, slot):
                    code += f"let r{dest.id} := sload({slot})"
                
                QIRInstruction.Add(dest, left, right, checked):
                    if checked:
                        code += f"let r{dest.id} := checked_add({left}, {right})"
                    else:
                        code += f"let r{dest.id} := add({left}, {right})"
                
                QIRInstruction.StorageStore(slot, value):
                    code += f"sstore({slot}, {value})"
                
                _:
                    # Handle other instructions
                    pass
        
        code += "}"
        return code
```

---

## 14. Future Extensions

### Planned Features:
- [ ] LLVM IR backend for native compilation
- [ ] WebAssembly IR support
- [ ] Advanced alias analysis
- [ ] Loop optimizations (unrolling, vectorization)
- [ ] Inlining heuristics
- [ ] Profile-guided optimization
- [ ] Debug info generation (DWARF)

---

**Status**: Phase 1 - Foundation  
**Next**: Runtime Architecture  
**Last Updated**: 2025-12-11
