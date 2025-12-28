use quorlin_parser::{Module, Item, ContractMember, Type, Expr, Stmt, BinOp, Pattern};
use thiserror::Error;

#[derive(Error, Debug)]
pub enum CodegenError {
    #[error("Generate error: {0}")]
    GenerateError(String),
    #[error("Unsupported feature: {0}")]
    UnsupportedFeature(String),
}

pub type CodegenResult<T> = Result<T, CodegenError>;

pub struct RustCodegen;

impl RustCodegen {
    pub fn new() -> Self {
        Self
    }

    pub fn generate(&mut self, module: &Module) -> CodegenResult<String> {
        let mut code = String::new();
        
        // Add standard imports
        code.push_str("#![allow(unused_imports)]\n");
        code.push_str("use std::collections::HashMap;\n");
        code.push_str("\n");

        for item in &module.items {
            match item {
                Item::Contract(contract) => {
                    self.generate_contract(contract, &mut code)?;
                }
                Item::Struct(struct_decl) => {
                    // TODO: Implement struct generation
                    code.push_str(&format!("// Struct: {}\n", struct_decl.name));
                }
                _ => {}
            }
        }
        
        Ok(code)
    }

    fn generate_contract(&self, contract: &quorlin_parser::ContractDecl, code: &mut String) -> CodegenResult<()> {
        // Generate struct definition (State)
        code.push_str("#[derive(Debug)]\n");
        code.push_str(&format!("pub struct {} {{\n", contract.name));
        
        for member in &contract.body {
            if let ContractMember::StateVar(var) = member {
                let type_str = self.map_type(&var.type_annotation)?;
                code.push_str(&format!("    pub {}: {},\n", var.name, type_str));
            }
        }
        code.push_str("}\n\n");

        // Generate implementation
        code.push_str(&format!("impl {} {{\n", contract.name));
        
        // Generate constructor logic if likely needed, or just methods
        // Add a 'new' method by default
        code.push_str("    pub fn new() -> Self {\n");
        code.push_str("        Self::default()\n");
        code.push_str("    }\n\n");

        for member in &contract.body {
            if let ContractMember::Function(func) = member {
                self.generate_function(func, code)?;
            }
        }

        code.push_str("}\n\n");

        // Generate Default impl manually to handle Result/Vec initialization
        code.push_str(&format!("impl Default for {} {{\n", contract.name));
        code.push_str("    fn default() -> Self {\n");
        code.push_str("        Self {\n");
        for member in &contract.body {
            if let ContractMember::StateVar(var) = member {
                 let def = self.generate_default_value(&var.type_annotation);
                 code.push_str(&format!("            {}: {},\n", var.name, def));
            }
        }
        code.push_str("        }\n");
        code.push_str("    }\n");
        code.push_str("}\n");
        Ok(())
    }

    fn generate_function(&self, func: &quorlin_parser::Function, code: &mut String) -> CodegenResult<()> {
        let mut params = vec!["&mut self".to_string()]; // All functions take &mut self for now
        
        for param in &func.params {
            let type_str = self.map_type(&param.type_annotation)?;
            params.push(format!("{}: {}", param.name, type_str));
        }

        let return_type = if let Some(rt) = &func.return_type {
             format!(" -> {}", self.map_type(rt)?)
        } else {
            String::new()
        };

        code.push_str(&format!("    pub fn {}({}){} {{\n", func.name, params.join(", "), return_type));
        
        for stmt in &func.body {
            let stmt_code = self.generate_stmt(stmt)?;
            code.push_str(&format!("        {}\n", stmt_code));
        }

        code.push_str("    }\n\n");
        Ok(())
    }

