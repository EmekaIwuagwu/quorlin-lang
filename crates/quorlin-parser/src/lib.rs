//! # Quorlin Parser
//!
//! Parser for the Quorlin smart contract language.
//!
//! This crate contains the LALRPOP-based parser that converts
//! token streams into an Abstract Syntax Tree (AST).

pub mod ast;

// Include the generated LALRPOP parser
// Using simplified grammar for MVP
#[allow(clippy::all)]
mod grammar_simple {
    include!(concat!(env!("OUT_DIR"), "/grammar_simple.rs"));
}

use quorlin_lexer::{Token, TokenType};

// Re-export main types
pub use ast::*;

/// Parser errors
#[derive(Debug, thiserror::Error)]
pub enum ParseError {
    #[error("Parse error at position {0}: {1}")]
    LalrpopError(usize, String),

    #[error("Unexpected token: {0:?}")]
    UnexpectedToken(TokenType),

    #[error("Unexpected end of file")]
    UnexpectedEof,
}

/// Parse a token stream into an AST Module
pub fn parse_module(tokens: Vec<Token>) -> Result<Module, ParseError> {
    // Convert our tokens to the format LALRPOP expects
    let lalrpop_tokens = tokens
        .into_iter()
        .map(|t| Ok((t.span.start, t.token_type, t.span.end)))
        .collect::<Vec<_>>();

    // Call the generated parser (using simplified grammar for MVP)
    grammar_simple::ModuleParser::new()
        .parse(lalrpop_tokens.into_iter())
        .map_err(|e| ParseError::LalrpopError(0, format!("{:?}", e)))
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
