//! Move code generation

use quorlin_parser::ast::*;
use crate::{AptosCodegenError, types::TypeMapper};
use std::collections::HashSet;

pub struct MoveGenerator {
    module_address: String,
    indent_level: usize,
    required_imports: HashSet<String>,
}

impl MoveGenerator {
    pub fn new(module_address: &str) -> Self {
        Self {
            module_address: module_address.to_string(),
            indent_level: 0,
            required_imports: HashSet::new(),
        }
    }
    
    pub fn generate_module(&mut self, module: &Module) -> Result<String, AptosCodegenError> {
        let mut output = String::new();
        
        // Generate module header
        output.push_str(&format!("module {}::quorlin_contract {{\n", self.module_address));
        self.indent_level += 1;
        
        // Add common imports
        output.push_str(&self.indent());
        output.push_str("use std::signer;\n");
        output.push_str(&self.indent());
        output.push_str("use std::vector;\n");
        output.push_str(&self.indent());
        output.push_str("use aptos_framework::account;\n");
        
        // Process items
        for item in &module.items {
            match item {
                Item::Contract(contract) => {
                    output.push_str(&self.generate_contract(contract)?);
                }
                Item::Struct(struct_decl) => {
                    output.push_str(&self.generate_struct(struct_decl)?);
                }
                Item::Enum(enum_decl) => {
                    output.push_str(&self.generate_enum(enum_decl)?);
                }
                _ => {} // Skip imports, interfaces, etc.
            }
        }
        
        // Add any additional required imports
        for import in &self.required_imports {
            if !output.contains(import) {
                let import_line = format!("{}use {};\n", self.indent(), import);
                // Insert after initial imports
                let insert_pos = output.find("use aptos_framework::account;\n")
                    .map(|pos| pos + "use aptos_framework::account;\n".len())
                    .unwrap_or(output.len());
                output.insert_str(insert_pos, &import_line);
            }
        }
        
        self.indent_level -= 1;
        output.push_str("}\n");
        
        Ok(output)
    }
    
    fn generate_contract(&mut self, contract: &ContractDecl) -> Result<String, AptosCodegenError> {
        let mut output = String::new();
        
        // Generate contract resource struct
        output.push_str("\n");
        output.push_str(&self.indent());
        output.push_str(&format!("/// Contract: {}\n", contract.name));
        
        if let Some(doc) = &contract.docstring {
            output.push_str(&self.indent());
            output.push_str(&format!("/// {}\n", doc));
        }
        
        output.push_str(&self.indent());
        output.push_str(&format!("struct {} has key {{\n", contract.name));
        self.indent_level += 1;
        
        // Generate state variables
        for member in &contract.body {
            if let ContractMember::StateVar(var) = member {
                output.push_str(&self.generate_state_var(var)?);
            }
        }
        
        self.indent_level -= 1;
        output.push_str(&self.indent());
        output.push_str("}\n\n");
        
        // Generate initialization function
        output.push_str(&self.generate_init_function(contract)?);
        
        // Generate functions
        for member in &contract.body {
            if let ContractMember::Function(func) = member {
                output.push_str(&self.generate_function(func, &contract.name)?);
            }
        }
        
        Ok(output)
    }
    
    fn generate_state_var(&mut self, var: &StateVar) -> Result<String, AptosCodegenError> {
        let mut output = String::new();
        
        output.push_str(&self.indent());
        let move_type = TypeMapper::to_move_type(&var.type_annotation)?;
        
        // Remove leading underscore for Move (Move doesn't use that convention)
        let var_name = var.name.trim_start_matches('_');
        
        output.push_str(&format!("{}: {},\n", var_name, move_type));
        
        // Track if we need table import
        if move_type.contains("Table") {
            self.required_imports.insert("aptos_std::table::Table".to_string());
        }
        
        Ok(output)
    }
    
