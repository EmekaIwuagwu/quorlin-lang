# AST Definitions for Quorlin Compiler
# This file defines all Abstract Syntax Tree node types

from compiler.runtime.stdlib import Vec, HashMap, Option

# ============================================================================
# Source Location
# ============================================================================

struct SourceLocation:
    """Represents a location in source code."""
    file: str
    line: uint256
    column: uint256
    offset: uint256
    
    fn to_string() -> str:
        return f"{self.file}:{self.line}:{self.column}"

# ============================================================================
# Tokens
# ============================================================================

enum TokenKind:
    """Token types."""
    # Literals
    IntLiteral(value: uint256)
    StringLiteral(value: str)
    BoolLiteral(value: bool)
    
    # Identifiers and keywords
    Identifier
    Keyword(name: str)
    
    # Operators
    Operator(symbol: str)
    
    # Delimiters
    LeftParen      # (
    RightParen     # )
    LeftBracket    # [
    RightBracket   # ]
    LeftBrace      # {
    RightBrace     # }
    Colon          # :
    Comma          # ,
    Dot            # .
    Arrow          # ->
    
    # Indentation
    Indent(level: uint256)
    Dedent
    Newline
    
    # Special
    EOF

struct Token:
    """A lexical token."""
    kind: TokenKind
    lexeme: str
    location: SourceLocation
    
    fn to_string() -> str:
        return f"Token({self.kind}, '{self.lexeme}' at {self.location})"

# ============================================================================
# Types
# ============================================================================

enum Type:
    """Type representations."""
    # Primitive types
    Unit                                          # void/()
    Bool
    Int(width: uint256, signed: bool)            # uint256, int256, etc.
    Address
    Bytes(size: Option[uint256])                 # bytes32 or bytes
    String
    
    # Composite types
    Struct(name: str)
    Enum(name: str)
    Tuple(elements: Vec[Type])
    Array(element_ty: Box[Type], size: Option[uint256])
    Mapping(key_ty: Box[Type], value_ty: Box[Type])
    
    # Generic types
    Generic(name: str, type_params: Vec[Type])
    TypeParam(name: str)
    
    # Function types
    Function(params: Vec[Type], return_ty: Box[Type])
    
    # Reference types
    Ref(inner: Box[Type], is_mutable: bool)
    Box(inner: Box[Type])
    
    fn to_string() -> str:
        """Convert type to string representation."""
        # Implementation will be added
        return "Type"

# ============================================================================
# Expressions
# ============================================================================

enum Expr:
    """Expression AST nodes."""
    # Literals
    IntLit(value: uint256, location: SourceLocation)
    StringLit(value: str, location: SourceLocation)
    BoolLit(value: bool, location: SourceLocation)
    NoneLit(location: SourceLocation)
    
    # Identifiers
    Ident(name: str, location: SourceLocation)
    
    # Binary operations
    BinOp(
        left: Box[Expr],
        op: BinOp,
        right: Box[Expr],
        location: SourceLocation
    )
    
    # Unary operations
    UnaryOp(
        op: UnaryOp,
        operand: Box[Expr],
        location: SourceLocation
    )
    
    # Function calls
    Call(
        func: Box[Expr],
        args: Vec[Expr],
        location: SourceLocation
    )
    
    # Attribute access
    Attribute(
        obj: Box[Expr],
        attr: str,
        location: SourceLocation
    )
    
    # Index access
    Index(
        obj: Box[Expr],
        index: Box[Expr],
        location: SourceLocation
    )
    
    # List literal
    List(
        elements: Vec[Expr],
        location: SourceLocation
    )
    
    # Tuple literal
    Tuple(
        elements: Vec[Expr],
        location: SourceLocation
    )
    
    # Struct literal
    StructLit(
        name: str,
        fields: Vec[(str, Expr)],
        location: SourceLocation
    )
    
    # Match expression
    Match(
        value: Box[Expr],
        arms: Vec[MatchArm],
        location: SourceLocation
    )
    
    # Lambda/closure
    Lambda(
        params: Vec[Parameter],
        body: Box[Expr],
        location: SourceLocation
    )

