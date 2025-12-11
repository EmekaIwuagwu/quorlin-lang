# Quorlin Virtual Machine
# Executes Quorlin bytecode - enables self-hosting!

from compiler.runtime.stdlib import Vec, HashMap, Option, Result
from compiler.backends.quorlin import Opcode, FunctionMetadata

# ============================================================================
# VM Memory and Stack
# ============================================================================

contract VMStack:
    """Stack for VM execution."""
    
    items: Vec[uint256]
    
    @constructor
    fn __init__():
        """Create new stack."""
        self.items = Vec[uint256]()
    
    @external
    fn push(value: uint256):
        """Push value onto stack."""
        self.items.push(value)
    
    @external
    fn pop() -> Result[uint256, str]:
        """Pop value from stack."""
        if self.items.len() == 0:
            return Result.Err("Stack underflow")
        
        let value = self.items.get(self.items.len() - 1).unwrap()
        self.items.pop()
        return Result.Ok(value)
    
    @view
    fn peek() -> Result[uint256, str]:
        """Peek at top of stack."""
        if self.items.len() == 0:
            return Result.Err("Stack empty")
        
        return Result.Ok(self.items.get(self.items.len() - 1).unwrap())
    
    @view
    fn size() -> uint256:
        """Get stack size."""
        return self.items.len()

contract VMMemory:
    """Memory for VM execution."""
    
    locals: Vec[uint256]
    storage: HashMap[uint256, uint256]
    
    @constructor
    fn __init__():
        """Create new memory."""
        self.locals = Vec[uint256]()
        self.storage = HashMap[uint256, uint256]()
    
    @external
    fn allocate_locals(count: uint256):
        """Allocate local variables."""
        self.locals = Vec[uint256]()
        for i in range(count):
            self.locals.push(0)
    
    @external
    fn load_local(index: uint256) -> Result[uint256, str]:
        """Load local variable."""
        if index >= self.locals.len():
            return Result.Err("Invalid local index")
        
        return Result.Ok(self.locals.get(index).unwrap())
    
    @external
    fn store_local(index: uint256, value: uint256) -> Result[(), str]:
        """Store local variable."""
        if index >= self.locals.len():
            return Result.Err("Invalid local index")
        
        self.locals.set(index, value)
        return Result.Ok(())
    
    @external
    fn load_storage(slot: uint256) -> uint256:
        """Load from storage."""
        return self.storage.get(slot).unwrap_or(0)
    
    @external
    fn store_storage(slot: uint256, value: uint256):
        """Store to storage."""
        self.storage.insert(slot, value)

# ============================================================================
# Bytecode Loader
# ============================================================================

struct BytecodeModule:
    """Loaded bytecode module."""
    magic: uint32
    version: (uint8, uint8, uint8)
    constants: Vec[uint256]
    strings: Vec[str]
    functions: Vec[FunctionMetadata]
    bytecode: Vec[uint8]

