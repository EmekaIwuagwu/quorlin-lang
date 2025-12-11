# Quorlin IR Builder
# Lowers AST to intermediate representation (QIR)

from compiler.runtime.stdlib import Vec, HashMap, Option, Result
from compiler.frontend.ast import *
from compiler.middle.semantic import SemanticAnalyzer

# ============================================================================
# QIR Definitions (Intermediate Representation)
# ============================================================================

# Note: Full QIR definitions would be in a separate file
# This is a simplified version for the IR builder

enum QIRValue:
    """Values in IR."""
    Register(id: uint256, ty: Type)
    Constant(value: uint256)
    GlobalVar(name: str)
    LocalVar(name: str)

enum QIRInstruction:
    """IR instructions."""
    # Assignment
    Assign(dest: uint256, value: QIRValue)
    
    # Arithmetic
    Add(dest: uint256, left: QIRValue, right: QIRValue, checked: bool)
    Sub(dest: uint256, left: QIRValue, right: QIRValue, checked: bool)
    Mul(dest: uint256, left: QIRValue, right: QIRValue, checked: bool)
    Div(dest: uint256, left: QIRValue, right: QIRValue, checked: bool)
    Mod(dest: uint256, left: QIRValue, right: QIRValue, checked: bool)
    Pow(dest: uint256, base: QIRValue, exp: QIRValue, checked: bool)
    
    # Comparison
    Eq(dest: uint256, left: QIRValue, right: QIRValue)
    Ne(dest: uint256, left: QIRValue, right: QIRValue)
    Lt(dest: uint256, left: QIRValue, right: QIRValue)
    Le(dest: uint256, left: QIRValue, right: QIRValue)
    Gt(dest: uint256, left: QIRValue, right: QIRValue)
    Ge(dest: uint256, left: QIRValue, right: QIRValue)
    
    # Logical
    And(dest: uint256, left: QIRValue, right: QIRValue)
    Or(dest: uint256, left: QIRValue, right: QIRValue)
    Not(dest: uint256, value: QIRValue)
    
    # Memory/Storage
    StorageLoad(dest: uint256, slot: uint256)
    StorageStore(slot: uint256, value: QIRValue)
    
    # Function calls
    Call(dest: Option[uint256], function: str, args: Vec[QIRValue])
    
    # Events
    EmitEvent(event_id: uint256, args: Vec[QIRValue])

enum QIRTerminator:
    """Block terminator."""
    Return(value: Option[QIRValue])
    Jump(target: str)
    Branch(condition: QIRValue, true_target: str, false_target: str)
    Unreachable

struct QIRBasicBlock:
    """Basic block in control flow graph."""
    label: str
    instructions: Vec[QIRInstruction]
    terminator: QIRTerminator
    predecessors: Vec[str]
    successors: Vec[str]

struct QIRFunction:
    """Function in IR."""
    name: str
    params: Vec[Parameter]
    return_type: Option[Type]
    entry_block: QIRBasicBlock
    blocks: HashMap[str, QIRBasicBlock]
    local_vars: HashMap[str, Type]
    next_register: uint256

struct QIRContract:
    """Contract in IR."""
    name: str
    state_vars: Vec[StateVar]
    functions: Vec[QIRFunction]
    events: Vec[EventDecl]
    storage_layout: HashMap[str, uint256]

struct QIRModule:
    """Module in IR."""
    name: str
    contracts: Vec[QIRContract]
    functions: Vec[QIRFunction]

# ============================================================================
# IR Builder Errors
# ============================================================================

enum IRError:
    """IR builder error types."""
    InvalidExpression(message: str, location: SourceLocation)
    InvalidStatement(message: str, location: SourceLocation)
    UndefinedLabel(label: str)
    
    fn to_string() -> str:
        """Convert error to string."""
        match self:
            IRError.InvalidExpression(msg, loc):
                return f"Invalid expression: {msg} at {loc}"
            IRError.InvalidStatement(msg, loc):
                return f"Invalid statement: {msg} at {loc}"
            IRError.UndefinedLabel(label):
                return f"Undefined label: {label}"