    fn generate_init_function(&mut self, contract: &ContractDecl) -> Result<String, AptosCodegenError> {
        let mut output = String::new();
        
        output.push_str(&self.indent());
        output.push_str(&format!("/// Initialize the {} contract\n", contract.name));
        output.push_str(&self.indent());
        output.push_str(&format!("public entry fun initialize(account: &signer) {{\n"));
        self.indent_level += 1;
        
        output.push_str(&self.indent());
        output.push_str(&format!("let contract = {} {{\n", contract.name));
        self.indent_level += 1;
        
        // Initialize state variables with defaults
        for member in &contract.body {
            if let ContractMember::StateVar(var) = member {
                let var_name = var.name.trim_start_matches('_');
                let default = TypeMapper::default_value(&var.type_annotation)?;
                output.push_str(&self.indent());
                output.push_str(&format!("{}: {},\n", var_name, default));
            }
        }
        
        self.indent_level -= 1;
        output.push_str(&self.indent());
        output.push_str("};\n");
        
        output.push_str(&self.indent());
        output.push_str("move_to(account, contract);\n");
        
        self.indent_level -= 1;
        output.push_str(&self.indent());
        output.push_str("}\n\n");
        
        Ok(output)
    }
    
    fn generate_function(&mut self, func: &Function, contract_name: &str) -> Result<String, AptosCodegenError> {
        let mut output = String::new();
        
        // Add docstring
        if let Some(doc) = &func.docstring {
            output.push_str(&self.indent());
            output.push_str(&format!("/// {}\n", doc));
        }
        
        // Determine function visibility
        let is_public = func.decorators.iter().any(|d| d == "external" || d == "public");
        let visibility = if is_public { "public entry fun" } else { "fun" };
        
        output.push_str(&self.indent());
        output.push_str(visibility);
        output.push_str(&format!(" {}", func.name));
        
        // Parameters
        output.push_str("(");
        
        // Add account parameter for public functions
        if is_public {
            output.push_str("account: &signer");
            if !func.params.is_empty() {
                output.push_str(", ");
            }
        }
        
        // Add contract reference for non-static functions
        let needs_contract_ref = func.body.iter().any(|stmt| self.references_self(stmt));
        if needs_contract_ref && !is_public {
            output.push_str(&format!("contract: &mut {}", contract_name));
            if !func.params.is_empty() {
                output.push_str(", ");
            }
        }
        
        // Function parameters
        for (i, param) in func.params.iter().enumerate() {
            let move_type = TypeMapper::to_move_type(&param.type_annotation)?;
            output.push_str(&format!("{}: {}", param.name, move_type));
            if i < func.params.len() - 1 {
                output.push_str(", ");
            }
        }
        
        output.push_str(")");
        
        // Return type
        if let Some(return_type) = &func.return_type {
            let move_type = TypeMapper::to_move_type(return_type)?;
            output.push_str(&format!(": {}", move_type));
        }
        
        // Function body
        output.push_str(" {\n");
        self.indent_level += 1;
        
        // Get contract reference if needed
        if needs_contract_ref && is_public {
            output.push_str(&self.indent());
            output.push_str(&format!("let contract = borrow_global_mut<{}>(signer::address_of(account));\n", contract_name));
        }
        
        // Generate body statements
        for stmt in &func.body {
            output.push_str(&self.generate_statement(stmt)?);
        }
        
        self.indent_level -= 1;
        output.push_str(&self.indent());
        output.push_str("}\n\n");
        
        Ok(output)
    }
    
