//! # Quorlin EVM Codegen
//!
//! EVM bytecode generator for the Quorlin compiler.
//!
//! This crate generates Yul code from Quorlin AST, which can then be
//! compiled to EVM bytecode using solc.

pub mod yul_generator;
pub mod storage_layout;
pub mod abi;

use quorlin_parser::Module;
use std::collections::HashMap;

/// Errors that can occur during code generation
#[derive(Debug, thiserror::Error)]
pub enum CodegenError {
    #[error("Codegen error: {0}")]
    Error(String),

    #[error("Unsupported feature: {0}")]
    UnsupportedFeature(String),

    #[error("Contract not found")]
    ContractNotFound,
}

/// Result type for code generation
pub type CodegenResult<T> = Result<T, CodegenError>;

/// EVM code generator
pub struct EvmCodegen {
    /// Storage slot assignments for state variables
    storage_layout: HashMap<String, usize>,

    /// Current storage slot counter
    next_storage_slot: usize,
}

impl EvmCodegen {
    /// Create a new EVM code generator
    pub fn new() -> Self {
        Self {
            storage_layout: HashMap::new(),
            next_storage_slot: 0,
        }
    }

    /// Generate Yul code from a module
    pub fn generate(&mut self, module: &Module) -> CodegenResult<String> {
        // Find the contract (for now, assume only one contract per module)
        let contract = module
            .items
            .iter()
            .find_map(|item| {
                if let quorlin_parser::Item::Contract(c) = item {
                    Some(c)
                } else {
                    None
                }
            })
            .ok_or(CodegenError::ContractNotFound)?;

        // Allocate storage slots for state variables
        self.allocate_storage(&contract.body)?;

        // Generate Yul code
        let mut yul = String::new();
        yul.push_str(&format!("// Contract: {}\n", contract.name));
        yul.push_str("object \"Contract\" {\n");
        yul.push_str("  code {\n");

        // Constructor code
        yul.push_str("    // Copy runtime code to memory and return it\n");
        yul.push_str("    datacopy(0, dataoffset(\"runtime\"), datasize(\"runtime\"))\n");
        yul.push_str("    return(0, datasize(\"runtime\"))\n");
        yul.push_str("  }\n");

        // Runtime code
        yul.push_str("  object \"runtime\" {\n");
        yul.push_str("    code {\n");

        // Function dispatcher
        yul.push_str(&self.generate_dispatcher(&contract.body)?);

        // Function implementations
        yul.push_str(&self.generate_functions(&contract.body)?);

        yul.push_str("    }\n");
        yul.push_str("  }\n");
        yul.push_str("}\n");

        Ok(yul)
    }

    /// Allocate storage slots for state variables
    fn allocate_storage(&mut self, members: &[quorlin_parser::ContractMember]) -> CodegenResult<()> {
        for member in members {
            if let quorlin_parser::ContractMember::StateVar(var) = member {
                self.storage_layout.insert(var.name.clone(), self.next_storage_slot);
                self.next_storage_slot += 1;
            }
        }
        Ok(())
    }

    /// Generate function dispatcher (routes function calls based on signature)
    fn generate_dispatcher(&self, members: &[quorlin_parser::ContractMember]) -> CodegenResult<String> {
        let mut code = String::new();

        code.push_str("      // Function dispatcher\n");
        code.push_str("      switch selector()\n");

        for member in members {
            if let quorlin_parser::ContractMember::Function(func) = member {
                // Skip constructor
                if func.name == "__init__" {
                    continue;
                }

                // Calculate function selector (first 4 bytes of keccak256 hash)
                let selector = self.calculate_selector(&func.name, &func.params);
                code.push_str(&format!("      case 0x{:08x} {{ {}() }}\n", selector, func.name));
            }
        }

        code.push_str("      default { revert(0, 0) }\n\n");

        // Helper function to get selector from calldata
        code.push_str("      function selector() -> s {\n");
        code.push_str("        s := div(calldataload(0), 0x100000000000000000000000000000000000000000000000000000000)\n");
        code.push_str("      }\n\n");

        Ok(code)
    }

    /// Generate function implementations
    fn generate_functions(&self, members: &[quorlin_parser::ContractMember]) -> CodegenResult<String> {
        let mut code = String::new();

        for member in members {
            if let quorlin_parser::ContractMember::Function(func) = member {
                // Skip constructor for now
                if func.name == "__init__" {
                    continue;
                }

                code.push_str(&format!("      function {}() {{\n", func.name));

                // Function body
                for stmt in &func.body {
                    code.push_str(&self.generate_statement(stmt, 8)?);
                }

                code.push_str("      }\n\n");
            }
        }

        Ok(code)
    }

