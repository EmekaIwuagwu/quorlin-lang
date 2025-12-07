//! Security Analyzer
//!
//! Detects common security vulnerabilities in smart contracts

use quorlin_parser::ast::*;
use crate::{SecurityIssue, SecurityCategory, Severity};

pub struct SecurityAnalyzer {
    issues: Vec<SecurityIssue>,
}

impl SecurityAnalyzer {
    pub fn new() -> Self {
        Self {
            issues: Vec::new(),
        }
    }
    
    pub fn analyze(&mut self, module: &Module) -> Vec<SecurityIssue> {
        self.issues.clear();
        
        for item in &module.items {
            if let Item::Contract(contract) = item {
                self.analyze_contract(contract);
            }
        }
        
        self.issues.clone()
    }
    
    fn analyze_contract(&mut self, contract: &ContractDecl) {
        for member in &contract.body {
            if let ContractMember::Function(func) = member {
                self.analyze_function(func, contract);
            }
        }
    }
    
    fn analyze_function(&mut self, func: &Function, _contract: &ContractDecl) {
        // Check for reentrancy vulnerabilities
        self.check_reentrancy(func);
        
        // Check for integer overflow/underflow
        self.check_integer_operations(func);
        
        // Check for unchecked external calls
        self.check_unchecked_calls(func);
        
        // Check for access control
        self.check_access_control(func);
        
        // Check for timestamp dependence
        self.check_timestamp_dependence(func);
    }
    
    /// Checks for reentrancy vulnerabilities (CEI pattern violations)
    fn check_reentrancy(&mut self, func: &Function) {
        let mut has_external_call = false;
        let mut state_change_after_call = false;
        
        for (i, stmt) in func.body.iter().enumerate() {
            // Check if this is an external call
            if self.is_external_call(stmt) {
                has_external_call = true;
                
                // Check if there are state changes after this call
                for later_stmt in &func.body[i+1..] {
                    if self.modifies_state(later_stmt) {
                        state_change_after_call = true;
                        break;
                    }
                }
            }
        }
        
        if has_external_call && state_change_after_call {
            self.issues.push(SecurityIssue {
                severity: Severity::High,
                category: SecurityCategory::Reentrancy,
                message: format!(
                    "Potential reentrancy in function '{}': state changes after external call. \
                     Follow Checks-Effects-Interactions pattern.",
                    func.name
                ),
                location: Some(func.name.clone()),
            });
        }
    }
    
    /// Checks for unsafe integer operations
    fn check_integer_operations(&mut self, func: &Function) {
        for stmt in &func.body {
            self.check_stmt_for_unsafe_math(stmt, &func.name);
        }
    }
    
    fn check_stmt_for_unsafe_math(&mut self, stmt: &Stmt, func_name: &str) {
        match stmt {
            Stmt::Assign(assign) => {
                if self.has_unsafe_arithmetic(&assign.value) {
                    self.issues.push(SecurityIssue {
                        severity: Severity::Medium,
                        category: SecurityCategory::IntegerOverflow,
                        message: format!(
                            "Unsafe arithmetic operation in function '{}'. \
                             Use safe_add, safe_sub, safe_mul, safe_div from std.math",
                            func_name
                        ),
                        location: Some(func_name.to_string()),
                    });
                }
            }
            
            Stmt::If(if_stmt) => {
                for s in &if_stmt.then_branch {
                    self.check_stmt_for_unsafe_math(s, func_name);
                }
                if let Some(else_stmts) = &if_stmt.else_branch {
                    for s in else_stmts {
                        self.check_stmt_for_unsafe_math(s, func_name);
                    }
                }
            }
            
            Stmt::While(while_stmt) => {
                for s in &while_stmt.body {
                    self.check_stmt_for_unsafe_math(s, func_name);
                }
            }
            
            Stmt::For(for_stmt) => {
                for s in &for_stmt.body {
                    self.check_stmt_for_unsafe_math(s, func_name);
                }
            }
            
            _ => {}
        }
    }
    
    fn has_unsafe_arithmetic(&self, expr: &Expr) -> bool {
        match expr {
            Expr::BinOp(left, op, right) => {
                // Check if this is arithmetic without safe_ functions
                if matches!(op, BinOp::Add | BinOp::Sub | BinOp::Mul | BinOp::Div | BinOp::Mod) {
                    let uses_safe_math = self.uses_safe_math_function(expr);
                    !uses_safe_math
                } else {
                    self.has_unsafe_arithmetic(left) || self.has_unsafe_arithmetic(right)
                }
            }
            
            Expr::Call(function, args) => {
                args.iter().any(|arg| self.has_unsafe_arithmetic(arg)) ||
                self.has_unsafe_arithmetic(function)
            }
            
            _ => false,
        }
    }
    
