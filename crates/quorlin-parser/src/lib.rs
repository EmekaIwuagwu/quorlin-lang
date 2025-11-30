//! # Quorlin Parser
//!
//! Parser for the Quorlin smart contract language.
//!
//! This crate will contain the LALRPOP-based parser that converts
//! token streams into an Abstract Syntax Tree (AST).

pub mod ast;

// Re-export main types
pub use ast::*;