    /// Generate code for a statement
    fn generate_statement(&self, stmt: &quorlin_parser::Stmt, indent: usize) -> CodegenResult<String> {
        use quorlin_parser::{Stmt, Expr};

        let indent_str = " ".repeat(indent);
        let mut code = String::new();

        match stmt {
            Stmt::Return(expr) => {
                if let Some(e) = expr {
                    let expr_code = self.generate_expression(e)?;
                    code.push_str(&format!("{}let ret := {}\n", indent_str, expr_code));
                    code.push_str(&format!("{}mstore(0, ret)\n", indent_str));
                    code.push_str(&format!("{}return(0, 32)\n", indent_str));
                } else {
                    code.push_str(&format!("{}return(0, 0)\n", indent_str));
                }
            }
            Stmt::Assign(assign) => {
                let value_code = self.generate_expression(&assign.value)?;

                match &assign.target {
                    Expr::Ident(name) => {
                        // Simple identifier assignment
                        if let Some(&slot) = self.storage_layout.get(name) {
                            // State variable
                            code.push_str(&format!("{}sstore({}, {})\n", indent_str, slot, value_code));
                        } else {
                            // Local variable
                            code.push_str(&format!("{}let {} := {}\n", indent_str, name, value_code));
                        }
                    }
                    Expr::Index(target, index) => {
                        // Indexed assignment: self.balances[addr] = value
                        // Generate: sstore(keccak256(key, slot), value)

                        if let Expr::Attribute(base, attr) = &**target {
                            if let Expr::Ident(base_name) = &**base {
                                if base_name == "self" {
                                    if let Some(&slot) = self.storage_layout.get(attr) {
                                        let key_code = self.generate_expression(index)?;
                                        code.push_str(&format!("{}mstore(0, {})\n", indent_str, key_code));
                                        code.push_str(&format!("{}mstore(32, {})\n", indent_str, slot));
                                        code.push_str(&format!("{}sstore(keccak256(0, 64), {})\n", indent_str, value_code));
                                        return Ok(code);
                                    }
                                }
                            }
                        } else if let Expr::Index(nested_target, nested_index) = &**target {
                            // Nested indexing: self.allowances[addr1][addr2] = value
                            if let Expr::Attribute(base, attr) = &**nested_target {
                                if let Expr::Ident(base_name) = &**base {
                                    if base_name == "self" {
                                        if let Some(&slot) = self.storage_layout.get(attr) {
                                            let first_key = self.generate_expression(nested_index)?;
                                            let second_key = self.generate_expression(index)?;

                                            // Calculate nested mapping storage location
                                            code.push_str(&format!("{}// Nested mapping assignment\n", indent_str));
                                            code.push_str(&format!("{}mstore(0, {})\n", indent_str, first_key));
                                            code.push_str(&format!("{}mstore(32, {})\n", indent_str, slot));
                                            code.push_str(&format!("{}let first_slot := keccak256(0, 64)\n", indent_str));
                                            code.push_str(&format!("{}mstore(0, {})\n", indent_str, second_key));
                                            code.push_str(&format!("{}mstore(32, first_slot)\n", indent_str));
                                            code.push_str(&format!("{}sstore(keccak256(0, 64), {})\n", indent_str, value_code));
                                            return Ok(code);
                                        }
                                    }
                                }
                            }
                        }

                        return Err(CodegenError::UnsupportedFeature(format!("Indexed assignment {:?}", assign.target)));
                    }
                    _ => {
                        return Err(CodegenError::UnsupportedFeature(format!("Assignment target {:?}", assign.target)));
                    }
                }
            }
            Stmt::Require(req) => {
                let cond = self.generate_expression(&req.condition)?;
                code.push_str(&format!("{}if iszero({}) {{ revert(0, 0) }}\n", indent_str, cond));
            }
            Stmt::Emit(_) => {
                // TODO: Implement event emission
                code.push_str(&format!("{}// emit statement (not implemented)\n", indent_str));
            }
            Stmt::Pass => {
                code.push_str(&format!("{}// pass\n", indent_str));
            }
            _ => {
                return Err(CodegenError::UnsupportedFeature(format!("{:?}", stmt)));
            }
        }

        Ok(code)
    }

