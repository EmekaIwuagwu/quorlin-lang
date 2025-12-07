//! Type Checker
//!
//! Performs type checking on Quorlin AST

use quorlin_parser::ast::*;
use std::collections::HashMap;

pub struct TypeChecker {
    /// Type environment (variable name -> type)
    type_env: HashMap<String, Type>,
    
    /// Function signatures
    functions: HashMap<String, FunctionSignature>,
    
    /// Current contract context
    current_contract: Option<String>,
    
    /// Errors collected during type checking
    errors: Vec<String>,
}

#[derive(Debug, Clone)]
struct FunctionSignature {
    params: Vec<(String, Type)>,
    return_type: Option<Type>,
}

impl TypeChecker {
    pub fn new() -> Self {
        Self {
            type_env: HashMap::new(),
            functions: HashMap::new(),
            current_contract: None,
            errors: Vec::new(),
        }
    }
    
    pub fn check(&mut self, module: &Module) -> Result<(), Vec<String>> {
        self.errors.clear();
        
        // First pass: collect all function signatures
        for item in &module.items {
            if let Item::Contract(contract) = item {
                self.collect_signatures(contract);
            }
        }
        
        // Second pass: type check all items
        for item in &module.items {
            self.check_item(item);
        }
        
        if self.errors.is_empty() {
            Ok(())
        } else {
            Err(self.errors.clone())
        }
    }
    
    fn collect_signatures(&mut self, contract: &ContractDecl) {
        self.current_contract = Some(contract.name.clone());
        
        for member in &contract.body {
            if let ContractMember::Function(func) = member {
                let params = func.params.iter()
                    .map(|p| (p.name.clone(), p.type_annotation.clone()))
                    .collect();
                
                let sig = FunctionSignature {
                    params,
                    return_type: func.return_type.clone(),
                };
                
                let full_name = format!("{}.{}", contract.name, func.name);
                self.functions.insert(full_name, sig);
            }
        }
    }
    
    fn check_item(&mut self, item: &Item) {
        match item {
            Item::Contract(contract) => self.check_contract(contract),
            _ => {}, // Other items don't need checking
        }
    }
    
    fn check_contract(&mut self, contract: &ContractDecl) {
        self.current_contract = Some(contract.name.clone());
        
        // Check state variables
        for member in &contract.body {
            if let ContractMember::StateVar(var) = member {
                self.type_env.insert(var.name.clone(), var.type_annotation.clone());
            }
        }
        
        // Check functions
        for member in &contract.body {
            if let ContractMember::Function(func) = member {
                self.check_function(func);
            }
        }
    }
    
    fn check_function(&mut self, func: &Function) {
        // Add parameters to type environment
        for param in &func.params {
            self.type_env.insert(param.name.clone(), param.type_annotation.clone());
        }
        
        // Check function body
        for stmt in &func.body {
            self.check_statement(stmt);
        }
        
        // Check return type
        if let Some(_return_type) = &func.return_type {
            if !self.has_return_statement(&func.body) {
                self.errors.push(format!(
                    "Function '{}' declares return type but has no return statement",
                    func.name
                ));
            }
        }
    }
    