struct MatchArm:
    """Match expression arm."""
    pattern: Pattern
    guard: Option[Expr]
    body: Expr

enum Pattern:
    """Pattern for match expressions."""
    Wildcard
    Literal(value: Expr)
    Ident(name: str)
    Tuple(patterns: Vec[Pattern])
    Struct(name: str, fields: Vec[(str, Pattern)])
    Enum(variant: str, data: Option[Box[Pattern]])

enum BinOp:
    """Binary operators."""
    # Arithmetic
    Add
    Sub
    Mul
    Div
    Mod
    Pow
    
    # Comparison
    Eq
    Ne
    Lt
    Le
    Gt
    Ge
    
    # Logical
    And
    Or
    
    # Bitwise
    BitAnd
    BitOr
    BitXor
    Shl
    Shr

enum UnaryOp:
    """Unary operators."""
    Neg      # -
    Not      # not
    BitNot   # ~

# ============================================================================
# Statements
# ============================================================================

enum Stmt:
    """Statement AST nodes."""
    # Variable declaration
    Let(
        name: str,
        ty: Option[Type],
        value: Option[Expr],
        is_mutable: bool,
        location: SourceLocation
    )
    
    # Assignment
    Assign(
        target: Expr,
        value: Expr,
        location: SourceLocation
    )
    
    # Expression statement
    ExprStmt(
        expr: Expr,
        location: SourceLocation
    )
    
    # If statement
    If(
        condition: Expr,
        then_body: Vec[Stmt],
        elif_branches: Vec[(Expr, Vec[Stmt])],
        else_body: Option[Vec[Stmt]],
        location: SourceLocation
    )
    
    # While loop
    While(
        condition: Expr,
        body: Vec[Stmt],
        location: SourceLocation
    )
    
    # For loop
    For(
        var: str,
        iterable: Expr,
        body: Vec[Stmt],
        location: SourceLocation
    )
    
    # Return statement
    Return(
        value: Option[Expr],
        location: SourceLocation
    )
    
    # Break statement
    Break(location: SourceLocation)
    
    # Continue statement
    Continue(location: SourceLocation)
    
    # Require statement
    Require(
        condition: Expr,
        message: str,
        location: SourceLocation
    )
    
    # Revert statement
    Revert(
        message: str,
        location: SourceLocation
    )
    
    # Emit event
    Emit(
        event: str,
        args: Vec[Expr],
        location: SourceLocation
    )
    
    # Pass statement (no-op)
    Pass(location: SourceLocation)

# ============================================================================
# Declarations
# ============================================================================

struct Parameter:
    """Function parameter."""
    name: str
    ty: Type
    is_mutable: bool
    default_value: Option[Expr]

struct Function:
    """Function declaration."""
    name: str
    params: Vec[Parameter]
    return_type: Option[Type]
    body: Vec[Stmt]
    decorators: Vec[str]
    docstring: Option[str]
    location: SourceLocation

struct StateVar:
    """Contract state variable."""
    name: str
    ty: Type
    visibility: Visibility
    is_constant: bool
    initial_value: Option[Expr]
    location: SourceLocation

enum Visibility:
    """Visibility modifiers."""
    Public
    Private
    Internal
    External

struct EventDecl:
    """Event declaration."""
    name: str
    params: Vec[EventParam]
    location: SourceLocation

struct EventParam:
    """Event parameter."""
    name: str
    ty: Type
    indexed: bool

struct ErrorDecl:
    """Custom error declaration."""
    name: str
    params: Vec[Parameter]
    location: SourceLocation

struct StructDecl:
    """Struct declaration."""
    name: str
    fields: Vec[StructField]
    docstring: Option[str]
    location: SourceLocation

struct StructField:
    """Struct field."""
    name: str
    ty: Type