contract BytecodeLoader:
    """Loads and validates bytecode."""
    
    @external
    fn load(bytecode: Vec[uint8]) -> Result[BytecodeModule, str]:
        """Load bytecode module."""
        let mut offset: uint256 = 0
        
        // Read magic number
        let magic = self.read_uint32(bytecode, offset)?
        offset = offset + 4
        
        if magic != 0x00434251:  // "QBC\0"
            return Result.Err("Invalid magic number")
        
        // Read version
        let major = bytecode.get(offset).unwrap()
        let minor = bytecode.get(offset + 1).unwrap()
        let patch = bytecode.get(offset + 2).unwrap()
        offset = offset + 4
        
        // Read constant pool
        let const_count = self.read_uint32(bytecode, offset)?
        offset = offset + 4
        
        let mut constants = Vec[uint256]()
        for i in range(const_count):
            let constant = self.read_uint256(bytecode, offset)?
            constants.push(constant)
            offset = offset + 32
        
        // Read string table
        let string_count = self.read_uint32(bytecode, offset)?
        offset = offset + 4
        
        let mut strings = Vec[str]()
        for i in range(string_count):
            let (s, new_offset) = self.read_string(bytecode, offset)?
            strings.push(s)
            offset = new_offset
        
        // Read function table
        let func_count = self.read_uint32(bytecode, offset)?
        offset = offset + 4
        
        let mut functions = Vec[FunctionMetadata]()
        for i in range(func_count):
            let name_id = self.read_uint32(bytecode, offset)?
            let func_offset = self.read_uint32(bytecode, offset + 4)?
            let num_params = self.read_uint32(bytecode, offset + 8)?
            let num_locals = self.read_uint32(bytecode, offset + 12)?
            
            functions.push(FunctionMetadata(
                name: strings.get(name_id).unwrap(),
                offset: func_offset,
                num_params: num_params,
                num_locals: num_locals
            ))
            
            offset = offset + 16
        
        return Result.Ok(BytecodeModule(
            magic: magic,
            version: (major, minor, patch),
            constants: constants,
            strings: strings,
            functions: functions,
            bytecode: bytecode
        ))
    
    @internal
    fn read_uint32(data: Vec[uint8], offset: uint256) -> Result[uint256, str]:
        """Read uint32 in little-endian."""
        if offset + 4 > data.len():
            return Result.Err("Read past end of data")
        
        let b0 = data.get(offset).unwrap() as uint256
        let b1 = data.get(offset + 1).unwrap() as uint256
        let b2 = data.get(offset + 2).unwrap() as uint256
        let b3 = data.get(offset + 3).unwrap() as uint256
        
        return Result.Ok(b0 | (b1 << 8) | (b2 << 16) | (b3 << 24))
    
    @internal
    fn read_uint256(data: Vec[uint8], offset: uint256) -> Result[uint256, str]:
        """Read uint256 in little-endian."""
        if offset + 32 > data.len():
            return Result.Err("Read past end of data")
        
        let mut value: uint256 = 0
        for i in range(32):
            let b = data.get(offset + i).unwrap() as uint256
            value = value | (b << (i * 8))
        
        return Result.Ok(value)
    
    @internal
    fn read_string(data: Vec[uint8], offset: uint256) -> Result[(str, uint256], str]:
        """Read string with length prefix."""
        let len = self.read_uint32(data, offset)?
        let mut chars = Vec[char]()
        
        for i in range(len):
            let ch = data.get(offset + 4 + i).unwrap() as char
            chars.push(ch)
        
        let s = str_from_chars(chars)
        return Result.Ok((s, offset + 4 + len))

# ============================================================================
# Virtual Machine
# ============================================================================