    /// Generate code for an expression
    fn generate_expression(&self, expr: &quorlin_parser::Expr) -> CodegenResult<String> {
        use quorlin_parser::{Expr, BinOp};

        match expr {
            Expr::IntLiteral(n) => Ok(n.clone()),
            Expr::BoolLiteral(b) => Ok(if *b { "1".to_string() } else { "0".to_string() }),
            Expr::Ident(name) => {
                // Check if it's a state variable
                if let Some(&slot) = self.storage_layout.get(name) {
                    Ok(format!("sload({})", slot))
                } else {
                    // Assume it's a local variable or parameter
                    Ok(name.clone())
                }
            }
            Expr::BinOp(left, op, right) => {
                let left_code = self.generate_expression(left)?;
                let right_code = self.generate_expression(right)?;

                let op_code = match op {
                    BinOp::Add => "add",
                    BinOp::Sub => "sub",
                    BinOp::Mul => "mul",
                    BinOp::Div => "div",
                    BinOp::Eq => "eq",
                    BinOp::NotEq => "iszero(eq",
                    BinOp::Lt => "lt",
                    BinOp::Gt => "gt",
                    BinOp::LtEq => "iszero(gt",
                    BinOp::GtEq => "iszero(lt",
                    _ => return Err(CodegenError::UnsupportedFeature(format!("BinOp {:?}", op))),
                };

                if matches!(op, BinOp::NotEq | BinOp::LtEq | BinOp::GtEq) {
                    Ok(format!("{}({}, {})))", op_code, left_code, right_code))
                } else {
                    Ok(format!("{}({}, {})", op_code, left_code, right_code))
                }
            }
            Expr::Call(func, args) => {
                // For now, just generate function call
                if let Expr::Ident(func_name) = &**func {
                    let arg_codes: Vec<_> = args
                        .iter()
                        .map(|a| self.generate_expression(a))
                        .collect::<Result<_, _>>()?;

                    Ok(format!("{}({})", func_name, arg_codes.join(", ")))
                } else {
                    Err(CodegenError::UnsupportedFeature("Complex function calls".to_string()))
                }
            }
            Expr::Attribute(base, attr) => {
                // For msg.sender, use caller()
                if let Expr::Ident(base_name) = &**base {
                    if base_name == "msg" && attr == "sender" {
                        return Ok("caller()".to_string());
                    } else if base_name == "msg" && attr == "value" {
                        return Ok("callvalue()".to_string());
                    } else if base_name == "self" {
                        // self.state_variable - look up storage slot
                        if let Some(&slot) = self.storage_layout.get(attr) {
                            return Ok(slot.to_string());
                        }
                    }
                }
                Err(CodegenError::UnsupportedFeature(format!("Attribute access: {}.{}", "base", attr)))
            }
            Expr::Index(target, index) => {
                // Handle mapping/array access
                // For mappings: storage_slot = keccak256(key, base_slot)

                // Check if target is a state variable (self.balances)
                if let Expr::Attribute(base, attr) = &**target {
                    if let Expr::Ident(base_name) = &**base {
                        if base_name == "self" {
                            if let Some(&slot) = self.storage_layout.get(attr) {
                                // Generate keccak256(key, slot) for mapping access
                                let key_code = self.generate_expression(index)?;

                                // Store key and slot in memory, then hash
                                let mut code = String::new();
                                code.push_str("{\n");
                                code.push_str(&format!("          mstore(0, {})\n", key_code));
                                code.push_str(&format!("          mstore(32, {})\n", slot));
                                code.push_str("          sload(keccak256(0, 64))\n");
                                code.push_str("        }");
                                return Ok(code);
                            }
                        }
                    }
                } else if let Expr::Index(nested_target, nested_index) = &**target {
                    // Nested indexing: self.allowances[addr1][addr2]
                    // First calculate the slot for the first index
                    if let Expr::Attribute(base, attr) = &**nested_target {
                        if let Expr::Ident(base_name) = &**base {
                            if base_name == "self" {
                                if let Some(&slot) = self.storage_layout.get(attr) {
                                    // First level: keccak256(nested_index, slot)
                                    let first_key = self.generate_expression(nested_index)?;

                                    // Second level: keccak256(index, first_slot)
                                    let second_key = self.generate_expression(index)?;

                                    let mut code = String::new();
                                    code.push_str("{\n");
                                    // Calculate first level slot
                                    code.push_str(&format!("          mstore(0, {})\n", first_key));
                                    code.push_str(&format!("          mstore(32, {})\n", slot));
                                    code.push_str("          let first_slot := keccak256(0, 64)\n");
                                    // Calculate second level slot
                                    code.push_str(&format!("          mstore(0, {})\n", second_key));
                                    code.push_str("          mstore(32, first_slot)\n");
                                    code.push_str("          sload(keccak256(0, 64))\n");
                                    code.push_str("        }");
                                    return Ok(code);
                                }
                            }
                        }
                    }
                }

                Err(CodegenError::UnsupportedFeature(format!("Index {:?}", expr)))
            }
            _ => Err(CodegenError::UnsupportedFeature(format!("Expression {:?}", expr))),
        }
    }

    /// Calculate function selector (simplified version)
    fn calculate_selector(&self, name: &str, params: &[quorlin_parser::Param]) -> u32 {
        use std::collections::hash_map::DefaultHasher;
        use std::hash::{Hash, Hasher};

        let mut hasher = DefaultHasher::new();
        name.hash(&mut hasher);
        for param in params {
            param.name.hash(&mut hasher);
        }

        (hasher.finish() as u32) & 0xFFFFFFFF
    }
}

impl Default for EvmCodegen {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_codegen_creation() {
        let _codegen = EvmCodegen::new();
    }
}
