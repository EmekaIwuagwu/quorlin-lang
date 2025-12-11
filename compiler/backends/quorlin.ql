# Quorlin Self-Target Backend
# Generates Quorlin bytecode from QIR - THE KEY TO SELF-HOSTING!

from compiler.runtime.stdlib import Vec, HashMap, Option, Result
from compiler.runtime.stdlib import to_string, str_join
from compiler.middle.ir_builder import *

# ============================================================================
# Quorlin Bytecode Generator
# ============================================================================

contract QuorlinBytecodeGenerator:
    """Generates Quorlin bytecode from QIR - enables self-hosting!"""
    
    bytecode: Vec[uint8]
    constant_pool: Vec[uint256]
    string_table: Vec[str]
    function_table: Vec[FunctionMetadata]
    
    @constructor
    fn __init__():
        """Create new bytecode generator."""
        self.bytecode = Vec[uint8]()
        self.constant_pool = Vec[uint256]()
        self.string_table = Vec[str]()
        self.function_table = Vec[FunctionMetadata]()
    
    @external
    fn generate(qir: QIRModule) -> Result[bytes, str]:
        """Generate Quorlin bytecode from QIR module."""
        // Emit magic number
        self.emit_magic_number()
        
        // Emit version
        self.emit_version(1, 0, 0)
        
        // Build constant pool
        for contract in qir.contracts:
            self.build_constant_pool(contract)
        
        // Emit constant pool
        self.emit_constant_pool()
        
        // Emit string table
        self.emit_string_table()
        
        // Generate functions
        for contract in qir.contracts:
            self.generate_contract(contract)?
        
        // Emit function table
        self.emit_function_table()
        
        return Result.Ok(self.bytecode)
    
    @internal
    fn emit_magic_number():
        """Emit magic number 'QBC\0'."""
        self.bytecode.push(0x51)  # 'Q'
        self.bytecode.push(0x42)  # 'B'
        self.bytecode.push(0x43)  # 'C'
        self.bytecode.push(0x00)  # '\0'
    
    @internal
    fn emit_version(major: uint8, minor: uint8, patch: uint8):
        """Emit version number."""
        self.bytecode.push(major)
        self.bytecode.push(minor)
        self.bytecode.push(patch)
        self.bytecode.push(0)  # Reserved
    
    @internal
    fn build_constant_pool(contract: QIRContract):
        """Build constant pool from contract."""
        for func in contract.functions:
            for instr in func.entry_block.instructions:
                match instr:
                    QIRInstruction.Assign(_, value):
                        self.add_constant_from_value(value)
                    
                    QIRInstruction.Add(_, left, right, _):
                        self.add_constant_from_value(left)
                        self.add_constant_from_value(right)
                    
                    _:
                        pass
    
    @internal
    fn add_constant_from_value(value: QIRValue):
        """Add constant to pool if it's a constant value."""
        match value:
            QIRValue.Constant(val):
                if not self.constant_pool.contains(val):
                    self.constant_pool.push(val)
            _:
                pass
    
    @internal
    fn emit_constant_pool():
        """Emit constant pool to bytecode."""
        // Emit count
        self.emit_uint32(self.constant_pool.len())
        
        // Emit constants
        for constant in self.constant_pool:
            self.emit_uint256(constant)
    
    @internal
    fn emit_string_table():
        """Emit string table to bytecode."""
        // Emit count
        self.emit_uint32(self.string_table.len())
        
        // Emit strings
        for s in self.string_table:
            self.emit_string(s)
    
    @internal
    fn generate_contract(contract: QIRContract) -> Result[(), str]:
        """Generate bytecode for a contract."""
        // Generate functions
        for func in contract.functions:
            self.generate_function(func, contract)?
        
        return Result.Ok(())
    
    @internal
    fn generate_function(func: QIRFunction, contract: QIRContract) -> Result[(), str]:
        """Generate bytecode for a function."""
        let func_start = self.bytecode.len()
        
        // Generate function body
        self.generate_block(func.entry_block, contract)?
        
        // Record function metadata
        let func_meta = FunctionMetadata(
            name: func.name,
            offset: func_start,
            num_params: func.params.len(),
            num_locals: func.next_register
        )
        self.function_table.push(func_meta)
        
        return Result.Ok(())
    
    @internal
    fn generate_block(block: QIRBasicBlock, contract: QIRContract) -> Result[(), str]:
        """Generate bytecode for a basic block."""
        // Generate instructions
        for instr in block.instructions:
            self.generate_instruction(instr, contract)?
        
        // Generate terminator
        self.generate_terminator(block.terminator)?
        
        return Result.Ok(())
    
    @internal
    fn generate_instruction(instr: QIRInstruction, contract: QIRContract) -> Result[(), str]:
        """Generate bytecode for an instruction."""
        match instr:
            QIRInstruction.Assign(dest, value):
                self.emit_opcode(Opcode.LOAD_CONST)
                let const_id = self.get_constant_id(value)
                self.emit_uint32(const_id)
                self.emit_opcode(Opcode.STORE_LOCAL)
                self.emit_uint32(dest)
            
            QIRInstruction.Add(dest, left, right, checked):
                self.emit_load_value(left)
                self.emit_load_value(right)
                
                if checked:
                    self.emit_opcode(Opcode.CHECKED_ADD)
                else:
                    self.emit_opcode(Opcode.ADD)
                
                self.emit_opcode(Opcode.STORE_LOCAL)
                self.emit_uint32(dest)
            
            QIRInstruction.Sub(dest, left, right, checked):
                self.emit_load_value(left)
                self.emit_load_value(right)
                
                if checked:
                    self.emit_opcode(Opcode.CHECKED_SUB)
                else:
                    self.emit_opcode(Opcode.SUB)
                
                self.emit_opcode(Opcode.STORE_LOCAL)
                self.emit_uint32(dest)
            
            QIRInstruction.Mul(dest, left, right, checked):
                self.emit_load_value(left)
                self.emit_load_value(right)
                
                if checked:
                    self.emit_opcode(Opcode.CHECKED_MUL)
                else:
                    self.emit_opcode(Opcode.MUL)
                
                self.emit_opcode(Opcode.STORE_LOCAL)
                self.emit_uint32(dest)
            
            QIRInstruction.StorageLoad(dest, slot):
                self.emit_opcode(Opcode.STORAGE_LOAD)
                self.emit_uint32(slot)
                self.emit_opcode(Opcode.STORE_LOCAL)
                self.emit_uint32(dest)
            
            QIRInstruction.StorageStore(slot, value):
                self.emit_load_value(value)
                self.emit_opcode(Opcode.STORAGE_STORE)
                self.emit_uint32(slot)
            
            QIRInstruction.Call(dest, function, args):
                // Push arguments
                for arg in args:
                    self.emit_load_value(arg)
                
                // Call function
                self.emit_opcode(Opcode.CALL)
                let func_id = self.get_function_id(function)
                self.emit_uint32(func_id)
                self.emit_uint32(args.len())
                
                // Store result if needed
                match dest:
                    Option.Some(reg):
                        self.emit_opcode(Opcode.STORE_LOCAL)
                        self.emit_uint32(reg)
                    Option.None:
                        self.emit_opcode(Opcode.POP)
            
            _:
                pass
        
        return Result.Ok(())
    
    @internal
    fn generate_terminator(term: QIRTerminator) -> Result[(), str]:
        """Generate bytecode for a terminator."""
        match term:
            QIRTerminator.Return(value):
                match value:
                    Option.Some(val):
                        self.emit_load_value(val)
                        self.emit_opcode(Opcode.RETURN)
                    Option.None:
                        self.emit_opcode(Opcode.RETURN_VOID)
            
            QIRTerminator.Jump(target):
                self.emit_opcode(Opcode.JUMP)
                // Emit label offset (would be resolved in second pass)
                self.emit_uint32(0)
            
            QIRTerminator.Branch(condition, true_target, false_target):
                self.emit_load_value(condition)
                self.emit_opcode(Opcode.JUMP_IF_FALSE)
                self.emit_uint32(0)  // false target offset
            
            _:
                pass
        
        return Result.Ok(())
    
    @internal
    fn emit_load_value(value: QIRValue):
        """Emit bytecode to load a value onto stack."""
        match value:
            QIRValue.Register(id, _):
                self.emit_opcode(Opcode.LOAD_LOCAL)
                self.emit_uint32(id)
            
            QIRValue.Constant(val):
                let const_id = self.get_constant_id(value)
                self.emit_opcode(Opcode.LOAD_CONST)
                self.emit_uint32(const_id)
            
            QIRValue.GlobalVar(name):
                let slot = 0  // Would lookup in storage layout
                self.emit_opcode(Opcode.STORAGE_LOAD)
                self.emit_uint32(slot)
            
            _:
                pass
    
    @internal
    fn emit_function_table():
        """Emit function table to bytecode."""
        // Emit count
        self.emit_uint32(self.function_table.len())
        
        // Emit function metadata
        for func_meta in self.function_table:
            let name_id = self.add_string(func_meta.name)
            self.emit_uint32(name_id)
            self.emit_uint32(func_meta.offset)
            self.emit_uint32(func_meta.num_params)
            self.emit_uint32(func_meta.num_locals)
    
    @internal
    fn get_constant_id(value: QIRValue) -> uint256:
        """Get constant pool ID for a value."""
        match value:
            QIRValue.Constant(val):
                for i in range(self.constant_pool.len()):
                    if self.constant_pool.get(i).unwrap() == val:
                        return i
                return 0
            _:
                return 0
    
    @internal
    fn get_function_id(name: str) -> uint256:
        """Get function table ID for a function name."""
        for i in range(self.function_table.len()):
            if self.function_table.get(i).unwrap().name == name:
                return i
        return 0
    
    @internal
    fn add_string(s: str) -> uint256:
        """Add string to string table and return ID."""
        for i in range(self.string_table.len()):
            if self.string_table.get(i).unwrap() == s:
                return i
        
        let id = self.string_table.len()
        self.string_table.push(s)
        return id
    
    @internal
    fn emit_opcode(opcode: Opcode):
        """Emit an opcode byte."""
        self.bytecode.push(opcode as uint8)
    
    @internal
    fn emit_uint8(value: uint8):
        """Emit a uint8."""
        self.bytecode.push(value)
    
    @internal
    fn emit_uint32(value: uint256):
        """Emit a uint32 in little-endian."""
        self.bytecode.push((value & 0xFF) as uint8)
        self.bytecode.push(((value >> 8) & 0xFF) as uint8)
        self.bytecode.push(((value >> 16) & 0xFF) as uint8)
        self.bytecode.push(((value >> 24) & 0xFF) as uint8)
    
    @internal
    fn emit_uint256(value: uint256):
        """Emit a uint256 in little-endian."""
        for i in range(32):
            self.bytecode.push(((value >> (i * 8)) & 0xFF) as uint8)
    
    @internal
    fn emit_string(s: str):
        """Emit a string with length prefix."""
        let len = str_len(s)
        self.emit_uint32(len)
        
        for i in range(len):
            let ch = str_char_at(s, i).unwrap()
            self.bytecode.push(char_code(ch) as uint8)

