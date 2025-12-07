//! Linter
//!
//! Code quality and style checks

use quorlin_parser::ast::*;
use crate::LintWarning;

pub struct Linter {
    warnings: Vec<LintWarning>,
}

impl Linter {
    pub fn new() -> Self {
        Self {
            warnings: Vec::new(),
        }
    }
    
    pub fn lint(&mut self, module: &Module) -> Vec<LintWarning> {
        self.warnings.clear();
        
        for item in &module.items {
            self.lint_item(item);
        }
        
        self.warnings.clone()
    }
    
    fn lint_item(&mut self, item: &Item) {
        match item {
            Item::Contract(contract) => self.lint_contract(contract),
            _ => {}
        }
    }
    
    fn lint_contract(&mut self, contract: &ContractDecl) {
        // Check contract naming convention
        if !self.is_pascal_case(&contract.name) {
            self.warnings.push(LintWarning {
                rule: "naming-convention".to_string(),
                message: format!(
                    "Contract name '{}' should be in PascalCase",
                    contract.name
                ),
                location: Some(contract.name.clone()),
            });
        }
        
        // Check for functions
        for member in &contract.body {
            if let ContractMember::Function(func) = member {
                self.lint_function(func, Some(contract));
            }
        }
        
        // Check for state variables
        for member in &contract.body {
            if let ContractMember::StateVar(var) = member {
                self.lint_state_variable(var);
            }
        }
    }
    
    fn lint_function(&mut self, func: &Function, contract: Option<&ContractDecl>) {
        // Check function naming convention
        if !self.is_snake_case(&func.name) && !func.name.starts_with('_') && !func.name.starts_with("__") {
            self.warnings.push(LintWarning {
                rule: "naming-convention".to_string(),
                message: format!(
                    "Function name '{}' should be in snake_case",
                    func.name
                ),
                location: Some(func.name.clone()),
            });
        }
        
        // Check for missing docstring
        if func.docstring.is_none() && contract.is_some() && !func.name.starts_with('_') {
            self.warnings.push(LintWarning {
                rule: "missing-docstring".to_string(),
                message: format!(
                    "Public function '{}' should have a docstring",
                    func.name
                ),
                location: Some(func.name.clone()),
            });
        }
        
        // Check function complexity
        let complexity = self.calculate_complexity(&func.body);
        if complexity > 10 {
            self.warnings.push(LintWarning {
                rule: "high-complexity".to_string(),
                message: format!(
                    "Function '{}' has high cyclomatic complexity ({}). Consider refactoring.",
                    func.name, complexity
                ),
                location: Some(func.name.clone()),
            });
        }
        
        // Check function length
        if func.body.len() > 50 {
            self.warnings.push(LintWarning {
                rule: "long-function".to_string(),
                message: format!(
                    "Function '{}' is too long ({} statements). Consider breaking it into smaller functions.",
                    func.name, func.body.len()
                ),
                location: Some(func.name.clone()),
            });
        }
        
        // Check for magic numbers
        self.check_magic_numbers(&func.body, &func.name);
        
        // Check for unused variables
        self.check_unused_variables(func);
    }
    
    fn lint_state_variable(&mut self, var: &StateVar) {
        // Check naming convention
        if !var.name.starts_with('_') && !var.name.chars().all(|c| c.is_uppercase() || c == '_') {
            self.warnings.push(LintWarning {
                rule: "naming-convention".to_string(),
                message: format!(
                    "State variable '{}' should start with underscore (_{})",
                    var.name, var.name
                ),
                location: Some(var.name.clone()),
            });
        }
    }
    
    fn calculate_complexity(&self, stmts: &[Stmt]) -> usize {
        let mut complexity = 1; // Base complexity
        
        for stmt in stmts {
            complexity += match stmt {
                Stmt::If(if_stmt) => {
                    if if_stmt.else_branch.is_some() { 2 } else { 1 }
                }
                Stmt::While(_) | Stmt::For(_) => 1,
                _ => 0,
            };
        }
        
        complexity
    }
    
    fn check_magic_numbers(&mut self, stmts: &[Stmt], func_name: &str) {
        for stmt in stmts {
            self.check_stmt_for_magic_numbers(stmt, func_name);
        }
    }
    
