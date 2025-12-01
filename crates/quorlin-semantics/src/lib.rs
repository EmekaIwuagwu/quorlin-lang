//! # Quorlin Semantics
//!
//! Semantic analysis for the Quorlin compiler.
//!
//! This crate performs:
//! - Name resolution and scope analysis
//! - Type checking and inference
//! - Semantic validation (decorators, access control, etc.)

pub mod symbol_table;
pub mod type_checker;
pub mod validator;

use quorlin_parser::{Module, Type};
use std::collections::HashMap;

/// Semantic analysis errors
#[derive(Debug, thiserror::Error)]
pub enum SemanticError {
    #[error("Undefined variable: {0}")]
    UndefinedVariable(String),

    #[error("Undefined function: {0}")]
    UndefinedFunction(String),

    #[error("Undefined type: {0}")]
    UndefinedType(String),

    #[error("Duplicate definition: {0}")]
    DuplicateDefinition(String),

    #[error("Type mismatch: expected {expected}, found {found}")]
    TypeMismatch { expected: String, found: String },

    #[error("Invalid decorator: {0} cannot be used on {1}")]
    InvalidDecorator(String, String),

    #[error("{0}")]
    ValidationError(String),
}

/// Result type for semantic analysis
pub type SemanticResult<T> = Result<T, SemanticError>;

/// Semantic analyzer for Quorlin modules
pub struct SemanticAnalyzer {
    /// Symbol table for tracking definitions
    symbols: symbol_table::SymbolTable,

    /// Type environment (reserved for future type inference)
    _type_env: HashMap<String, Type>,
}

impl SemanticAnalyzer {
    /// Create a new semantic analyzer
    pub fn new() -> Self {
        Self {
            symbols: symbol_table::SymbolTable::new(),
            _type_env: HashMap::new(),
        }
    }

    /// Analyze a module
    pub fn analyze(&mut self, module: &Module) -> SemanticResult<()> {
        // First pass: collect all top-level definitions
        for item in &module.items {
            self.collect_definitions(item)?;
        }

        // Second pass: type check and validate
        for item in &module.items {
            self.check_item(item)?;
        }

        Ok(())
    }

    fn collect_definitions(&mut self, item: &quorlin_parser::Item) -> SemanticResult<()> {
        use quorlin_parser::Item;

        match item {
            Item::Import(_) => {
                // TODO: Handle imports (for now, just skip)
                Ok(())
            }
            Item::Event(event) => {
                self.symbols.define_event(&event.name)?;
                Ok(())
            }
            Item::Contract(contract) => {
                self.symbols.define_contract(&contract.name)?;
                // Collect contract members
                self.symbols.enter_scope();
                for member in &contract.body {
                    self.collect_contract_member(member)?;
                }
                self.symbols.exit_scope();
                Ok(())
            }
            _ => Ok(()),
        }
    }

    fn collect_contract_member(
        &mut self,
        member: &quorlin_parser::ContractMember,
    ) -> SemanticResult<()> {
        use quorlin_parser::ContractMember;

        match member {
            ContractMember::StateVar(var) => {
                self.symbols.define_variable(&var.name, &var.type_annotation)?;
                Ok(())
            }
            ContractMember::Function(func) => {
                self.symbols.define_function(&func.name)?;
                Ok(())
            }
            _ => Ok(()),
        }
    }

    fn check_item(&mut self, item: &quorlin_parser::Item) -> SemanticResult<()> {
        use quorlin_parser::Item;

        match item {
            Item::Contract(contract) => {
                self.symbols.enter_scope();

                // Check each member
                for member in &contract.body {
                    self.check_contract_member(member)?;
                }

                self.symbols.exit_scope();
                Ok(())
            }
            _ => Ok(()),
        }
    }

    fn check_contract_member(
        &mut self,
        member: &quorlin_parser::ContractMember,
    ) -> SemanticResult<()> {
        use quorlin_parser::ContractMember;

        match member {
            ContractMember::Function(func) => {
                // Validate decorators
                for decorator in &func.decorators {
                    validator::validate_decorator(decorator, "function")?;
                }

                // Enter function scope
                self.symbols.enter_scope();

                // Add parameters to scope
                for param in &func.params {
                    self.symbols.define_variable(&param.name, &param.type_annotation)?;
                }

                // Check function body
                for stmt in &func.body {
                    self.check_statement(stmt)?;
                }

                self.symbols.exit_scope();
                Ok(())
            }
            _ => Ok(()),
        }
    }

    fn check_statement(&mut self, stmt: &quorlin_parser::Stmt) -> SemanticResult<()> {
        use quorlin_parser::Stmt;

        match stmt {
            Stmt::Assign(assign) => {
                // Check that the value expression type-checks
                let _value_type = self.check_expression(&assign.value)?;
                // TODO: Check assignment compatibility
                Ok(())
            }
            Stmt::Return(ret) => {
                if let Some(value) = ret {
                    let _return_type = self.check_expression(value)?;
                    // TODO: Check return type matches function signature
                }
                Ok(())
            }
            Stmt::Emit(emit) => {
                // Check that event is defined
                if !self.symbols.is_event_defined(&emit.event) {
                    return Err(SemanticError::UndefinedFunction(emit.event.clone()));
                }
                // Check arguments
                for arg in &emit.args {
                    self.check_expression(arg)?;
                }
                Ok(())
            }
            Stmt::Require(req) => {
                // Check condition is boolean-like
                let _cond_type = self.check_expression(&req.condition)?;
                // TODO: Validate condition type
                Ok(())
            }
            Stmt::Pass => Ok(()),
            _ => Ok(()),
        }
    }

    fn check_expression(&mut self, expr: &quorlin_parser::Expr) -> SemanticResult<Type> {
        use quorlin_parser::Expr;

        match expr {
            Expr::IntLiteral(_) => Ok(Type::Simple("uint256".to_string())),
            Expr::StringLiteral(_) => Ok(Type::Simple("str".to_string())),
            Expr::BoolLiteral(_) => Ok(Type::Simple("bool".to_string())),
            Expr::NoneLiteral => Ok(Type::Simple("None".to_string())),
            Expr::Ident(name) => {
                if let Some(ty) = self.symbols.lookup_variable(name) {
                    Ok(ty.clone())
                } else {
                    // Might be a function call or type constructor
                    Ok(Type::Simple("unknown".to_string()))
                }
            }
            Expr::BinOp(left, _op, right) => {
                let _left_type = self.check_expression(left)?;
                let _right_type = self.check_expression(right)?;
                // TODO: Type checking for binary operations
                Ok(Type::Simple("uint256".to_string()))
            }
            Expr::Call(func, args) => {
                self.check_expression(func)?;
                for arg in args {
                    self.check_expression(arg)?;
                }
                // TODO: Function type inference
                Ok(Type::Simple("unknown".to_string()))
            }
            Expr::Attribute(base, _attr) => {
                let _base_type = self.check_expression(base)?;
                // TODO: Attribute type lookup
                Ok(Type::Simple("unknown".to_string()))
            }
            Expr::Index(base, index) => {
                let _base_type = self.check_expression(base)?;
                let _index_type = self.check_expression(index)?;
                // TODO: Index type checking
                Ok(Type::Simple("unknown".to_string()))
            }
            _ => Ok(Type::Simple("unknown".to_string())),
        }
    }
}

impl Default for SemanticAnalyzer {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_semantic_analyzer_creation() {
        let _analyzer = SemanticAnalyzer::new();
    }
}