# ============================================================================
# Opcode Definitions
# ============================================================================

enum Opcode:
    """Bytecode opcodes."""
    # Stack operations
    LOAD_CONST = 0x01
    LOAD_LOCAL = 0x02
    STORE_LOCAL = 0x03
    POP = 0x04
    DUP = 0x05
    
    # Arithmetic
    ADD = 0x10
    SUB = 0x11
    MUL = 0x12
    DIV = 0x13
    MOD = 0x14
    POW = 0x15
    
    # Checked arithmetic
    CHECKED_ADD = 0x20
    CHECKED_SUB = 0x21
    CHECKED_MUL = 0x22
    
    # Comparison
    EQ = 0x30
    NE = 0x31
    LT = 0x32
    LE = 0x33
    GT = 0x34
    GE = 0x35
    
    # Control flow
    JUMP = 0x40
    JUMP_IF_FALSE = 0x41
    JUMP_IF_TRUE = 0x42
    CALL = 0x43
    RETURN = 0x44
    RETURN_VOID = 0x45
    
    # Storage
    STORAGE_LOAD = 0x50
    STORAGE_STORE = 0x51

struct FunctionMetadata:
    """Metadata for a function in bytecode."""
    name: str
    offset: uint256
    num_params: uint256
    num_locals: uint256

# ============================================================================
# Helper Functions
# ============================================================================

fn generate_quorlin_bytecode(qir: QIRModule) -> Result[bytes, str]:
    """Convenience function to generate Quorlin bytecode."""
    let generator = QuorlinBytecodeGenerator()
    return generator.generate(qir)