    fn check_stmt_for_magic_numbers(&mut self, stmt: &Stmt, func_name: &str) {
        match stmt {
            Stmt::Assign(assign) => {
                if let Some(number) = self.find_magic_number(&assign.value) {
                    self.warnings.push(LintWarning {
                        rule: "magic-number".to_string(),
                        message: format!(
                            "Magic number {} in function '{}'. Consider using a named constant.",
                            number, func_name
                        ),
                        location: Some(func_name.to_string()),
                    });
                }
            }
            
            Stmt::Return(Some(expr)) | Stmt::Expr(expr) => {
                if let Some(number) = self.find_magic_number(expr) {
                    self.warnings.push(LintWarning {
                        rule: "magic-number".to_string(),
                        message: format!(
                            "Magic number {} in function '{}'. Consider using a named constant.",
                            number, func_name
                        ),
                        location: Some(func_name.to_string()),
                    });
                }
            }
            
            Stmt::If(if_stmt) => {
                for s in &if_stmt.then_branch {
                    self.check_stmt_for_magic_numbers(s, func_name);
                }
                if let Some(else_stmts) = &if_stmt.else_branch {
                    for s in else_stmts {
                        self.check_stmt_for_magic_numbers(s, func_name);
                    }
                }
            }
            
            Stmt::While(while_stmt) => {
                for s in &while_stmt.body {
                    self.check_stmt_for_magic_numbers(s, func_name);
                }
            }
            
            Stmt::For(for_stmt) => {
                for s in &for_stmt.body {
                    self.check_stmt_for_magic_numbers(s, func_name);
                }
            }
            
            _ => {}
        }
    }
    
    fn find_magic_number(&self, expr: &Expr) -> Option<String> {
        match expr {
            Expr::IntLiteral(n) => {
                // Ignore common constants
                if n == "0" || n == "1" || n == "2" {
                    None
                } else {
                    Some(n.clone())
                }
            }
            
            Expr::BinOp(left, _, right) => {
                self.find_magic_number(left).or_else(|| self.find_magic_number(right))
            }
            
            _ => None,
        }
    }
    
    fn check_unused_variables(&mut self, func: &Function) {
        // Simple unused variable check
        for param in &func.params {
            if param.name.starts_with('_') {
                // Intentionally unused (convention)
                continue;
            }
            
            let used = self.is_variable_used(&func.body, &param.name);
            if !used {
                self.warnings.push(LintWarning {
                    rule: "unused-variable".to_string(),
                    message: format!(
                        "Parameter '{}' is never used in function '{}'. \
                         Prefix with underscore if intentional.",
                        param.name, func.name
                    ),
                    location: Some(func.name.clone()),
                });
            }
        }
    }
    
    fn is_variable_used(&self, stmts: &[Stmt], var_name: &str) -> bool {
        for stmt in stmts {
            if self.stmt_uses_variable(stmt, var_name) {
                return true;
            }
        }
        false
    }
    
    fn stmt_uses_variable(&self, stmt: &Stmt, var_name: &str) -> bool {
        match stmt {
            Stmt::Assign(assign) => {
                self.expr_uses_variable(&assign.value, var_name) ||
                self.expr_uses_variable(&assign.target, var_name)
            }
            
            Stmt::Return(Some(expr)) | Stmt::Expr(expr) => {
                self.expr_uses_variable(expr, var_name)
            }
            
            Stmt::If(if_stmt) => {
                self.expr_uses_variable(&if_stmt.condition, var_name) ||
                if_stmt.then_branch.iter().any(|s| self.stmt_uses_variable(s, var_name)) ||
                if_stmt.else_branch.as_ref().map(|stmts| {
                    stmts.iter().any(|s| self.stmt_uses_variable(s, var_name))
                }).unwrap_or(false)
            }
            
            Stmt::While(while_stmt) => {
                self.expr_uses_variable(&while_stmt.condition, var_name) ||
                while_stmt.body.iter().any(|s| self.stmt_uses_variable(s, var_name))
            }
            
            Stmt::For(for_stmt) => {
                for_stmt.body.iter().any(|s| self.stmt_uses_variable(s, var_name))
            }
            
            _ => false,
        }
    }
    
    fn expr_uses_variable(&self, expr: &Expr, var_name: &str) -> bool {
        match expr {
            Expr::Ident(name) => name == var_name,
            
            Expr::BinOp(left, _, right) => {
                self.expr_uses_variable(left, var_name) ||
                self.expr_uses_variable(right, var_name)
            }
            
            Expr::UnaryOp(_, operand) => {
                self.expr_uses_variable(operand, var_name)
            }
            
            Expr::Call(function, args) => {
                self.expr_uses_variable(function, var_name) ||
                args.iter().any(|arg| self.expr_uses_variable(arg, var_name))
            }
            
            Expr::Index(object, index) => {
                self.expr_uses_variable(object, var_name) ||
                self.expr_uses_variable(index, var_name)
            }
            
            Expr::Attribute(object, _) => {
                self.expr_uses_variable(object, var_name)
            }
            
            Expr::List(items) | Expr::Tuple(items) => {
                items.iter().any(|item| self.expr_uses_variable(item, var_name))
            }
            
            _ => false,
        }
    }
    
    // Naming convention helpers
    
    fn is_pascal_case(&self, s: &str) -> bool {
        if s.is_empty() {
            return false;
        }
        
        let first_char = s.chars().next().unwrap();
        first_char.is_uppercase() && !s.contains('_')
    }
    
    fn is_snake_case(&self, s: &str) -> bool {
        s.chars().all(|c| c.is_lowercase() || c.is_numeric() || c == '_')
    }
}