    fn uses_safe_math_function(&self, expr: &Expr) -> bool {
        match expr {
            Expr::Call(function, _) => {
                if let Expr::Ident(name) = &**function {
                    matches!(
                        name.as_str(),
                        "safe_add" | "safe_sub" | "safe_mul" | "safe_div" | "safe_mod" | "safe_pow"
                    )
                } else {
                    false
                }
            }
            _ => false,
        }
    }
    
    /// Checks for unchecked external calls
    fn check_unchecked_calls(&mut self, func: &Function) {
        for stmt in &func.body {
            if let Stmt::Expr(Expr::Call(function, _)) = stmt {
                // Check if this is an external call without error handling
                if matches!(&**function, Expr::Attribute(_, _)) {
                    self.issues.push(SecurityIssue {
                        severity: Severity::Medium,
                        category: SecurityCategory::UncheckedCall,
                        message: format!(
                            "Unchecked external call in function '{}'. \
                             Always check return values or use require().",
                            func.name
                        ),
                        location: Some(func.name.clone()),
                    });
                }
            }
        }
    }
    
    /// Checks for missing access control
    fn check_access_control(&mut self, func: &Function) {
        // Check if function modifies state
        let modifies_state = func.body.iter().any(|stmt| self.modifies_state(stmt));
        
        // Check if function has access control
        let has_access_control = func.body.iter().any(|stmt| self.has_access_control_check(stmt));
        
        // Check if function is public/external (check decorators)
        let is_public = func.decorators.iter().any(|d| d == "external" || d == "public");
        
        if modifies_state && is_public && !has_access_control && !func.name.starts_with('_') {
            self.issues.push(SecurityIssue {
                severity: Severity::High,
                category: SecurityCategory::AccessControl,
                message: format!(
                    "Public function '{}' modifies state without access control. \
                     Consider adding owner checks or role-based access control.",
                    func.name
                ),
                location: Some(func.name.clone()),
            });
        }
    }
    
    /// Checks for timestamp dependence
    fn check_timestamp_dependence(&mut self, func: &Function) {
        for stmt in &func.body {
            if self.uses_timestamp(stmt) {
                self.issues.push(SecurityIssue {
                    severity: Severity::Low,
                    category: SecurityCategory::TimestampDependence,
                    message: format!(
                        "Function '{}' depends on block.timestamp. \
                         Be aware that miners can manipulate timestamps within bounds.",
                        func.name
                    ),
                    location: Some(func.name.clone()),
                });
                break;
            }
        }
    }
    
    // Helper methods
    
    fn is_external_call(&self, stmt: &Stmt) -> bool {
        match stmt {
            Stmt::Expr(Expr::Call(function, _)) => {
                matches!(&**function, Expr::Attribute(_, _))
            }
            _ => false,
        }
    }
    
    fn modifies_state(&self, stmt: &Stmt) -> bool {
        matches!(stmt, Stmt::Assign(_))
    }
    
    fn has_access_control_check(&self, stmt: &Stmt) -> bool {
        match stmt {
            Stmt::Expr(Expr::Call(function, _)) => {
                if let Expr::Ident(name) = &**function {
                    matches!(
                        name.as_str(),
                        "_only_owner" | "require" | "_check_role" | "require_owner"
                    )
                } else {
                    false
                }
            }
            Stmt::Require(_) => true,
            _ => false,
        }
    }
    
    fn uses_timestamp(&self, stmt: &Stmt) -> bool {
        match stmt {
            Stmt::Assign(assign) => self.expr_uses_timestamp(&assign.value),
            Stmt::Expr(expr) => self.expr_uses_timestamp(expr),
            Stmt::If(if_stmt) => self.expr_uses_timestamp(&if_stmt.condition),
            _ => false,
        }
    }
    
    fn expr_uses_timestamp(&self, expr: &Expr) -> bool {
        match expr {
            Expr::Call(function, _) => {
                if let Expr::Ident(name) = &**function {
                    matches!(name.as_str(), "block_timestamp" | "now")
                } else {
                    false
                }
            }
            
            Expr::Attribute(object, member) => {
                if let Expr::Ident(obj_name) = &**object {
                    obj_name == "block" && member == "timestamp"
                } else {
                    false
                }
            }
            
            Expr::BinOp(left, _, right) => {
                self.expr_uses_timestamp(left) || self.expr_uses_timestamp(right)
            }
            
            _ => false,
        }
    }
}