    fn generate_stmt(&self, stmt: &Stmt) -> CodegenResult<String> {
        match stmt {
            Stmt::Assign(assign) => {
                let target = self.generate_expr(&assign.target)?;
                let value = self.generate_expr(&assign.value)?;
                
                // Rust requires 'let' for new variables, nothing for reassignment
                // Simplistic check: if target is just a name and not 'self.', it's a local binding 'let'
                // This is crude. Ideally we check symbol table definition.
                // For now, assume assignments to 'self.*' are updates, others are 'let'.
                
                if target.starts_with("self.") {
                    Ok(format!("{} = {};", target, value))
                } else {
                    // Type annotation if present
                    if let Some(ty) = &assign.type_annotation {
                         let type_str = self.map_type(ty)?;
                         Ok(format!("let {}: {} = {};", target, type_str, value))
                    } else {
                         Ok(format!("let {} = {};", target, value))
                    }
                }
            }
            Stmt::Return(expr) => {
                if let Some(e) = expr {
                    Ok(format!("return {};", self.generate_expr(e)?))
                } else {
                    Ok("return;".to_string())
                }
            }
            Stmt::If(if_stmt) => {
                // Simplified If support
                let cond = self.generate_expr(&if_stmt.condition)?;
                let mut s = format!("if {} {{\n", cond);
                for st in &if_stmt.then_branch {
                    s.push_str(&format!("            {}\n", self.generate_stmt(st)?));
                }
                s.push_str("        }");
                // TODO: else branch
                Ok(s)
            }
            Stmt::Expr(expr) => {
                 Ok(format!("{};", self.generate_expr(expr)?))
            }
            _ => Ok("// Unimplemented statement".to_string())
        }
    }

    fn generate_expr(&self, expr: &Expr) -> CodegenResult<String> {
        match expr {
            Expr::Ident(name) => {
                if name == "self" {
                    Ok("self".to_string())
                } else {
                    Ok(name.clone())
                }
            }
            Expr::IntLiteral(n) => Ok(n.clone()), // Assumption: n is valid integer string
            Expr::StringLiteral(s) => Ok(format!("\"{}\".to_string()", s)),
            Expr::List(items) => {
                let mut parts = Vec::new();
                for item in items {
                    parts.push(self.generate_expr(item)?);
                }
                Ok(format!("vec![{}]", parts.join(", ")))
            }
            Expr::Attribute(base, attr) => {
                let base_str = self.generate_expr(base)?;
                Ok(format!("{}.{}", base_str, attr))
            }
            Expr::Call(func, args) => {
                let func_str = self.generate_expr(func)?;
                let mut arg_strs = Vec::new();
                for arg in args {
                    let mut arg_code = self.generate_expr(arg)?;
                    // Auto-clone field accesses to satisfy Rust borrow checker
                    // This is heuristic but works for simple cases like self.field
                    if arg_code.starts_with("self.") {
                        arg_code.push_str(".clone()");
                    }
                    arg_strs.push(arg_code);
                }
                
                // Handle specific Rust conversions if needed
                if func_str == "len" {
                     // Quorlin: len(x). Rust: x.len()
                     if arg_strs.len() == 1 {
                         return Ok(format!("{}.len() as u128", arg_strs[0]));
                     }
                }
                
                Ok(format!("{}({})", func_str, arg_strs.join(", ")))
            }
            Expr::BinOp(left, op, right) => {
                 let l = self.generate_expr(left)?;
                 let r = self.generate_expr(right)?;
                 let op_str = match op {
                     BinOp::Add => "+",
                     BinOp::Sub => "-",
                     BinOp::Mul => "*",
                     BinOp::Div => "/",
                     BinOp::Eq => "==",
                     BinOp::NotEq => "!=",
                     BinOp::Lt => "<",
                     BinOp::Gt => ">",
                     _ => "/* op */"
                 };
                 Ok(format!("{} {} {}", l, op_str, r))
            }
            Expr::Index(obj, index) => {
                let o = self.generate_expr(obj)?;
                let i = self.generate_expr(index)?;
                // Cast index to usize for Rust vectors
                Ok(format!("{}[{} as usize]", o, i))
            }
            Expr::Try(inner) => {
                let e = self.generate_expr(inner)?;
                // Rust '?' operator
                Ok(format!("{}?", e))
            }
            Expr::Match { subject, arms } => {
                let subj = self.generate_expr(subject)?;
                let mut rules = Vec::new();
                for arm in arms {
                    let pat = self.generate_pattern(&arm.pattern)?;
                    let body = self.generate_expr(&arm.body)?;
                    rules.push(format!("{} => {},", pat, body));
                }
                
                Ok(format!("match {} {{\n{}\n}}", subj, rules.join("\n")))
            }
            Expr::FStringLiteral(s) => {
                // Parse f-string content: "Hello {name}!"
                // We need to convert to format!("Hello {}!", name)
                
                let mut format_str = String::new();
                let mut args = Vec::new();
                
                let mut chars = s.chars().peekable();
                while let Some(c) = chars.next() {
                    if c == '{' {
                        // Check if escaped {{
                         if let Some(&next_c) = chars.peek() {
                             if next_c == '{' {
                                 chars.next();
                                 format_str.push('{');
                                 continue;
                             }
                         }
                         
                         // Parse interpolation variable
                         let mut var_name = String::new();
                         let mut closed = false;
                         while let Some(ic) = chars.next() {
                             if ic == '}' {
                                 closed = true;
                                 break;
                             }
                             var_name.push(ic);
                         }
                         
                         if closed {
                             format_str.push_str("{}");
                             // Assume var_name is a valid expression/ident. 
                             // We should technically parse it as Expr, but usually it's Ident.
                             // For safety, just pass it raw assuming it's an identifier.
                             args.push(var_name);
                         } else {
                             // Unclosed brace, treat literally? Or error?
                             format_str.push('{');
                             format_str.push_str(&var_name);
                         }
                    } else {
                        format_str.push(c);
                    }
                }
                
                if args.is_empty() {
                    Ok(format!("\"{}\".to_string()", format_str))
                } else {
                    Ok(format!("format!(\"{}\", {})", format_str, args.join(", ")))
                }
            }
            _ => Ok("/* Unimplemented Expr */".to_string())
        }
    }

