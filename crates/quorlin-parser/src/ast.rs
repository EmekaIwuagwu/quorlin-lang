//! Abstract Syntax Tree definitions for Quorlin
//!
//! This module defines the structure of parsed Quorlin programs.

use serde::{Deserialize, Serialize};

/// A complete Quorlin source file
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct Module {
    pub items: Vec<Item>,
}

/// Top-level items in a Quorlin file
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub enum Item {
    Import(ImportStmt),
    Contract(ContractDecl),
    Struct(StructDecl),
    Enum(EnumDecl),
    Interface(InterfaceDecl),
    Event(EventDecl),
    Error(ErrorDecl),
}

/// Import statement: `from std.math import safe_add, safe_sub`
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ImportStmt {
    pub module: String,
    pub items: Vec<String>,
}

/// Contract declaration
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ContractDecl {
    pub name: String,
    pub bases: Vec<String>,
    pub body: Vec<ContractMember>,
    pub docstring: Option<String>,
}

/// Contract member (state variables, functions, etc.)
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub enum ContractMember {
    StateVar(StateVar),
    Function(Function),
    Constant(Constant),
}

/// State variable: `balances: mapping[address, uint256]`
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct StateVar {
    pub name: String,
    pub type_annotation: Type,
    pub initial_value: Option<Expr>,
}

/// Function definition
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct Function {
    pub name: String,
    pub decorators: Vec<String>,
    pub params: Vec<Param>,
    pub return_type: Option<Type>,
    pub body: Vec<Stmt>,
    pub docstring: Option<String>,
}

/// Function parameter
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct Param {
    pub name: String,
    pub type_annotation: Type,
    pub default: Option<Expr>,
}

/// Type annotation
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub enum Type {
    /// Simple type (bool, uint256, address, etc.)
    Simple(String),
    /// List type: list[T]
    List(Box<Type>),
    /// Fixed array: T[N]
    FixedArray(Box<Type>, usize),
    /// Mapping: mapping[K, V]
    Mapping(Box<Type>, Box<Type>),
    /// Optional: Optional[T]
    Optional(Box<Type>),
    /// Tuple: (T1, T2, ...)
    Tuple(Vec<Type>),
}

/// Statement
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub enum Stmt {
    Assign(AssignStmt),
    AugAssign(AugAssignStmt),
    Expr(Expr),
    Return(Option<Expr>),
    Pass,
    Break,
    Continue,
    If(IfStmt),
    For(ForStmt),
    While(WhileStmt),
    Require(RequireStmt),
    Revert(String),
    Emit(EmitStmt),
    Raise(RaiseStmt),
}

/// Assignment: `x = 10` or `x: uint256 = 10` or `self.balances[addr] = 100`
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct AssignStmt {
    pub target: Expr,
    pub type_annotation: Option<Type>,
    pub value: Expr,
}

/// Augmented assignment: `x += 10` (NOTE: Currently unused - parser desugars to Assign)
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct AugAssignStmt {
    pub target: String,
    pub op: AugAssignOp,
    pub value: Expr,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub enum AugAssignOp {
    Add,
    Sub,
    Mul,
    Div,
}

/// If statement
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct IfStmt {
    pub condition: Expr,
    pub then_branch: Vec<Stmt>,
    pub elif_branches: Vec<(Expr, Vec<Stmt>)>,
    pub else_branch: Option<Vec<Stmt>>,
}

/// For loop: `for i in range(10):`
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ForStmt {
    pub variable: String,
    pub iterable: Expr,
    pub body: Vec<Stmt>,
}

/// While loop
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct WhileStmt {
    pub condition: Expr,
    pub body: Vec<Stmt>,
}

/// Require statement: `require(condition, "message")`
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct RequireStmt {
    pub condition: Expr,
    pub message: Option<String>,
}

/// Emit statement: `emit Transfer(from, to, amount)`
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct EmitStmt {
    pub event: String,
    pub args: Vec<Expr>,
}

/// Raise statement: `raise InsufficientBalance(available, needed)`
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct RaiseStmt {
    pub error: String,
    pub args: Vec<Expr>,
}

/// Expression
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub enum Expr {
    /// Literal values
    IntLiteral(String),
    HexLiteral(String),
    StringLiteral(String),
    BoolLiteral(bool),
    NoneLiteral,

    /// Identifier
    Ident(String),

    /// Binary operation
    BinOp(Box<Expr>, BinOp, Box<Expr>),

    /// Unary operation
    UnaryOp(UnaryOp, Box<Expr>),

    /// Function call
    Call(Box<Expr>, Vec<Expr>),

    /// Attribute access: `self.balances`
    Attribute(Box<Expr>, String),

    /// Index access: `balances[owner]`
    Index(Box<Expr>, Box<Expr>),

    /// List literal: `[1, 2, 3]`
    List(Vec<Expr>),

    /// Tuple literal: `(1, 2, 3)`
    Tuple(Vec<Expr>),

    /// Ternary expression: `x if c else y`
    IfExp {
        test: Box<Expr>,
        body: Box<Expr>,
        orelse: Box<Expr>,
    },
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub enum BinOp {
    Add,
    Sub,
    Mul,
    Div,
    FloorDiv,
    Mod,
    Pow,
    Eq,
    NotEq,
    Lt,
    LtEq,
    Gt,
    GtEq,
    And,
    Or,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub enum UnaryOp {
    Not,
    Neg,
    Pos,
}

/// Struct declaration
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct StructDecl {
    pub name: String,
    pub fields: Vec<StructField>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct StructField {
    pub name: String,
    pub type_annotation: Type,
}

/// Enum declaration
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct EnumDecl {
    pub name: String,
    pub variants: Vec<String>,
}

/// Interface declaration
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct InterfaceDecl {
    pub name: String,
    pub functions: Vec<FunctionSignature>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct FunctionSignature {
    pub name: String,
    pub params: Vec<Param>,
    pub return_type: Option<Type>,
}

/// Event declaration
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct EventDecl {
    pub name: String,
    pub params: Vec<EventParam>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct EventParam {
    pub name: String,
    pub type_annotation: Type,
    pub indexed: bool,
}

/// Error declaration
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ErrorDecl {
    pub name: String,
    pub params: Vec<Param>,
}

/// Constant declaration
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct Constant {
    pub name: String,
    pub type_annotation: Type,
    pub value: Expr,
}
