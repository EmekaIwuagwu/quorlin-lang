# Quorlin Semantic Analyzer
# Type checking, name resolution, and semantic validation

from compiler.runtime.stdlib import Vec, HashMap, Option, Result
from compiler.frontend.ast import *

# ============================================================================
# Semantic Errors
# ============================================================================

enum SemanticError:
    """Semantic analysis error types."""
    UndefinedVariable(name: str, location: SourceLocation)
    UndefinedFunction(name: str, location: SourceLocation)
    UndefinedType(name: str, location: SourceLocation)
    TypeMismatch(expected: Type, found: Type, location: SourceLocation)
    InvalidOperation(op: str, left: Type, right: Type, location: SourceLocation)
    DuplicateDefinition(name: str, location: SourceLocation)
    InvalidAssignment(target: str, location: SourceLocation)
    WrongNumberOfArguments(expected: uint256, found: uint256, location: SourceLocation)
    NotCallable(ty: Type, location: SourceLocation)
    CannotIndex(ty: Type, location: SourceLocation)
    NoSuchAttribute(ty: Type, attr: str, location: SourceLocation)
    InvalidReturnType(expected: Option[Type], found: Type, location: SourceLocation)
    BreakOutsideLoop(location: SourceLocation)
    ContinueOutsideLoop(location: SourceLocation)
    
    fn to_string() -> str:
        """Convert error to string."""
        match self:
            SemanticError.UndefinedVariable(name, loc):
                return f"Undefined variable '{name}' at {loc}"
            SemanticError.TypeMismatch(expected, found, loc):
                return f"Type mismatch: expected {expected}, found {found} at {loc}"
            SemanticError.DuplicateDefinition(name, loc):
                return f"Duplicate definition of '{name}' at {loc}"
            _:
                return "Semantic error"

# ============================================================================
# Symbol Table
# ============================================================================

enum SymbolKind:
    """Kind of symbol."""
    Variable(ty: Type, is_mutable: bool)
    Function(params: Vec[Type], return_type: Option[Type])
    Type(ty: Type)
    Contract(name: str)
    Module(name: str)

struct Symbol:
    """Symbol in symbol table."""
    name: str
    kind: SymbolKind
    location: SourceLocation

contract Scope:
    """Lexical scope for name resolution."""
    
    symbols: HashMap[str, Symbol]
    parent: Option[Box[Scope]]
    
    @constructor
    fn __init__(parent: Option[Box[Scope]]):
        """Create new scope."""
        self.symbols = HashMap[str, Symbol]()
        self.parent = parent
    
    @external
    fn define(name: str, symbol: Symbol) -> Result[(), SemanticError]:
        """Define a symbol in this scope."""
        if self.symbols.contains(name):
            return Result.Err(SemanticError.DuplicateDefinition(name, symbol.location))
        
        self.symbols.insert(name, symbol)
        return Result.Ok(())
    
    @view
    fn lookup(name: str) -> Option[Symbol]:
        """Look up a symbol in this scope or parent scopes."""
        # Check this scope
        let result = self.symbols.get(name)
        if result.is_some():
            return result
        
        # Check parent scope
        match self.parent:
            Option.Some(parent_scope):
                return parent_scope.lookup(name)
            Option.None:
                return Option.None
    
    @view
    fn lookup_local(name: str) -> Option[Symbol]:
        """Look up a symbol only in this scope."""
        return self.symbols.get(name)

# ============================================================================
# Type Environment
# ============================================================================

contract TypeEnvironment:
    """Tracks type information during analysis."""
    
    expr_types: HashMap[uint256, Type]  # Expression ID -> Type
    next_expr_id: uint256
    
    @constructor
    fn __init__():
        """Create new type environment."""
        self.expr_types = HashMap[uint256, Type]()
        self.next_expr_id = 0
    
    @external
    fn register_expr(expr: Expr, ty: Type) -> uint256:
        """Register expression type and return ID."""
        let id = self.next_expr_id
        self.next_expr_id = self.next_expr_id + 1
        self.expr_types.insert(id, ty)
        return id
    
    @view
    fn get_type(expr_id: uint256) -> Option[Type]:
        """Get type of expression."""
        return self.expr_types.get(expr_id)

# ============================================================================
# Semantic Analyzer
# ============================================================================