contract QuorlinVM:
    """Quorlin Virtual Machine - executes bytecode."""
    
    module: Option[BytecodeModule]
    stack: VMStack
    memory: VMMemory
    pc: uint256  // Program counter
    call_stack: Vec[uint256]  // Return addresses
    
    @constructor
    fn __init__():
        """Create new VM."""
        self.module = Option.None
        self.stack = VMStack()
        self.memory = VMMemory()
        self.pc = 0
        self.call_stack = Vec[uint256]()
    
    @external
    fn load_module(bytecode: Vec[uint8]) -> Result[(), str]:
        """Load bytecode module."""
        let loader = BytecodeLoader()
        let module = loader.load(bytecode)?
        self.module = Option.Some(module)
        return Result.Ok(())
    
    @external
    fn execute_function(func_name: str, args: Vec[uint256]) -> Result[uint256, str]:
        """Execute a function by name."""
        let module = self.module.unwrap()
        
        // Find function
        let mut func_meta: Option[FunctionMetadata] = Option.None
        for func in module.functions:
            if func.name == func_name:
                func_meta = Option.Some(func)
                break
        
        match func_meta:
            Option.None:
                return Result.Err(f"Function not found: {func_name}")
            
            Option.Some(meta):
                // Allocate locals
                self.memory.allocate_locals(meta.num_locals)
                
                // Push arguments as locals
                for i in range(args.len()):
                    self.memory.store_local(i, args.get(i).unwrap())?
                
                // Set PC to function start
                self.pc = meta.offset
                
                // Execute
                return self.execute()
    
    @internal
    fn execute() -> Result[uint256, str]:
        """Execute bytecode from current PC."""
        let module = self.module.unwrap()
        
        while self.pc < module.bytecode.len():
            let opcode = module.bytecode.get(self.pc).unwrap()
            self.pc = self.pc + 1
            
            match opcode:
                Opcode.LOAD_CONST as uint8:
                    let const_id = self.read_uint32()?
                    let value = module.constants.get(const_id).unwrap()
                    self.stack.push(value)
                
                Opcode.LOAD_LOCAL as uint8:
                    let index = self.read_uint32()?
                    let value = self.memory.load_local(index)?
                    self.stack.push(value)
                
                Opcode.STORE_LOCAL as uint8:
                    let index = self.read_uint32()?
                    let value = self.stack.pop()?
                    self.memory.store_local(index, value)?
                
                Opcode.POP as uint8:
                    self.stack.pop()?
                
                Opcode.DUP as uint8:
                    let value = self.stack.peek()?
                    self.stack.push(value)
                
                Opcode.ADD as uint8:
                    let b = self.stack.pop()?
                    let a = self.stack.pop()?
                    self.stack.push(a + b)
                
                Opcode.SUB as uint8:
                    let b = self.stack.pop()?
                    let a = self.stack.pop()?
                    self.stack.push(a - b)
                
                Opcode.MUL as uint8:
                    let b = self.stack.pop()?
                    let a = self.stack.pop()?
                    self.stack.push(a * b)
                
                Opcode.DIV as uint8:
                    let b = self.stack.pop()?
                    let a = self.stack.pop()?
                    if b == 0:
                        return Result.Err("Division by zero")
                    self.stack.push(a / b)
                
                Opcode.CHECKED_ADD as uint8:
                    let b = self.stack.pop()?
                    let a = self.stack.pop()?
                    let result = a + b
                    if result < a:
                        return Result.Err("Overflow in checked_add")
                    self.stack.push(result)
                
                Opcode.CHECKED_SUB as uint8:
                    let b = self.stack.pop()?
                    let a = self.stack.pop()?
                    if a < b:
                        return Result.Err("Underflow in checked_sub")
                    self.stack.push(a - b)
                
                Opcode.CHECKED_MUL as uint8:
                    let b = self.stack.pop()?
                    let a = self.stack.pop()?
                    let result = a * b
                    if b != 0 and result / b != a:
                        return Result.Err("Overflow in checked_mul")
                    self.stack.push(result)
                
                Opcode.EQ as uint8:
                    let b = self.stack.pop()?
                    let a = self.stack.pop()?
                    self.stack.push(if a == b: 1 else: 0)
                
                Opcode.LT as uint8:
                    let b = self.stack.pop()?
                    let a = self.stack.pop()?
                    self.stack.push(if a < b: 1 else: 0)
                
                Opcode.STORAGE_LOAD as uint8:
                    let slot = self.read_uint32()?
                    let value = self.memory.load_storage(slot)
                    self.stack.push(value)
                
                Opcode.STORAGE_STORE as uint8:
                    let slot = self.read_uint32()?
                    let value = self.stack.pop()?
                    self.memory.store_storage(slot, value)
                
                Opcode.JUMP as uint8:
                    let target = self.read_uint32()?
                    self.pc = target
                
                Opcode.JUMP_IF_FALSE as uint8:
                    let target = self.read_uint32()?
                    let condition = self.stack.pop()?
                    if condition == 0:
                        self.pc = target
                
                Opcode.RETURN as uint8:
                    let value = self.stack.pop()?
                    return Result.Ok(value)
                
                Opcode.RETURN_VOID as uint8:
                    return Result.Ok(0)
                
                _:
                    return Result.Err(f"Unknown opcode: {opcode}")
        
        return Result.Err("Unexpected end of bytecode")
    
    @internal
    fn read_uint32() -> Result[uint256, str]:
        """Read uint32 from bytecode at PC."""
        let module = self.module.unwrap()
        
        if self.pc + 4 > module.bytecode.len():
            return Result.Err("Read past end of bytecode")
        
        let b0 = module.bytecode.get(self.pc).unwrap() as uint256
        let b1 = module.bytecode.get(self.pc + 1).unwrap() as uint256
        let b2 = module.bytecode.get(self.pc + 2).unwrap() as uint256
        let b3 = module.bytecode.get(self.pc + 3).unwrap() as uint256
        
        self.pc = self.pc + 4
        
        return Result.Ok(b0 | (b1 << 8) | (b2 << 16) | (b3 << 24))

# ============================================================================
# Helper Functions
# ============================================================================

fn execute_bytecode(bytecode: Vec[uint8], func_name: str, args: Vec[uint256]) -> Result[uint256, str]:
    """Convenience function to execute bytecode."""
    let vm = QuorlinVM()
    vm.load_module(bytecode)?
    return vm.execute_function(func_name, args)