    fn check_statement(&mut self, stmt: &Stmt) {
        match stmt {
            Stmt::Assign(assign) => {
                let target_type = self.infer_type(&assign.target);
                let value_type = self.infer_type(&assign.value);
                
                if !self.types_compatible(&value_type, &target_type) {
                    self.errors.push(format!(
                        "Type mismatch in assignment: cannot assign {:?} to {:?}",
                        value_type, target_type
                    ));
                }
            }
            
            Stmt::Return(Some(expr)) => {
                let _ = self.infer_type(expr);
            }
            
            Stmt::If(if_stmt) => {
                let cond_type = self.infer_type(&if_stmt.condition);
                if !matches!(cond_type, Type::Simple(ref s) if s == "bool") {
                    self.errors.push(format!(
                        "If condition must be boolean, got {:?}",
                        cond_type
                    ));
                }
                
                for stmt in &if_stmt.then_branch {
                    self.check_statement(stmt);
                }
                
                if let Some(else_stmts) = &if_stmt.else_branch {
                    for stmt in else_stmts {
                        self.check_statement(stmt);
                    }
                }
            }
            
            Stmt::While(while_stmt) => {
                let cond_type = self.infer_type(&while_stmt.condition);
                if !matches!(cond_type, Type::Simple(ref s) if s == "bool") {
                    self.errors.push(format!(
                        "While condition must be boolean, got {:?}",
                        cond_type
                    ));
                }
                
                for stmt in &while_stmt.body {
                    self.check_statement(stmt);
                }
            }
            
            Stmt::For(for_stmt) => {
                for stmt in &for_stmt.body {
                    self.check_statement(stmt);
                }
            }
            
            Stmt::Expr(expr) => {
                let _ = self.infer_type(expr);
            }
            
            Stmt::Return(None) | Stmt::Break | Stmt::Continue | Stmt::Pass => {}
            
            _ => {} // Handle other statement types
        }
    }
    
    fn infer_type(&mut self, expr: &Expr) -> Type {
        match expr {
            Expr::IntLiteral(_) => Type::Simple("uint256".to_string()),
            Expr::BoolLiteral(_) => Type::Simple("bool".to_string()),
            Expr::StringLiteral(_) => Type::Simple("string".to_string()),
            Expr::HexLiteral(_) => Type::Simple("address".to_string()),
            Expr::NoneLiteral => Type::Simple("none".to_string()),
            
            Expr::Ident(name) => {
                self.type_env.get(name).cloned().unwrap_or_else(|| {
                    // Don't error for common identifiers
                    if name == "msg" || name == "self" || name == "block" {
                        Type::Simple("any".to_string())
                    } else {
                        Type::Simple("uint256".to_string()) // Default
                    }
                })
            }
            
            Expr::BinOp(left, op, right) => {
                let left_type = self.infer_type(left);
                let right_type = self.infer_type(right);
                
                match op {
                    BinOp::Add | BinOp::Sub | BinOp::Mul | BinOp::Div | BinOp::Mod | BinOp::Pow => {
                        left_type
                    }
                    
                    BinOp::Eq | BinOp::NotEq | BinOp::Lt | BinOp::LtEq | BinOp::Gt | BinOp::GtEq => {
                        Type::Simple("bool".to_string())
                    }
                    
                    BinOp::And | BinOp::Or => {
                        Type::Simple("bool".to_string())
                    }
                    
                    _ => Type::Simple("uint256".to_string()),
                }
            }
            
            Expr::UnaryOp(op, operand) => {
                let operand_type = self.infer_type(operand);
                
                match op {
                    UnaryOp::Not => Type::Simple("bool".to_string()),
                    UnaryOp::Neg => operand_type,
                    _ => Type::Simple("uint256".to_string()),
                }
            }
            
            Expr::Call(function, _args) => {
                // Look up function signature
                if let Expr::Ident(name) = &**function {
                    if let Some(sig) = self.functions.get(name) {
                        sig.return_type.clone().unwrap_or(Type::Simple("uint256".to_string()))
                    } else {
                        Type::Simple("uint256".to_string())
                    }
                } else {
                    Type::Simple("uint256".to_string())
                }
            }
            
            Expr::Index(_, _) => Type::Simple("uint256".to_string()),
            
            Expr::Attribute(_, _) => Type::Simple("uint256".to_string()),
            
            Expr::List(_) => Type::Simple("list".to_string()),
            
            Expr::Tuple(_) => Type::Simple("tuple".to_string()),
        }
    }
    
    fn types_compatible(&self, t1: &Type, t2: &Type) -> bool {
        // Simplified type compatibility check
        match (t1, t2) {
            (Type::Simple(s1), Type::Simple(s2)) => s1 == s2 || s1 == "any" || s2 == "any",
            _ => true, // Be lenient for now
        }
    }
    
    fn has_return_statement(&self, stmts: &[Stmt]) -> bool {
        stmts.iter().any(|stmt| matches!(stmt, Stmt::Return(_)))
    }
}