    fn generate_pattern(&self, pat: &Pattern) -> CodegenResult<String> {
        match pat {
            Pattern::Literal(expr) => self.generate_expr(expr),
            Pattern::Ident(name) => Ok(name.clone()),
            Pattern::Wildcard => Ok("_".to_string()),
            Pattern::Variant(name, subpats) => {
                 // Enum variant
                 let mut parts = Vec::new();
                 for p in subpats {
                     parts.push(self.generate_pattern(p)?);
                 }
                 if parts.is_empty() {
                     Ok(name.clone())
                 } else {
                     Ok(format!("{}({})", name, parts.join(", ")))
                 }
            }
        }
    }

    fn generate_default_value(&self, ty: &Type) -> String {
        match ty {
            Type::List(_) => "vec![]".to_string(),
            Type::Generic(name, _) if name == "Result" => "Ok(Default::default())".to_string(),
            Type::Simple(name) => match name.as_str() {
                 "uint256" | "int" | "uint" | "uint64" | "uint32" | "uint16" | "uint8" => "0".to_string(),
                 "string" => "String::new()".to_string(),
                 "bool" => "false".to_string(),
                 _ => "Default::default()".to_string(),
            },
            _ => "Default::default()".to_string()
        }
    }

    fn map_type(&self, ty: &Type) -> CodegenResult<String> {
        match ty {
            Type::Simple(name) => match name.as_str() {
                "uint256" | "int" => Ok("u128".to_string()),
                "uint64" | "uint" => Ok("u64".to_string()),
                "uint32" => Ok("u32".to_string()),
                "uint16" => Ok("u16".to_string()),
                "uint8" | "byte" => Ok("u8".to_string()),
                "string" | "str" => Ok("String".to_string()),
                "bool" => Ok("bool".to_string()),
                "address" => Ok("String".to_string()), // Address as string in native?
                _ => Ok(name.clone())
            },
            Type::List(inner) => {
                Ok(format!("Vec<{}>", self.map_type(inner)?))
            },
            Type::Generic(name, args) => {
                if name == "List" && args.len() == 1 {
                    Ok(format!("Vec<{}>", self.map_type(&args[0])?))
                } else if name == "Result" && args.len() == 2 {
                    Ok(format!("Result<{}, {}>", self.map_type(&args[0])?, self.map_type(&args[1])?))
                } else {
                     let inner_strs: Result<Vec<_>, _> = args.iter().map(|arg| self.map_type(arg)).collect();
                     Ok(format!("{}<{}>", name, inner_strs?.join(", ")))
                }
            }
             _ => Ok("()".to_string()) // Fallback Unit
        }
    }
}
