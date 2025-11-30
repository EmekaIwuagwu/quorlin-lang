//! # Quorlin Lexer
//!
//! Lexical analysis for the Quorlin smart contract language.
//!
//! This crate provides tokenization with Python-style indentation handling,
//! converting `.ql` source code into a stream of tokens with INDENT/DEDENT
//! markers that make whitespace-based syntax parsing possible.
//!
//! ## Example
//!
//! ```rust
//! use quorlin_lexer::Lexer;
//!
//! let source = r#"
//! contract Token:
//!     name: str = "My Token"
//! "#;
//!
//! let lexer = Lexer::new(source);
//! let tokens = lexer.tokenize().expect("Failed to tokenize");
//!
//! // tokens now contains the full token stream with INDENT/DEDENT
//! ```

pub mod indent;
pub mod lexer;
pub mod token;

// Re-export main types for convenience
pub use lexer::{Lexer, LexerError};
pub use token::{Span, Token, TokenType};
