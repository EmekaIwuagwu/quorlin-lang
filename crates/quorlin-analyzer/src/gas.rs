//! Gas Estimator
//!
//! Estimates gas costs for functions and operations

use quorlin_parser::ast::*;
use crate::{GasEstimate, GasComplexity};

pub struct GasEstimator {
    estimates: Vec<GasEstimate>,
}

impl GasEstimator {
    pub fn new() -> Self {
        Self {
            estimates: Vec::new(),
        }
    }
    
    pub fn estimate(&mut self, module: &Module) -> Vec<GasEstimate> {
        self.estimates.clear();
        
        for item in &module.items {
            if let Item::Contract(contract) = item {
                self.estimate_contract(contract);
            }
        }
        
        self.estimates.clone()
    }
    
    fn estimate_contract(&mut self, contract: &ContractDecl) {
        for member in &contract.body {
            if let ContractMember::Function(func) = member {
                let estimate = self.estimate_function(func);
                self.estimates.push(estimate);
            }
        }
    }
    
    fn estimate_function(&self, func: &Function) -> GasEstimate {
        let mut gas = 21000; // Base transaction cost
        let mut complexity = GasComplexity::Constant;
        
        // Add function overhead
        gas += 200; // Function call overhead
        
        // Estimate body
        for stmt in &func.body {
            let (stmt_gas, stmt_complexity) = self.estimate_statement(stmt);
            gas += stmt_gas;
            
            // Update complexity
            complexity = match (complexity, stmt_complexity) {
                (GasComplexity::Quadratic, _) | (_, GasComplexity::Quadratic) => GasComplexity::Quadratic,
                (GasComplexity::Linear, _) | (_, GasComplexity::Linear) => GasComplexity::Linear,
                (GasComplexity::Constant, GasComplexity::Constant) => GasComplexity::Constant,
                _ => GasComplexity::Unknown,
            };
        }
        
        GasEstimate {
            function_name: func.name.clone(),
            estimated_gas: gas,
            complexity,
        }
    }
    
    fn estimate_statement(&self, stmt: &Stmt) -> (u64, GasComplexity) {
        match stmt {
            Stmt::Assign(assign) => {
                let gas = 100 + self.estimate_expression(&assign.value);
                (gas, GasComplexity::Constant)
            }
            
            Stmt::Return(Some(expr)) => {
                let gas = 50 + self.estimate_expression(expr);
                (gas, GasComplexity::Constant)
            }
            
            Stmt::Return(None) => (50, GasComplexity::Constant),
            
            Stmt::If(if_stmt) => {
                let mut gas = 100 + self.estimate_expression(&if_stmt.condition);
                
                // Estimate both branches (worst case)
                let then_gas: u64 = if_stmt.then_branch.iter()
                    .map(|s| self.estimate_statement(s).0)
                    .sum();
                
                let else_gas: u64 = if_stmt.else_branch.as_ref()
                    .map(|stmts| stmts.iter().map(|s| self.estimate_statement(s).0).sum())
                    .unwrap_or(0);
                
                gas += then_gas.max(else_gas);
                
                (gas, GasComplexity::Constant)
            }
            
            Stmt::While(while_stmt) => {
                let condition_gas = self.estimate_expression(&while_stmt.condition);
                let body_gas: u64 = while_stmt.body.iter()
                    .map(|s| self.estimate_statement(s).0)
                    .sum();
                
                // Assume 10 iterations for estimation
                let gas = (condition_gas + body_gas) * 10;
                
                (gas, GasComplexity::Linear)
            }
            
            Stmt::For(for_stmt) => {
                let body_gas: u64 = for_stmt.body.iter()
                    .map(|s| self.estimate_statement(s).0)
                    .sum();
                
                // Check for nested loops
                let has_nested_loop = for_stmt.body.iter().any(|s| {
                    matches!(s, Stmt::For(_) | Stmt::While(_))
                });
                
                let complexity = if has_nested_loop {
                    GasComplexity::Quadratic
                } else {
                    GasComplexity::Linear
                };
                
                // Assume 10 iterations
                (body_gas * 10, complexity)
            }
            
            Stmt::Expr(expr) => {
                (self.estimate_expression(expr), GasComplexity::Constant)
            }
            
            Stmt::Break | Stmt::Continue | Stmt::Pass => (50, GasComplexity::Constant),
            
            _ => (100, GasComplexity::Constant),
        }
    }
    
    fn estimate_expression(&self, expr: &Expr) -> u64 {
        match expr {
            Expr::IntLiteral(_) | Expr::BoolLiteral(_) | Expr::NoneLiteral => 10,
            
            Expr::StringLiteral(s) => 10 + (s.len() as u64 * 2),
            
            Expr::HexLiteral(_) => 10,
            
            Expr::Ident(_) => 50, // SLOAD or memory access
            
            Expr::BinOp(left, op, right) => {
                let left_gas = self.estimate_expression(left);
                let right_gas = self.estimate_expression(right);
                let op_gas = match op {
                    BinOp::Add | BinOp::Sub => 3,
                    BinOp::Mul => 5,
                    BinOp::Div | BinOp::Mod | BinOp::FloorDiv => 5,
                    BinOp::Pow => 10,
                    BinOp::Eq | BinOp::NotEq | BinOp::Lt | BinOp::LtEq | BinOp::Gt | BinOp::GtEq => 3,
                    BinOp::And | BinOp::Or => 3,
                };
                left_gas + right_gas + op_gas
            }
            
            Expr::UnaryOp(_, operand) => {
                self.estimate_expression(operand) + 3
            }
            
            Expr::Call(function, args) => {
                let mut gas = 700; // Function call overhead
                
                // Add argument costs
                for arg in args {
                    gas += self.estimate_expression(arg);
                }
                
                // Check if this is a storage operation
                if let Expr::Ident(name) = &**function {
                    gas += match name.as_str() {
                        "transfer" | "send" => 9000, // ETH transfer
                        "require" => 100,
                        _ => 200,
                    };
                }
                
                gas
            }
            
            Expr::Index(object, index) => {
                let obj_gas = self.estimate_expression(object);
                let idx_gas = self.estimate_expression(index);
                obj_gas + idx_gas + 200 // Array/mapping access
            }
            
            Expr::Attribute(object, _) => {
                self.estimate_expression(object) + 100 // Struct member access
            }
            
            Expr::List(items) => {
                let items_gas: u64 = items.iter()
                    .map(|item| self.estimate_expression(item))
                    .sum();
                items_gas + (items.len() as u64 * 100)
            }
            
            Expr::Tuple(items) => {
                let items_gas: u64 = items.iter()
                    .map(|item| self.estimate_expression(item))
                    .sum();
                items_gas + (items.len() as u64 * 50)
            }
            
            Expr::IfExp { test, body, orelse } => {
                // Estimate condition plus max of both branches
                let test_gas = self.estimate_expression(test);
                let body_gas = self.estimate_expression(body);
                let orelse_gas = self.estimate_expression(orelse);
                test_gas + body_gas.max(orelse_gas) + 50 // Add overhead for conditional logic
            }
        }
    }
}
