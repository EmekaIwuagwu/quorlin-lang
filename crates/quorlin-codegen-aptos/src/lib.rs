//! Quorlin to Aptos Move Code Generator
//!
//! Generates Move code for the Aptos blockchain from Quorlin AST.

pub mod move_gen;
pub mod types;

use quorlin_parser::ast::Module;
use thiserror::Error;

#[derive(Error, Debug)]
pub enum AptosCodegenError {
    #[error("Unsupported feature: {0}")]
    UnsupportedFeature(String),
    
    #[error("Type conversion error: {0}")]
    TypeConversion(String),
    
    #[error("Invalid Move syntax: {0}")]
    InvalidSyntax(String),
}

pub struct AptosCodegen {
    module_address: String,
}

impl AptosCodegen {
    pub fn new(module_address: String) -> Self {
        Self { module_address }
    }
    
    pub fn generate(&self, module: &Module) -> Result<String, AptosCodegenError> {
        let mut generator = move_gen::MoveGenerator::new(&self.module_address);
        generator.generate_module(module)
    }
}

impl Default for AptosCodegen {
    fn default() -> Self {
        Self::new("0x1".to_string())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use quorlin_parser::parse;
    
    #[test]
    fn test_simple_contract() {
        let source = r#"
contract SimpleStorage:
    _value: uint256
    
    fn set(value: uint256):
        self._value = value
    
    fn get() -> uint256:
        return self._value
"#;
        
        let module = parse(source).expect("Failed to parse");
        let codegen = AptosCodegen::default();
        let move_code = codegen.generate(&module).expect("Failed to generate");
        
        assert!(move_code.contains("module"));
        assert!(move_code.contains("struct"));
        assert!(move_code.contains("public entry fun"));
    }
}