struct EnumDecl:
    """Enum declaration."""
    name: str
    variants: Vec[EnumVariant]
    docstring: Option[str]
    location: SourceLocation

struct EnumVariant:
    """Enum variant."""
    name: str
    data: Option[Type]

struct InterfaceDecl:
    """Interface declaration."""
    name: str
    functions: Vec[FunctionSignature]
    location: SourceLocation

struct FunctionSignature:
    """Function signature (for interfaces)."""
    name: str
    params: Vec[Parameter]
    return_type: Option[Type]
    decorators: Vec[str]

struct ContractDecl:
    """Contract declaration."""
    name: str
    bases: Vec[str]  # Inherited contracts/interfaces
    state_vars: Vec[StateVar]
    functions: Vec[Function]
    events: Vec[EventDecl]
    errors: Vec[ErrorDecl]
    docstring: Option[str]
    location: SourceLocation

struct ImportStmt:
    """Import statement."""
    module: str  # e.g., "std.math"
    items: Vec[str]  # e.g., ["safe_add", "safe_sub"]
    location: SourceLocation

# ============================================================================
# Top-Level Items
# ============================================================================

enum Item:
    """Top-level items in a module."""
    Import(ImportStmt)
    Contract(ContractDecl)
    Struct(StructDecl)
    Enum(EnumDecl)
    Interface(InterfaceDecl)
    Event(EventDecl)
    Error(ErrorDecl)
    Function(Function)  # Free function
    Constant(StateVar)  # Module-level constant

struct Module:
    """A Quorlin module (file)."""
    name: str
    items: Vec[Item]
    docstring: Option[str]
    
    fn to_string() -> str:
        return f"Module({self.name}, {len(self.items)} items)"

# ============================================================================
# Helper Functions
# ============================================================================

fn make_int_lit(value: uint256, location: SourceLocation) -> Expr:
    """Create an integer literal expression."""
    return Expr.IntLit(value, location)

fn make_string_lit(value: str, location: SourceLocation) -> Expr:
    """Create a string literal expression."""
    return Expr.StringLit(value, location)

fn make_bool_lit(value: bool, location: SourceLocation) -> Expr:
    """Create a boolean literal expression."""
    return Expr.BoolLit(value, location)

fn make_ident(name: str, location: SourceLocation) -> Expr:
    """Create an identifier expression."""
    return Expr.Ident(name, location)

fn make_binop(left: Expr, op: BinOp, right: Expr, location: SourceLocation) -> Expr:
    """Create a binary operation expression."""
    return Expr.BinOp(Box.new(left), op, Box.new(right), location)

fn make_call(func: Expr, args: Vec[Expr], location: SourceLocation) -> Expr:
    """Create a function call expression."""
    return Expr.Call(Box.new(func), args, location)

# ============================================================================
# AST Visitor Pattern (for traversal)
# ============================================================================

trait ExprVisitor[T]:
    """Visitor pattern for expressions."""
    fn visit_int_lit(value: uint256, location: SourceLocation) -> T
    fn visit_string_lit(value: str, location: SourceLocation) -> T
    fn visit_bool_lit(value: bool, location: SourceLocation) -> T
    fn visit_ident(name: str, location: SourceLocation) -> T
    fn visit_binop(left: Expr, op: BinOp, right: Expr, location: SourceLocation) -> T
    fn visit_call(func: Expr, args: Vec[Expr], location: SourceLocation) -> T
    # ... other visit methods

trait StmtVisitor[T]:
    """Visitor pattern for statements."""
    fn visit_let(name: str, ty: Option[Type], value: Option[Expr], location: SourceLocation) -> T
    fn visit_assign(target: Expr, value: Expr, location: SourceLocation) -> T
    fn visit_if(condition: Expr, then_body: Vec[Stmt], else_body: Option[Vec[Stmt]], location: SourceLocation) -> T
    fn visit_return(value: Option[Expr], location: SourceLocation) -> T
    # ... other visit methods
