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

    /// Event signatures for event emission
    event_signatures: HashMap<String, String>,
}

impl EvmCodegen {
    /// Create a new EVM code generator
    pub fn new() -> Self {
        Self {
            storage_layout: HashMap::new(),
            next_storage_slot: 0,
            event_signatures: HashMap::new(),
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

        // Collect event definitions
        self.collect_events(module)?;

        // Allocate storage slots for state variables
        self.allocate_storage(&contract.body)?;

        // Generate Yul code
        let mut yul = String::new();
        yul.push_str(&format!("// Contract: {}\n", contract.name));
        yul.push_str("object \"Contract\" {\n");
        yul.push_str("  code {\n");

        // Constructor code - execute __init__ if present
        yul.push_str("    // Constructor (deployment) code\n");
        yul.push_str(&self.generate_constructor(&contract.body)?);
        yul.push_str("    // Copy runtime code to memory and return it\n");
        yul.push_str("    datacopy(0, dataoffset(\"runtime\"), datasize(\"runtime\"))\n");
        yul.push_str("    return(0, datasize(\"runtime\"))\n");
        yul.push_str("  }\n");

        // Runtime code
        yul.push_str("  object \"runtime\" {\n");
        yul.push_str("    code {\n");

        // Add checked arithmetic helper functions
        yul.push_str(&self.generate_checked_math_helpers());

        // Function dispatcher
        yul.push_str(&self.generate_dispatcher(&contract.body)?);

        // Function implementations
        yul.push_str(&self.generate_functions(&contract.body)?);

        yul.push_str("    }\n");
        yul.push_str("  }\n");
        yul.push_str("}\n");

        Ok(yul)
    }

    /// Generate checked arithmetic helper functions
    fn generate_checked_math_helpers(&self) -> String {
        r#"
      // ========================================
      // CHECKED ARITHMETIC HELPERS
      // Prevent integer overflow/underflow
      // ========================================

      function checked_add(a, b) -> result {
          result := add(a, b)
          // Overflow check: result must be >= a
          if lt(result, a) { revert(0, 0) }
      }

      function checked_sub(a, b) -> result {
          // Underflow check: a must be >= b
          if lt(a, b) { revert(0, 0) }
          result := sub(a, b)
      }

      function checked_mul(a, b) -> result {
          result := mul(a, b)
          // Overflow check (except for zero)
          if iszero(b) { leave }
          if iszero(eq(div(result, b), a)) { revert(0, 0) }
      }

      function checked_div(a, b) -> result {
          // Division by zero check
          if iszero(b) { revert(0, 0) }
          result := div(a, b)
      }

      function checked_mod(a, b) -> result {
          // Modulo by zero check
          if iszero(b) { revert(0, 0) }
          result := mod(a, b)
      }

      // ========================================
"#.to_string()
    }

    /// Collect event definitions and calculate their signatures
    fn collect_events(&mut self, module: &Module) -> CodegenResult<()> {
        for item in &module.items {
            if let quorlin_parser::Item::Event(event) = item {
                // Calculate event signature (simplified - using hash of name)
                // In real implementation, should be keccak256(name + param types)
                use std::collections::hash_map::DefaultHasher;
                use std::hash::{Hash, Hasher};

                let mut hasher = DefaultHasher::new();
                event.name.hash(&mut hasher);
                for param in &event.params {
                    param.name.hash(&mut hasher);
                }
                let sig = format!("0x{:064x}", hasher.finish());
                self.event_signatures.insert(event.name.clone(), sig);
            }
        }
        Ok(())
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

    /// Generate constructor code
    fn generate_constructor(&self, members: &[quorlin_parser::ContractMember]) -> CodegenResult<String> {
        // Find constructor function
        let constructor = members.iter().find_map(|member| {
            if let quorlin_parser::ContractMember::Function(func) = member {
                if func.name == "__init__" {
                    Some(func)
                } else {
                    None
                }
            } else {
                None
            }
        });

        let mut code = String::new();
        if let Some(ctor) = constructor {
            code.push_str("    // Execute constructor\n");

            // Load constructor parameters from calldata
            for (i, param) in ctor.params.iter().enumerate() {
                let offset = i * 32;
                code.push_str(&format!(
                    "    let {} := calldataload({})\n",
                    param.name, offset
                ));
            }

            if !ctor.params.is_empty() {
                code.push_str("\n");
            }

            // Execute constructor body
            for stmt in &ctor.body {
                code.push_str(&self.generate_statement(stmt, 4)?);
            }

            code.push_str("\n");
        }

        Ok(code)
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

                // Load function parameters from calldata
                // Parameters start at byte 4 (after the 4-byte selector)
                // Each parameter is 32 bytes
                for (i, param) in func.params.iter().enumerate() {
                    let offset = 4 + (i * 32);
                    code.push_str(&format!(
                        "        let {} := calldataload({})\n",
                        param.name, offset
                    ));
                }

                if !func.params.is_empty() {
                    code.push_str("\n");
                }

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
            Stmt::Emit(emit) => {
                // Generate event emission using LOG1
                // LOG1(offset, size, topic0)
                // topic0 = event signature
                // data = abi.encode(args...)

                if let Some(sig) = self.event_signatures.get(&emit.event) {
                    // Store event arguments in memory starting at position 0
                    let mut mem_offset = 0;
                    for arg in &emit.args {
                        let arg_code = self.generate_expression(arg)?;
                        code.push_str(&format!("{}mstore({}, {})\n", indent_str, mem_offset, arg_code));
                        mem_offset += 32;
                    }

                    // Emit LOG1 with event signature as topic
                    let data_size = emit.args.len() * 32;
                    code.push_str(&format!("{}log1(0, {}, {})\n", indent_str, data_size, sig));
                } else {
                    code.push_str(&format!("{}// Unknown event: {}\n", indent_str, emit.event));
                }
            }
            Stmt::Pass => {
                code.push_str(&format!("{}// pass\n", indent_str));
            }
            Stmt::If(if_stmt) => {
                // Generate if statement
                let cond_code = self.generate_expression(&if_stmt.condition)?;
                code.push_str(&format!("{}if {} {{\n", indent_str, cond_code));

                // Then branch
                for stmt in &if_stmt.then_branch {
                    code.push_str(&self.generate_statement(stmt, indent + 2)?);
                }

                // Elif branches
                for (elif_cond, elif_body) in &if_stmt.elif_branches {
                    let elif_cond_code = self.generate_expression(elif_cond)?;
                    code.push_str(&format!("{}}}\n", indent_str));
                    code.push_str(&format!("{}if {} {{\n", indent_str, elif_cond_code));
                    for stmt in elif_body {
                        code.push_str(&self.generate_statement(stmt, indent + 2)?);
                    }
                }

                // Else branch
                if let Some(else_body) = &if_stmt.else_branch {
                    code.push_str(&format!("{}}}\n", indent_str));
                    code.push_str(&format!("{}// else\n", indent_str));
                    code.push_str(&format!("{}{{\n", indent_str));
                    for stmt in else_body {
                        code.push_str(&self.generate_statement(stmt, indent + 2)?);
                    }
                }

                code.push_str(&format!("{}}}\n", indent_str));
            }
            Stmt::While(while_stmt) => {
                // Generate while loop (using Yul's for loop with no init/post)
                let cond_code = self.generate_expression(&while_stmt.condition)?;
                code.push_str(&format!("{}for {{}} {} {{}}\n", indent_str, cond_code));
                code.push_str(&format!("{}{{\n", indent_str));

                for stmt in &while_stmt.body {
                    code.push_str(&self.generate_statement(stmt, indent + 2)?);
                }

                code.push_str(&format!("{}}}\n", indent_str));
            }
            Stmt::For(for_stmt) => {
                // Generate for loop: for i in range(n):  →  Yul for loop
                // ✅ Properly implemented for loop code generation

                // Check if iterable is range() call
                if let Expr::Call(func, args) = &for_stmt.iterable {
                    if let Expr::Ident(func_name) = &**func {
                        if func_name == "range" {
                            // range(n) → for i := 0 to n-1
                            // range(start, end) → for i := start to end-1
                            // range(start, end, step) → for i := start to end-1 by step

                            let (start, end, step) = match args.len() {
                                1 => {
                                    // range(n) → 0 to n
                                    let end = self.generate_expression(&args[0])?;
                                    ("0".to_string(), end, "1".to_string())
                                }
                                2 => {
                                    // range(start, end)
                                    let start = self.generate_expression(&args[0])?;
                                    let end = self.generate_expression(&args[1])?;
                                    (start, end, "1".to_string())
                                }
                                3 => {
                                    // range(start, end, step)
                                    let start = self.generate_expression(&args[0])?;
                                    let end = self.generate_expression(&args[1])?;
                                    let step = self.generate_expression(&args[2])?;
                                    (start, end, step)
                                }
                                _ => {
                                    return Err(CodegenError::UnsupportedFeature(
                                        "range() requires 1-3 arguments".to_string()
                                    ));
                                }
                            };

                            // Generate Yul for loop
                            code.push_str(&format!(
                                "{}for {{ let {} := {} }} lt({}, {}) {{ {} := add({}, {}) }}\n",
                                indent_str, for_stmt.variable, start, for_stmt.variable, end,
                                for_stmt.variable, for_stmt.variable, step
                            ));
                            code.push_str(&format!("{}{{\n", indent_str));

                            // Generate loop body
                            for stmt in &for_stmt.body {
                                code.push_str(&self.generate_statement(stmt, indent + 1)?);
                            }

                            code.push_str(&format!("{}}}\n", indent_str));
                        } else {
                            return Err(CodegenError::UnsupportedFeature(
                                format!("For loop over {} not supported (use range())", func_name)
                            ));
                        }
                    } else {
                        return Err(CodegenError::UnsupportedFeature(
                            "For loop iterable must be range() call".to_string()
                        ));
                    }
                } else {
                    return Err(CodegenError::UnsupportedFeature(
                        "For loop iterable must be range() call".to_string()
                    ));
                }
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

                // Use checked arithmetic for overflow-prone operations
                let op_code = match op {
                    BinOp::Add => "checked_add",  // ✅ Overflow protected
                    BinOp::Sub => "checked_sub",  // ✅ Underflow protected
                    BinOp::Mul => "checked_mul",  // ✅ Overflow protected
                    BinOp::Div => "checked_div",  // ✅ Division by zero protected
                    BinOp::Mod => "checked_mod",  // ✅ Modulo by zero protected
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
                // Handle special built-in functions
                if let Expr::Ident(func_name) = &**func {
                    let arg_codes: Vec<_> = args
                        .iter()
                        .map(|a| self.generate_expression(a))
                        .collect::<Result<_, _>>()?;

                    match func_name.as_str() {
                        "address" => {
                            // address(0) -> 0, address(x) -> x
                            if args.len() == 1 {
                                Ok(arg_codes[0].clone())
                            } else {
                                Err(CodegenError::UnsupportedFeature("address() requires 1 argument".to_string()))
                            }
                        }
                        "safe_add" => {
                            // ✅ Use checked_add for overflow protection
                            if args.len() == 2 {
                                Ok(format!("checked_add({}, {})", arg_codes[0], arg_codes[1]))
                            } else {
                                Err(CodegenError::UnsupportedFeature("safe_add requires 2 arguments".to_string()))
                            }
                        }
                        "safe_sub" => {
                            // ✅ Use checked_sub for underflow protection
                            if args.len() == 2 {
                                Ok(format!("checked_sub({}, {})", arg_codes[0], arg_codes[1]))
                            } else {
                                Err(CodegenError::UnsupportedFeature("safe_sub requires 2 arguments".to_string()))
                            }
                        }
                        "safe_mul" => {
                            // ✅ Use checked_mul for overflow protection
                            if args.len() == 2 {
                                Ok(format!("checked_mul({}, {})", arg_codes[0], arg_codes[1]))
                            } else {
                                Err(CodegenError::UnsupportedFeature("safe_mul requires 2 arguments".to_string()))
                            }
                        }
                        "safe_div" => {
                            // ✅ Use checked_div for division by zero protection
                            if args.len() == 2 {
                                Ok(format!("checked_div({}, {})", arg_codes[0], arg_codes[1]))
                            } else {
                                Err(CodegenError::UnsupportedFeature("safe_div requires 2 arguments".to_string()))
                            }
                        }
                        _ => {
                            // Regular function call
                            Ok(format!("{}({})", func_name, arg_codes.join(", ")))
                        }
                    }
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
