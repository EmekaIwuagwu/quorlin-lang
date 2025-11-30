//! # Quorlin Common
//!
//! Common utilities shared across the Quorlin compiler.

pub mod diagnostics;
pub mod span;

// Re-export commonly used types
pub use span::Span;
