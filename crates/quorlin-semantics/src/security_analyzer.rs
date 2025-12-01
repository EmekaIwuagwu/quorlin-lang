//! # Security Analyzer
//!
//! Static security analysis for Quorlin smart contracts.
//!
//! This module implements security checks for common vulnerabilities:
//! - Reentrancy attacks
//! - Missing access control
//! - Unprotected state changes
//! - External call safety

use quorlin_parser::{ContractMember, Expr, Function, Item, Module, Stmt};
use std::collections::HashSet;

/// Security warnings
#[derive(Debug, Clone, PartialEq)]
pub enum SecurityWarning {
    /// Potential reentrancy vulnerability
    ReentrancyRisk {
        function: String,
        line: String,
    },

    /// Missing access control on sensitive function
    MissingAccessControl {
        function: String,
        reason: String,
    },

    /// State change after external call (reentrancy pattern)
    StateChangeAfterExternalCall {
        function: String,
        line: String,
    },

    /// Unprotected state modification
    UnprotectedStateModification {
        function: String,
        state_var: String,
    },
}

impl std::fmt::Display for SecurityWarning {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            SecurityWarning::ReentrancyRisk { function, line } => {
                write!(f, "⚠️  REENTRANCY RISK in function '{}': {}", function, line)
            }
            SecurityWarning::MissingAccessControl { function, reason } => {
                write!(f, "⚠️  MISSING ACCESS CONTROL in '{}': {}", function, reason)
            }
            SecurityWarning::StateChangeAfterExternalCall { function, line } => {
                write!(f, "⚠️  STATE CHANGE AFTER EXTERNAL CALL in '{}': {}", function, line)
            }
            SecurityWarning::UnprotectedStateModification { function, state_var } => {
                write!(f, "⚠️  UNPROTECTED STATE MODIFICATION in '{}': modifies '{}'", function, state_var)
            }
        }
    }
}

/// Security analyzer
pub struct SecurityAnalyzer {
    warnings: Vec<SecurityWarning>,
    state_variables: HashSet<String>,
}

impl SecurityAnalyzer {
    /// Create a new security analyzer
    pub fn new() -> Self {
        Self {
            warnings: Vec::new(),
            state_variables: HashSet::new(),
        }
    }

    /// Analyze a module for security issues
    pub fn analyze(&mut self, module: &Module) -> Vec<SecurityWarning> {
        self.warnings.clear();
        self.state_variables.clear();

        // Collect state variables first
        for item in &module.items {
            if let Item::Contract(contract) = item {
                for member in &contract.body {
                    if let ContractMember::StateVar(var) = member {
                        self.state_variables.insert(var.name.clone());
                    }
                }
            }
        }

        // Analyze each contract
        for item in &module.items {
            if let Item::Contract(contract) = item {
                for member in &contract.body {
                    if let ContractMember::Function(func) = member {
                        self.analyze_function(func);
                    }
                }
            }
        }

        self.warnings.clone()
    }

    /// Analyze a function for security issues
    fn analyze_function(&mut self, func: &Function) {
        // Check for access control on state-modifying functions
        self.check_access_control(func);

        // Check for reentrancy vulnerabilities
        self.check_reentrancy(func);

        // Check for state changes after external calls
        self.check_state_change_after_external_call(func);
    }

    /// Check if function has appropriate access control
    fn check_access_control(&mut self, func: &Function) {
        // Skip view functions (they don't modify state)
        let is_view = func.decorators.iter().any(|d| d == "view");
        if is_view {
            return;
        }

        // Skip constructor (access control doesn't apply)
        let is_constructor = func.decorators.iter().any(|d| d == "constructor");
        if is_constructor {
            return;
        }

        // Check if function modifies sensitive state variables
        let modifies_sensitive_state = self.function_modifies_state(&func.body);

        if modifies_sensitive_state {
            // Check if function has access control
            let has_access_control = self.has_access_control_check(&func.body);

            if !has_access_control {
                // Special exemption for common token functions that have built-in checks
                let exempted_functions = ["transfer", "approve", "balance_of", "allowance"];
                if !exempted_functions.contains(&func.name.as_str()) {
                    self.warnings.push(SecurityWarning::MissingAccessControl {
                        function: func.name.clone(),
                        reason: "Function modifies state without checking msg.sender".to_string(),
                    });
                }
            }
        }
    }

    /// Check if function modifies state variables
    fn function_modifies_state(&self, body: &[Stmt]) -> bool {
        for stmt in body {
            if self.statement_modifies_state(stmt) {
                return true;
            }
        }
        false
    }

    /// Check if statement modifies state
    fn statement_modifies_state(&self, stmt: &Stmt) -> bool {
        match stmt {
            Stmt::Assign(assign) => {
                // Check if target is a state variable (self.variable)
                if let Expr::Attribute(base, attr) = &assign.target {
                    if let Expr::Ident(base_name) = &**base {
                        if base_name == "self" && self.state_variables.contains(attr) {
                            return true;
                        }
                    }
                }
                // Check if target is an indexed state variable (self.mapping[key])
                if let Expr::Index(base, _) = &assign.target {
                    if self.is_state_variable_access(base) {
                        return true;
                    }
                }
                false
            }
            Stmt::If(if_stmt) => {
                self.function_modifies_state(&if_stmt.then_branch)
                    || if_stmt.elif_branches.iter().any(|(_, body)| self.function_modifies_state(body))
                    || if_stmt.else_branch.as_ref().map_or(false, |body| self.function_modifies_state(body))
            }
            Stmt::For(for_stmt) => self.function_modifies_state(&for_stmt.body),
            Stmt::While(while_stmt) => self.function_modifies_state(&while_stmt.body),
            _ => false,
        }
    }