    fn generate_statement(&mut self, stmt: &Stmt) -> Result<String, AptosCodegenError> {
        let mut output = String::new();
        
        match stmt {
            Stmt::Assign(assign) => {
                output.push_str(&self.indent());
                output.push_str(&self.generate_expr(&assign.target)?);
                output.push_str(" = ");
                output.push_str(&self.generate_expr(&assign.value)?);
                output.push_str(";\n");
            }
            
            Stmt::Return(Some(expr)) => {
                output.push_str(&self.indent());
                output.push_str(&self.generate_expr(expr)?);
                output.push_str("\n");
            }
            
            Stmt::Return(None) => {
                output.push_str(&self.indent());
                output.push_str("()\n");
            }
            
            Stmt::If(if_stmt) => {
                output.push_str(&self.indent());
                output.push_str("if (");
                output.push_str(&self.generate_expr(&if_stmt.condition)?);
                output.push_str(") {\n");
                self.indent_level += 1;
                
                for s in &if_stmt.then_branch {
                    output.push_str(&self.generate_statement(s)?);
                }
                
                self.indent_level -= 1;
                output.push_str(&self.indent());
                output.push_str("}");
                
                if let Some(else_branch) = &if_stmt.else_branch {
                    output.push_str(" else {\n");
                    self.indent_level += 1;
                    
                    for s in else_branch {
                        output.push_str(&self.generate_statement(s)?);
                    }
                    
                    self.indent_level -= 1;
                    output.push_str(&self.indent());
                    output.push_str("}");
                }
                
                output.push_str("\n");
            }
            
            Stmt::While(while_stmt) => {
                output.push_str(&self.indent());
                output.push_str("while (");
                output.push_str(&self.generate_expr(&while_stmt.condition)?);
                output.push_str(") {\n");
                self.indent_level += 1;
                
                for s in &while_stmt.body {
                    output.push_str(&self.generate_statement(s)?);
                }
                
                self.indent_level -= 1;
                output.push_str(&self.indent());
                output.push_str("}\n");
            }
            
            Stmt::Require(req) => {
                output.push_str(&self.indent());
                output.push_str("assert!(");
                output.push_str(&self.generate_expr(&req.condition)?);
                if let Some(msg) = &req.message {
                    output.push_str(&format!(", {}", msg));
                }
                output.push_str(");\n");
            }
            
            Stmt::Expr(expr) => {
                output.push_str(&self.indent());
                output.push_str(&self.generate_expr(expr)?);
                output.push_str(";\n");
            }
            
            _ => {
                output.push_str(&self.indent());
                output.push_str("// Unsupported statement\n");
            }
        }
        
        Ok(output)
    }
    
    fn generate_expr(&self, expr: &Expr) -> Result<String, AptosCodegenError> {
        match expr {
            Expr::IntLiteral(n) => Ok(n.clone()),
            Expr::BoolLiteral(b) => Ok(b.to_string()),
            Expr::StringLiteral(s) => Ok(format!("b\"{}\"", s)),
            Expr::HexLiteral(h) => Ok(format!("@{}", h)),
            Expr::NoneLiteral => Ok("()".to_string()),
            
            Expr::Ident(name) => {
                // Convert self.field to contract.field
                if name == "self" {
                    Ok("contract".to_string())
                } else {
                    Ok(name.clone())
                }
            }
            
            Expr::BinOp(left, op, right) => {
                let left_str = self.generate_expr(left)?;
                let right_str = self.generate_expr(right)?;
                let op_str = self.binop_to_move(op);
                Ok(format!("({} {} {})", left_str, op_str, right_str))
            }
            
            Expr::UnaryOp(op, operand) => {
                let operand_str = self.generate_expr(operand)?;
                let op_str = self.unaryop_to_move(op);
                Ok(format!("({}{})", op_str, operand_str))
            }
            
            Expr::Call(function, args) => {
                let func_str = self.generate_expr(function)?;
                let args_str: Result<Vec<_>, _> = args.iter()
                    .map(|arg| self.generate_expr(arg))
                    .collect();
                Ok(format!("{}({})", func_str, args_str?.join(", ")))
            }
            
            Expr::Attribute(object, attr) => {
                let obj_str = self.generate_expr(object)?;
                // Remove leading underscore from attribute names
                let attr_name = attr.trim_start_matches('_');
                Ok(format!("{}.{}", obj_str, attr_name))
            }
            
            Expr::Index(object, index) => {
                let obj_str = self.generate_expr(object)?;
                let idx_str = self.generate_expr(index)?;
                Ok(format!("*vector::borrow(&{}, {})", obj_str, idx_str))
            }
            
            Expr::List(items) => {
                let items_str: Result<Vec<_>, _> = items.iter()
                    .map(|item| self.generate_expr(item))
                    .collect();
                Ok(format!("vector[{}]", items_str?.join(", ")))
            }
            
            Expr::Tuple(items) => {
                let items_str: Result<Vec<_>, _> = items.iter()
                    .map(|item| self.generate_expr(item))
                    .collect();
                Ok(format!("({})", items_str?.join(", ")))
            }
            Expr::IfExp { test, body, orelse } => {
                let test_str = self.generate_expr(test)?;
                let body_str = self.generate_expr(body)?;
                let orelse_str = self.generate_expr(orelse)?;
                Ok(format!("if ({}) {} else {}", test_str, body_str, orelse_str))
            }
        }
    }
    
