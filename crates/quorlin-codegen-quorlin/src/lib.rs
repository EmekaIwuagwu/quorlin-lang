use quorlin_parser::ast::*;

/// Quorlin bytecode generator
/// Generates a simple text representation of bytecode for now
pub struct QuorlinCodegen {
    output: String,
}

impl QuorlinCodegen {
    pub fn new() -> Self {
        Self {
            output: String::new(),
        }
    }

    pub fn generate(&mut self, module: &Module) -> Result<Vec<u8>, String> {
        // Generate header
        self.output.push_str("# Quorlin Bytecode\n");
        self.output.push_str("# Magic: QBC\\0\n");
        self.output.push_str("# Version: 1.0.0\n\n");

        // Generate code for each item
        for item in &module.items {
            match item {
                Item::Contract(contract) => {
                    self.generate_contract(contract)?;
                }
                Item::Event(event) => {
                    self.generate_event(event)?;
                }
                _ => {
                    // Skip other items for now
                }
            }
        }

        // Convert to bytes
        Ok(self.output.as_bytes().to_vec())
    }

    fn generate_contract(&mut self, contract: &ContractDecl) -> Result<(), String> {
        self.output.push_str(&format!("# Contract: {}\n\n", contract.name));

        // Generate state variables
        for member in &contract.body {
            if let ContractMember::StateVar(var) = member {
                self.output.push_str(&format!("# State: {} : {:?}\n", var.name, var.type_annotation));
            }
        }
        self.output.push_str("\n");

        // Generate functions
        for member in &contract.body {
            if let ContractMember::Function(func) = member {
                self.generate_function(func)?;
            }
        }

        Ok(())
    }

    fn generate_function(&mut self, func: &Function) -> Result<(), String> {
        self.output.push_str(&format!("# Function: {}\n", func.name));
        self.output.push_str(&format!("#   Params: {}\n", func.params.len()));
        self.output.push_str(&format!("#   Return: {:?}\n", func.return_type));
        
        // Generate simplified bytecode for function body
        self.output.push_str("FUNC_START\n");
        
        for stmt in &func.body {
            self.generate_statement(stmt)?;
        }
        
        self.output.push_str("FUNC_END\n\n");
        
        Ok(())
    }

    fn generate_statement(&mut self, stmt: &Stmt) -> Result<(), String> {
        match stmt {
            Stmt::Assign(assign) => {
                self.output.push_str(&format!("  ASSIGN {:?}\n", assign.target));
            }
            Stmt::Return(expr) => {
                if expr.is_some() {
                    self.output.push_str("  RETURN\n");
                } else {
                    self.output.push_str("  RETURN_VOID\n");
                }
            }
            Stmt::If(if_stmt) => {
                self.output.push_str("  IF\n");
                for stmt in &if_stmt.then_branch {
                    self.generate_statement(stmt)?;
                }
                if let Some(else_branch) = &if_stmt.else_branch {
                    self.output.push_str("  ELSE\n");
                    for stmt in else_branch {
                        self.generate_statement(stmt)?;
                    }
                }
                self.output.push_str("  END_IF\n");
            }
            Stmt::Expr(expr) => {
                self.output.push_str(&format!("  EXPR {:?}\n", expr));
            }
            Stmt::Require(req) => {
                self.output.push_str(&format!("  REQUIRE {:?}\n", req.message));
            }
            Stmt::Emit(emit) => {
                self.output.push_str(&format!("  EMIT {}\n", emit.event));
            }
            _ => {
                self.output.push_str("  # Other statement\n");
            }
        }
        Ok(())
    }

    fn generate_event(&mut self, event: &EventDecl) -> Result<(), String> {
        self.output.push_str(&format!("# Event: {}\n", event.name));
        for param in &event.params {
            self.output.push_str(&format!("#   {} : {:?}\n", param.name, param.type_annotation));
        }
        self.output.push_str("\n");
        Ok(())
    }
}

impl Default for QuorlinCodegen {
    fn default() -> Self {
        Self::new()
    }
}