# ============================================================================
# IR Builder
# ============================================================================

contract IRBuilder:
    """Builds intermediate representation from AST."""
    
    current_function: Option[QIRFunction]
    current_block: Option[QIRBasicBlock]
    blocks: HashMap[str, QIRBasicBlock]
    next_register: uint256
    next_label: uint256
    local_vars: HashMap[str, uint256]  # Variable name -> register
    
    @constructor
    fn __init__():
        """Create new IR builder."""
        self.current_function = Option.None
        self.current_block = Option.None
        self.blocks = HashMap[str, QIRBasicBlock]()
        self.next_register = 0
        self.next_label = 0
        self.local_vars = HashMap[str, uint256]()
    
    @external
    fn build(module: Module) -> Result[QIRModule, IRError]:
        """Build IR from AST module."""
        let mut qir_contracts = Vec[QIRContract]()
        let mut qir_functions = Vec[QIRFunction]()
        
        for item in module.items:
            match item:
                Item.Contract(contract):
                    qir_contracts.push(self.build_contract(contract)?)
                
                Item.Function(func):
                    qir_functions.push(self.build_function(func)?)
                
                _:
                    pass
        
        return Result.Ok(QIRModule(
            name: module.name,
            contracts: qir_contracts,
            functions: qir_functions
        ))
    
    @internal
    fn build_contract(contract: ContractDecl) -> Result[QIRContract, IRError]:
        """Build IR for contract."""
        let mut qir_functions = Vec[QIRFunction]()
        
        # Build storage layout
        let mut storage_layout = HashMap[str, uint256]()
        let mut next_slot: uint256 = 0
        
        for state_var in contract.state_vars:
            storage_layout.insert(state_var.name, next_slot)
            next_slot = next_slot + 1
        
        # Build functions
        for func in contract.functions:
            qir_functions.push(self.build_function(func)?)
        
        return Result.Ok(QIRContract(
            name: contract.name,
            state_vars: contract.state_vars,
            functions: qir_functions,
            events: contract.events,
            storage_layout: storage_layout
        ))
    
    @internal
    fn build_function(func: Function) -> Result[QIRFunction, IRError]:
        """Build IR for function."""
        # Reset builder state
        self.next_register = 0
        self.next_label = 0
        self.local_vars = HashMap[str, uint256]()
        self.blocks = HashMap[str, QIRBasicBlock]()
        
        # Create entry block
        let entry_block = self.create_block("entry")
        self.current_block = Option.Some(entry_block)
        
        # Allocate registers for parameters
        for param in func.params:
            let reg = self.new_register()
            self.local_vars.insert(param.name, reg)
        
        # Build function body
        for stmt in func.body:
            self.build_statement(stmt)?
        
        # Ensure block is terminated
        if not self.block_is_terminated():
            self.emit_terminator(QIRTerminator.Return(Option.None))
        
        return Result.Ok(QIRFunction(
            name: func.name,
            params: func.params,
            return_type: func.return_type,
            entry_block: entry_block,
            blocks: self.blocks,
            local_vars: HashMap[str, Type](),
            next_register: self.next_register
        ))
    
    @internal
    fn build_statement(stmt: Stmt) -> Result[(), IRError]:
        """Build IR for statement."""
        match stmt:
            Stmt.Let(name, ty, value, is_mutable, location):
                # Allocate register for variable
                let reg = self.new_register()
                self.local_vars.insert(name, reg)
                
                # Build initializer if present
                if value.is_some():
                    let value_reg = self.build_expression(value.unwrap())?
                    self.emit(QIRInstruction.Assign(reg, value_reg))
            
            Stmt.Assign(target, value, location):
                let value_reg = self.build_expression(value)?
                
                # Handle different assignment targets
                match target:
                    Expr.Ident(name, _):
                        let target_reg = self.local_vars.get(name).unwrap()
                        self.emit(QIRInstruction.Assign(target_reg, value_reg))
                    
                    Expr.Attribute(obj, attr, _):
                        # Handle storage assignment
                        # Simplified - full implementation would handle this properly
                        pass
                    
                    _:
                        return Result.Err(IRError.InvalidStatement(
                            "Invalid assignment target",
                            location
                        ))
            
            Stmt.If(condition, then_body, elif_branches, else_body, location):
                self.build_if_statement(condition, then_body, elif_branches, else_body)?
            
            Stmt.While(condition, body, location):
                self.build_while_statement(condition, body)?
            
            Stmt.Return(value, location):
                if value.is_some():
                    let value_reg = self.build_expression(value.unwrap())?
                    self.emit_terminator(QIRTerminator.Return(Option.Some(value_reg)))
                else:
                    self.emit_terminator(QIRTerminator.Return(Option.None))
            
            Stmt.ExprStmt(expr, location):
                self.build_expression(expr)?
            
            _:
                pass
        
        return Result.Ok(())
    
    @internal
    fn build_if_statement(
        condition: Expr,
        then_body: Vec[Stmt],
        elif_branches: Vec[(Expr, Vec[Stmt])],
        else_body: Option[Vec[Stmt]]
    ) -> Result[(), IRError]:
        """Build IR for if statement."""
        let cond_reg = self.build_expression(condition)?
        
        let then_label = self.new_label("then")
        let else_label = self.new_label("else")
        let merge_label = self.new_label("merge")
        
        # Emit branch
        self.emit_terminator(QIRTerminator.Branch(
            cond_reg,
            then_label,
            else_label
        ))
        
        # Build then block
        self.current_block = Option.Some(self.create_block(then_label))
        for stmt in then_body:
            self.build_statement(stmt)?
        if not self.block_is_terminated():
            self.emit_terminator(QIRTerminator.Jump(merge_label))
        
        # Build else block
        self.current_block = Option.Some(self.create_block(else_label))
        if else_body.is_some():
            for stmt in else_body.unwrap():
                self.build_statement(stmt)?
        if not self.block_is_terminated():
            self.emit_terminator(QIRTerminator.Jump(merge_label))
        
        # Continue at merge point
        self.current_block = Option.Some(self.create_block(merge_label))
        
        return Result.Ok(())
    
    @internal
    fn build_while_statement(condition: Expr, body: Vec[Stmt]) -> Result[(), IRError]:
        """Build IR for while loop."""
        let header_label = self.new_label("while_header")
        let body_label = self.new_label("while_body")
        let exit_label = self.new_label("while_exit")
        
        # Jump to header
        self.emit_terminator(QIRTerminator.Jump(header_label))
        
        # Build header (condition check)
        self.current_block = Option.Some(self.create_block(header_label))
        let cond_reg = self.build_expression(condition)?
        self.emit_terminator(QIRTerminator.Branch(
            cond_reg,
            body_label,
            exit_label
        ))
        
        # Build body
        self.current_block = Option.Some(self.create_block(body_label))
        for stmt in body:
            self.build_statement(stmt)?
        if not self.block_is_terminated():
            self.emit_terminator(QIRTerminator.Jump(header_label))
        
        # Continue at exit
        self.current_block = Option.Some(self.create_block(exit_label))
        
        return Result.Ok(())
    
    @internal
    fn build_expression(expr: Expr) -> Result[QIRValue, IRError]:
        """Build IR for expression and return value."""
        match expr:
            Expr.IntLit(value, location):
                return Result.Ok(QIRValue.Constant(value))
            
            Expr.Ident(name, location):
                let reg = self.local_vars.get(name)
                match reg:
                    Option.Some(r):
                        return Result.Ok(QIRValue.Register(r, Type.Unit))
                    Option.None:
                        return Result.Ok(QIRValue.GlobalVar(name))
            
            Expr.BinOp(left, op, right, location):
                let left_reg = self.build_expression(*left)?
                let right_reg = self.build_expression(*right)?
                let result_reg = self.new_register()
                
                match op:
                    BinOp.Add:
                        self.emit(QIRInstruction.Add(result_reg, left_reg, right_reg, true))
                    BinOp.Sub:
                        self.emit(QIRInstruction.Sub(result_reg, left_reg, right_reg, true))
                    BinOp.Mul:
                        self.emit(QIRInstruction.Mul(result_reg, left_reg, right_reg, true))
                    BinOp.Div:
                        self.emit(QIRInstruction.Div(result_reg, left_reg, right_reg, true))
                    BinOp.Mod:
                        self.emit(QIRInstruction.Mod(result_reg, left_reg, right_reg, true))
                    BinOp.Pow:
                        self.emit(QIRInstruction.Pow(result_reg, left_reg, right_reg, true))
                    BinOp.Eq:
                        self.emit(QIRInstruction.Eq(result_reg, left_reg, right_reg))
                    BinOp.Ne:
                        self.emit(QIRInstruction.Ne(result_reg, left_reg, right_reg))
                    BinOp.Lt:
                        self.emit(QIRInstruction.Lt(result_reg, left_reg, right_reg))
                    BinOp.Le:
                        self.emit(QIRInstruction.Le(result_reg, left_reg, right_reg))
                    BinOp.Gt:
                        self.emit(QIRInstruction.Gt(result_reg, left_reg, right_reg))
                    BinOp.Ge:
                        self.emit(QIRInstruction.Ge(result_reg, left_reg, right_reg))
                    BinOp.And:
                        self.emit(QIRInstruction.And(result_reg, left_reg, right_reg))
                    BinOp.Or:
                        self.emit(QIRInstruction.Or(result_reg, left_reg, right_reg))
                    _:
                        pass
                
                return Result.Ok(QIRValue.Register(result_reg, Type.Unit))
            
            Expr.UnaryOp(op, operand, location):
                let operand_reg = self.build_expression(*operand)?
                let result_reg = self.new_register()
                
                match op:
                    UnaryOp.Not:
                        self.emit(QIRInstruction.Not(result_reg, operand_reg))
                    _:
                        pass
                
                return Result.Ok(QIRValue.Register(result_reg, Type.Unit))
            
            Expr.Call(func, args, location):
                # Build arguments
                let mut arg_regs = Vec[QIRValue]()
                for arg in args:
                    arg_regs.push(self.build_expression(arg)?)
                
                # Get function name
                let func_name = match *func:
                    Expr.Ident(name, _):
                        name
                    _:
                        "unknown"
                
                let result_reg = self.new_register()
                self.emit(QIRInstruction.Call(Option.Some(result_reg), func_name, arg_regs))
                
                return Result.Ok(QIRValue.Register(result_reg, Type.Unit))
            
            _:
                return Result.Ok(QIRValue.Constant(0))
    
    @internal
    fn new_register() -> uint256:
        """Allocate new virtual register."""
        let reg = self.next_register
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
            successors: Vec[str]()
        )
        self.blocks.insert(label, block)
        return block
    
    @internal
    fn emit(instr: QIRInstruction):
        """Emit instruction to current block."""
        match self.current_block:
            Option.Some(block):
                block.instructions.push(instr)
            Option.None:
                pass
    
    @internal
    fn emit_terminator(term: QIRTerminator):
        """Emit terminator for current block."""
        match self.current_block:
            Option.Some(block):
                block.terminator = term
            Option.None:
                pass
    
    @internal
    fn block_is_terminated() -> bool:
        """Check if current block is terminated."""
        match self.current_block:
            Option.Some(block):
                match block.terminator:
                    QIRTerminator.Unreachable:
                        return false
                    _:
                        return true
            Option.None:
                return true

# ============================================================================
# Helper Functions
# ============================================================================

fn build_ir(module: Module) -> Result[QIRModule, IRError]:
    """Convenience function to build IR from module."""
    let builder = IRBuilder()
    return builder.build(module)