    fn binop_to_move(&self, op: &BinOp) -> &str {
        match op {
            BinOp::Add => "+",
            BinOp::Sub => "-",
            BinOp::Mul => "*",
            BinOp::Div => "/",
            BinOp::Mod => "%",
            BinOp::Eq => "==",
            BinOp::NotEq => "!=",
            BinOp::Lt => "<",
            BinOp::LtEq => "<=",
            BinOp::Gt => ">",
            BinOp::GtEq => ">=",
            BinOp::And => "&&",
            BinOp::Or => "||",
            _ => "/* unsupported op */",
        }
    }
    
    fn unaryop_to_move(&self, op: &UnaryOp) -> &str {
        match op {
            UnaryOp::Not => "!",
            UnaryOp::Neg => "-",
            _ => "/* unsupported op */",
        }
    }
    
    fn generate_struct(&mut self, struct_decl: &StructDecl) -> Result<String, AptosCodegenError> {
        let mut output = String::new();
        
        output.push_str("\n");
        output.push_str(&self.indent());
        output.push_str(&format!("struct {} has copy, drop {{\n", struct_decl.name));
        self.indent_level += 1;
        
        for field in &struct_decl.fields {
            output.push_str(&self.indent());
            let move_type = TypeMapper::to_move_type(&field.type_annotation)?;
            output.push_str(&format!("{}: {},\n", field.name, move_type));
        }
        
        self.indent_level -= 1;
        output.push_str(&self.indent());
        output.push_str("}\n");
        
        Ok(output)
    }
    
    fn generate_enum(&mut self, _enum_decl: &EnumDecl) -> Result<String, AptosCodegenError> {
        // Move doesn't have enums in the same way, would need to use constants or structs
        Ok(String::from("// Enums not yet supported in Move\n"))
    }
    
    fn references_self(&self, stmt: &Stmt) -> bool {
        match stmt {
            Stmt::Assign(assign) => {
                self.expr_references_self(&assign.target) || self.expr_references_self(&assign.value)
            }
            Stmt::Return(Some(expr)) | Stmt::Expr(expr) => {
                self.expr_references_self(expr)
            }
            Stmt::If(if_stmt) => {
                self.expr_references_self(&if_stmt.condition) ||
                if_stmt.then_branch.iter().any(|s| self.references_self(s)) ||
                if_stmt.else_branch.as_ref().map(|b| b.iter().any(|s| self.references_self(s))).unwrap_or(false)
            }
            _ => false,
        }
    }
    
    fn expr_references_self(&self, expr: &Expr) -> bool {
        match expr {
            Expr::Ident(name) => name == "self",
            Expr::Attribute(obj, _) => self.expr_references_self(obj),
            Expr::BinOp(left, _, right) => {
                self.expr_references_self(left) || self.expr_references_self(right)
            }
            Expr::Call(func, args) => {
                self.expr_references_self(func) || args.iter().any(|a| self.expr_references_self(a))
            }
            Expr::Index(obj, idx) => {
                self.expr_references_self(obj) || self.expr_references_self(idx)
            }
            Expr::List(items) | Expr::Tuple(items) => {
                items.iter().any(|i| self.expr_references_self(i))
            }
            Expr::IfExp { test, body, orelse } => {
                self.expr_references_self(test) || self.expr_references_self(body) || self.expr_references_self(orelse)
            }
            Expr::UnaryOp(_, op) => self.expr_references_self(op),
            _ => false,
        }
    }
    
    fn indent(&self) -> String {
        "    ".repeat(self.indent_level)
    }
}