contract SemanticAnalyzer:
    """Performs semantic analysis on AST."""
    
    current_scope: Box[Scope]
    type_env: TypeEnvironment
    current_function_return_type: Option[Type]
    in_loop: bool
    errors: Vec[SemanticError]
    
    @constructor
    fn __init__():
        """Create new semantic analyzer."""
        self.current_scope = Box.new(Scope(Option.None))
        self.type_env = TypeEnvironment()
        self.current_function_return_type = Option.None
        self.in_loop = false
        self.errors = Vec[SemanticError]()
    
    @external
    fn analyze(module: Module) -> Result[Module, Vec[SemanticError]]:
        """Analyze a module."""
        # First pass: collect all top-level definitions
        for item in module.items:
            self.collect_item(item)?
        
        # Second pass: type check everything
        for item in module.items:
            self.check_item(item)?
        
        if self.errors.len() > 0:
            return Result.Err(self.errors)
        
        return Result.Ok(module)
    
    @internal
    fn collect_item(item: Item) -> Result[(), SemanticError]:
        """Collect top-level item definition."""
        match item:
            Item.Contract(contract):
                self.current_scope.define(
                    contract.name,
                    Symbol(
                        name: contract.name,
                        kind: SymbolKind.Contract(contract.name),
                        location: contract.location
                    )
                )?
            
            Item.Function(func):
                let param_types = Vec[Type]()
                for param in func.params:
                    param_types.push(param.ty)
                
                self.current_scope.define(
                    func.name,
                    Symbol(
                        name: func.name,
                        kind: SymbolKind.Function(param_types, func.return_type),
                        location: func.location
                    )
                )?
            
            Item.Struct(struct_decl):
                self.current_scope.define(
                    struct_decl.name,
                    Symbol(
                        name: struct_decl.name,
                        kind: SymbolKind.Type(Type.Struct(struct_decl.name)),
                        location: struct_decl.location
                    )
                )?
            
            Item.Enum(enum_decl):
                self.current_scope.define(
                    enum_decl.name,
                    Symbol(
                        name: enum_decl.name,
                        kind: SymbolKind.Type(Type.Enum(enum_decl.name)),
                        location: enum_decl.location
                    )
                )?
            
            _:
                pass
        
        return Result.Ok(())
    
    @internal
    fn check_item(item: Item) -> Result[(), SemanticError]:
        """Type check an item."""
        match item:
            Item.Contract(contract):
                return self.check_contract(contract)
            
            Item.Function(func):
                return self.check_function(func)
            
            _:
                return Result.Ok(())
    
    @internal
    fn check_contract(contract: ContractDecl) -> Result[(), SemanticError]:
        """Type check a contract."""
        # Create new scope for contract
        self.push_scope()
        
        # Add state variables to scope
        for state_var in contract.state_vars:
            self.current_scope.define(
                state_var.name,
                Symbol(
                    name: state_var.name,
                    kind: SymbolKind.Variable(state_var.ty, not state_var.is_constant),
                    location: state_var.location
                )
            )?
        
        # Check functions
        for func in contract.functions:
            self.check_function(func)?
        
        self.pop_scope()
        return Result.Ok(())
    
    @internal
    fn check_function(func: Function) -> Result[(), SemanticError]:
        """Type check a function."""
        # Create new scope for function
        self.push_scope()
        
        # Add parameters to scope
        for param in func.params:
            self.current_scope.define(
                param.name,
                Symbol(
                    name: param.name,
                    kind: SymbolKind.Variable(param.ty, param.is_mutable),
                    location: func.location
                )
            )?
        
        # Set current function return type
        self.current_function_return_type = func.return_type
        
        # Check function body
        for stmt in func.body:
            self.check_statement(stmt)?
        
        self.pop_scope()
        return Result.Ok(())
    
    @internal
    fn check_statement(stmt: Stmt) -> Result[(), SemanticError]:
        """Type check a statement."""
        match stmt:
            Stmt.Let(name, ty_annotation, value, is_mutable, location):
                # Check initializer if present
                let mut var_type = ty_annotation
                
                if value.is_some():
                    let init_type = self.check_expression(value.unwrap())?
                    
                    if var_type.is_some():
                        # Check type matches annotation
                        if not self.types_compatible(var_type.unwrap(), init_type):
                            return Result.Err(SemanticError.TypeMismatch(
                                var_type.unwrap(),
                                init_type,
                                location
                            ))
                    else:
                        # Infer type from initializer
                        var_type = Option.Some(init_type)
                
                # Add variable to scope
                self.current_scope.define(
                    name,
                    Symbol(
                        name: name,
                        kind: SymbolKind.Variable(var_type.unwrap(), is_mutable),
                        location: location
                    )
                )?
            
            Stmt.Assign(target, value, location):
                let target_type = self.check_expression(target)?
                let value_type = self.check_expression(value)?
                
                if not self.types_compatible(target_type, value_type):
                    return Result.Err(SemanticError.TypeMismatch(
                        target_type,
                        value_type,
                        location
                    ))
            
            Stmt.If(condition, then_body, elif_branches, else_body, location):
                # Check condition is boolean
                let cond_type = self.check_expression(condition)?
                if not self.is_bool_type(cond_type):
                    return Result.Err(SemanticError.TypeMismatch(
                        Type.Bool,
                        cond_type,
                        location
                    ))
                
                # Check then body
                self.push_scope()
                for stmt in then_body:
                    self.check_statement(stmt)?
                self.pop_scope()
                
                # Check elif branches
                for (elif_cond, elif_body) in elif_branches:
                    let elif_cond_type = self.check_expression(elif_cond)?
                    if not self.is_bool_type(elif_cond_type):
                        return Result.Err(SemanticError.TypeMismatch(
                            Type.Bool,
                            elif_cond_type,
                            location
                        ))
                    
                    self.push_scope()
                    for stmt in elif_body:
                        self.check_statement(stmt)?
                    self.pop_scope()
                
                # Check else body
                if else_body.is_some():
                    self.push_scope()
                    for stmt in else_body.unwrap():
                        self.check_statement(stmt)?
                    self.pop_scope()
            
            Stmt.While(condition, body, location):
                # Check condition
                let cond_type = self.check_expression(condition)?
                if not self.is_bool_type(cond_type):
                    return Result.Err(SemanticError.TypeMismatch(
                        Type.Bool,
                        cond_type,
                        location
                    ))
                
                # Check body
                self.push_scope()
                let old_in_loop = self.in_loop
                self.in_loop = true
                
                for stmt in body:
                    self.check_statement(stmt)?
                
                self.in_loop = old_in_loop
                self.pop_scope()
            
            Stmt.Return(value, location):
                if value.is_some():
                    let return_type = self.check_expression(value.unwrap())?
                    
                    match self.current_function_return_type:
                        Option.Some(expected_type):
                            if not self.types_compatible(expected_type, return_type):
                                return Result.Err(SemanticError.InvalidReturnType(
                                    self.current_function_return_type,
                                    return_type,
                                    location
                                ))
                        Option.None:
                            return Result.Err(SemanticError.InvalidReturnType(
                                Option.None,
                                return_type,
                                location
                            ))
                else:
                    if self.current_function_return_type.is_some():
                        return Result.Err(SemanticError.InvalidReturnType(
                            self.current_function_return_type,
                            Type.Unit,
                            location
                        ))
            
            Stmt.Break(location):
                if not self.in_loop:
                    return Result.Err(SemanticError.BreakOutsideLoop(location))
            
            Stmt.Continue(location):
                if not self.in_loop:
                    return Result.Err(SemanticError.ContinueOutsideLoop(location))
            
            Stmt.ExprStmt(expr, location):
                self.check_expression(expr)?
            
            _:
                pass
        
        return Result.Ok(())
    
    @internal
    fn check_expression(expr: Expr) -> Result[Type, SemanticError]:
        """Type check an expression and return its type."""
        match expr:
            Expr.IntLit(value, location):
                return Result.Ok(Type.Int(256, false))
            
            Expr.StringLit(value, location):
                return Result.Ok(Type.String)
            
            Expr.BoolLit(value, location):
                return Result.Ok(Type.Bool)
            
            Expr.NoneLit(location):
                return Result.Ok(Type.Unit)
            
            Expr.Ident(name, location):
                let symbol = self.current_scope.lookup(name)
                match symbol:
                    Option.Some(sym):
                        match sym.kind:
                            SymbolKind.Variable(ty, _):
                                return Result.Ok(ty)
                            _:
                                return Result.Err(SemanticError.UndefinedVariable(name, location))
                    Option.None:
                        return Result.Err(SemanticError.UndefinedVariable(name, location))
            
            Expr.BinOp(left, op, right, location):
                let left_type = self.check_expression(*left)?
                let right_type = self.check_expression(*right)?
                
                return self.check_binary_op(op, left_type, right_type, location)
            
            Expr.UnaryOp(op, operand, location):
                let operand_type = self.check_expression(*operand)?
                
                match op:
                    UnaryOp.Neg:
                        if self.is_numeric_type(operand_type):
                            return Result.Ok(operand_type)
                        return Result.Err(SemanticError.InvalidOperation(
                            "negation",
                            operand_type,
                            Type.Unit,
                            location
                        ))
                    
                    UnaryOp.Not:
                        if self.is_bool_type(operand_type):
                            return Result.Ok(Type.Bool)
                        return Result.Err(SemanticError.TypeMismatch(
                            Type.Bool,
                            operand_type,
                            location
                        ))
                    
                    _:
                        return Result.Ok(operand_type)
            
            Expr.Call(func, args, location):
                let func_type = self.check_expression(*func)?
                
                # Check if callable
                # For now, assume functions are defined in scope
                # Full implementation would check function signatures
                
                # Check arguments
                for arg in args:
                    self.check_expression(arg)?
                
                # Return type depends on function
                # For now, return Unit
                return Result.Ok(Type.Unit)
            
            Expr.Attribute(obj, attr, location):
                let obj_type = self.check_expression(*obj)?
                
                # Check if object has attribute
                # Full implementation would check struct/contract fields
                
                return Result.Ok(Type.Unit)
            
            Expr.Index(obj, index, location):
                let obj_type = self.check_expression(*obj)?
                let index_type = self.check_expression(*index)?
                
                # Check if indexable
                match obj_type:
                    Type.Array(element_ty, _):
                        return Result.Ok(*element_ty)
                    Type.Mapping(key_ty, value_ty):
                        if self.types_compatible(*key_ty, index_type):
                            return Result.Ok(*value_ty)
                        return Result.Err(SemanticError.TypeMismatch(
                            *key_ty,
                            index_type,
                            location
                        ))
                    _:
                        return Result.Err(SemanticError.CannotIndex(obj_type, location))
            
            _:
                return Result.Ok(Type.Unit)
    
    @internal
    fn check_binary_op(op: BinOp, left: Type, right: Type, location: SourceLocation) -> Result[Type, SemanticError]:
        """Check binary operation and return result type."""
        match op:
            BinOp.Add | BinOp.Sub | BinOp.Mul | BinOp.Div | BinOp.Mod | BinOp.Pow:
                if self.is_numeric_type(left) and self.is_numeric_type(right):
                    return Result.Ok(left)
                return Result.Err(SemanticError.InvalidOperation(
                    "arithmetic",
                    left,
                    right,
                    location
                ))
            
            BinOp.Eq | BinOp.Ne | BinOp.Lt | BinOp.Le | BinOp.Gt | BinOp.Ge:
                if self.types_compatible(left, right):
                    return Result.Ok(Type.Bool)
                return Result.Err(SemanticError.TypeMismatch(left, right, location))
            
            BinOp.And | BinOp.Or:
                if self.is_bool_type(left) and self.is_bool_type(right):
                    return Result.Ok(Type.Bool)
                return Result.Err(SemanticError.TypeMismatch(Type.Bool, left, location))
            
            _:
                return Result.Ok(Type.Unit)
    
    @internal
    fn types_compatible(ty1: Type, ty2: Type) -> bool:
        """Check if two types are compatible."""
        # Simplified type compatibility check
        # Full implementation would handle subtyping, generics, etc.
        return ty1 == ty2
    
    @internal
    fn is_numeric_type(ty: Type) -> bool:
        """Check if type is numeric."""
        match ty:
            Type.Int(_, _):
                return true
            _:
                return false
    
    @internal
    fn is_bool_type(ty: Type) -> bool:
        """Check if type is boolean."""
        match ty:
            Type.Bool:
                return true
            _:
                return false
    
    @internal
    fn push_scope():
        """Push a new scope."""
        let new_scope = Scope(Option.Some(self.current_scope))
        self.current_scope = Box.new(new_scope)
    
    @internal
    fn pop_scope():
        """Pop current scope."""
        match self.current_scope.parent:
            Option.Some(parent):
                self.current_scope = parent
            Option.None:
                pass

# ============================================================================
# Helper Functions
# ============================================================================

fn analyze_module(module: Module) -> Result[Module, Vec[SemanticError]]:
    """Convenience function to analyze a module."""
    let analyzer = SemanticAnalyzer()
    return analyzer.analyze(module)
