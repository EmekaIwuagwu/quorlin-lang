//! # Quorlin Parser
//!
//! Parser for the Quorlin smart contract language.
//!
//! This crate contains a hand-written recursive descent parser that converts
//! token streams into an Abstract Syntax Tree (AST).
//!
//! We use a hand-written parser instead of LALRPOP because Python-style
//! indentation creates ambiguities that LR parser generators can't handle well.

// Quorlin Parser Library
pub mod ast;
pub mod parser;

use quorlin_lexer::Token;

// Re-export main types
pub use ast::*;
pub use parser::Parser;

/// Parser errors
#[derive(Debug, thiserror::Error)]
pub enum ParseError {
    #[error("Parse error at position {0}: {1}")]
    UnexpectedToken(usize, String),

    #[error("Unexpected end of file")]
    UnexpectedEof,
}

/// Parse a token stream into an AST Module
pub fn parse_module(tokens: Vec<Token>) -> Result<Module, ParseError> {
    let mut parser = Parser::new(tokens);
    parser.parse_module()
}

#[cfg(test)]
mod tests {
    use super::*;
    use quorlin_lexer::Lexer;

    #[test]
    fn test_parse_simple_contract() {
        let source = r#"
contract Test:
    value: uint256 = 0
"#;

        let lexer = Lexer::new(source);
        let tokens = lexer.tokenize().unwrap();
        let module = parse_module(tokens);

        assert!(module.is_ok(), "Failed to parse: {:?}", module.err());
        let module = module.unwrap();
        assert_eq!(module.items.len(), 1);
    }

    #[test]
    fn test_parse_event() {
        let source = r#"
event Transfer(from_addr: address, to_addr: address, value: uint256)
"#;

        let lexer = Lexer::new(source);
        let tokens = lexer.tokenize().unwrap();
        let module = parse_module(tokens);

        assert!(module.is_ok(), "Failed to parse: {:?}", module.err());
        let module = module.unwrap();
        assert_eq!(module.items.len(), 1);

        match &module.items[0] {
            Item::Event(event) => {
                assert_eq!(event.name, "Transfer");
                assert_eq!(event.params.len(), 3);
            }
            _ => panic!("Expected event item"),
        }
    }
}