    /// Check if expression is a state variable access
    fn is_state_variable_access(&self, expr: &Expr) -> bool {
        match expr {
            Expr::Attribute(base, attr) => {
                if let Expr::Ident(base_name) = &**base {
                    base_name == "self" && self.state_variables.contains(attr)
                } else {
                    false
                }
            }
            Expr::Index(base, _) => self.is_state_variable_access(base),
            _ => false,
        }
    }

    /// Check if function has access control checks
    fn has_access_control_check(&self, body: &[Stmt]) -> bool {
        for stmt in body {
            if self.statement_has_access_control(stmt) {
                return true;
            }
        }
        false
    }

    /// Check if statement contains access control
    fn statement_has_access_control(&self, stmt: &Stmt) -> bool {
        match stmt {
            Stmt::Require(require) => {
                // Check if condition references msg.sender
                self.expression_checks_sender(&require.condition)
            }
            Stmt::If(if_stmt) => {
                // Check condition and all branches
                self.expression_checks_sender(&if_stmt.condition)
                    || self.has_access_control_check(&if_stmt.then_branch)
                    || if_stmt.elif_branches.iter().any(|(cond, body)| {
                        self.expression_checks_sender(cond) || self.has_access_control_check(body)
                    })
                    || if_stmt.else_branch.as_ref().map_or(false, |body| self.has_access_control_check(body))
            }
            _ => false,
        }
    }

    /// Check if expression references msg.sender (access control)
    fn expression_checks_sender(&self, expr: &Expr) -> bool {
        match expr {
            Expr::BinOp(left, _, right) => {
                self.expression_checks_sender(left) || self.expression_checks_sender(right)
            }
            Expr::Attribute(base, attr) => {
                if let Expr::Ident(base_name) = &**base {
                    base_name == "msg" && attr == "sender"
                } else {
                    false
                }
            }
            _ => false,
        }
    }

    /// Check for reentrancy vulnerabilities
    fn check_reentrancy(&mut self, func: &Function) {
        let has_external_call = self.has_external_call(&func.body);
        let modifies_state = self.function_modifies_state(&func.body);

        if has_external_call && modifies_state {
            self.warnings.push(SecurityWarning::ReentrancyRisk {
                function: func.name.clone(),
                line: "Function makes external calls and modifies state".to_string(),
            });
        }
    }

    /// Check if function makes external calls
    fn has_external_call(&self, body: &[Stmt]) -> bool {
        for stmt in body {
            if self.statement_has_external_call(stmt) {
                return true;
            }
        }
        false
    }

    /// Check if statement contains external calls
    fn statement_has_external_call(&self, stmt: &Stmt) -> bool {
        match stmt {
            Stmt::Expr(expr) => self.expression_is_external_call(expr),
            Stmt::Assign(assign) => self.expression_is_external_call(&assign.value),
            Stmt::If(if_stmt) => {
                self.has_external_call(&if_stmt.then_branch)
                    || if_stmt.elif_branches.iter().any(|(_, body)| self.has_external_call(body))
                    || if_stmt.else_branch.as_ref().map_or(false, |body| self.has_external_call(body))
            }
            Stmt::For(for_stmt) => self.has_external_call(&for_stmt.body),
            Stmt::While(while_stmt) => self.has_external_call(&while_stmt.body),
            _ => false,
        }
    }

    /// Check if expression is an external call
    fn expression_is_external_call(&self, expr: &Expr) -> bool {
        match expr {
            Expr::Call(func, _) => {
                // External calls are typically method calls: address.call(), contract.function()
                matches!(**func, Expr::Attribute(_, _))
            }
            _ => false,
        }
    }

    /// Check for state changes after external calls (reentrancy pattern)
    fn check_state_change_after_external_call(&mut self, func: &Function) {
        let has_bad_pattern = self.check_statements_for_bad_pattern(&func.body);
        if has_bad_pattern {
            self.warnings.push(SecurityWarning::StateChangeAfterExternalCall {
                function: func.name.clone(),
                line: "State modified after external call (use Checks-Effects-Interactions pattern)".to_string(),
            });
        }
    }

    /// Check statements for state-change-after-external-call pattern
    fn check_statements_for_bad_pattern(&mut self, body: &[Stmt]) -> bool {
        let mut found_external_call = false;

        for stmt in body {
            if found_external_call && self.statement_modifies_state(stmt) {
                return true;
            }

            if self.statement_has_external_call(stmt) {
                found_external_call = true;
            }

            // Recursively check nested statements
            match stmt {
                Stmt::If(if_stmt) => {
                    if self.check_statements_for_bad_pattern(&if_stmt.then_branch) {
                        return true;
                    }
                    for (_, body) in &if_stmt.elif_branches {
                        if self.check_statements_for_bad_pattern(body) {
                            return true;
                        }
                    }
                    if let Some(else_body) = &if_stmt.else_branch {
                        if self.check_statements_for_bad_pattern(else_body) {
                            return true;
                        }
                    }
                }
                Stmt::For(for_stmt) => {
                    if self.check_statements_for_bad_pattern(&for_stmt.body) {
                        return true;
                    }
                }
                Stmt::While(while_stmt) => {
                    if self.check_statements_for_bad_pattern(&while_stmt.body) {
                        return true;
                    }
                }
                _ => {}
            }
        }

        false
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_security_analyzer_creation() {
        let analyzer = SecurityAnalyzer::new();
        assert_eq!(analyzer.warnings.len(), 0);
    }
}
