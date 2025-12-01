//! Yul code generation utilities
//!
//! Helper functions for generating clean and optimized Yul code.

use std::fmt::Write;

/// Yul code builder with indentation support
pub struct YulBuilder {
    code: String,
    indent_level: usize,
    indent_size: usize,
}

impl YulBuilder {
    /// Create a new Yul code builder
    pub fn new() -> Self {
        YulBuilder {
            code: String::new(),
            indent_level: 0,
            indent_size: 2,
        }
    }

    /// Create a builder with custom indent size
    pub fn with_indent_size(indent_size: usize) -> Self {
        YulBuilder {
            code: String::new(),
            indent_level: 0,
            indent_size,
        }
    }

    /// Add a line with proper indentation
    pub fn line(&mut self, text: &str) {
        self.indent();
        writeln!(self.code, "{}", text).unwrap();
    }

    /// Add a comment line
    pub fn comment(&mut self, text: &str) {
        self.indent();
        writeln!(self.code, "// {}", text).unwrap();
    }

    /// Add raw text without newline
    pub fn raw(&mut self, text: &str) {
        write!(self.code, "{}", text).unwrap();
    }

    /// Add current indentation
    fn indent(&mut self) {
        for _ in 0..(self.indent_level * self.indent_size) {
            write!(self.code, " ").unwrap();
        }
    }

    /// Increase indentation level
    pub fn indent_more(&mut self) {
        self.indent_level += 1;
    }

    /// Decrease indentation level
    pub fn indent_less(&mut self) {
        if self.indent_level > 0 {
            self.indent_level -= 1;
        }
    }

    /// Add opening brace and increase indent
    pub fn open_block(&mut self) {
        self.raw(" {\n");
        self.indent_more();
    }

    /// Decrease indent and add closing brace
    pub fn close_block(&mut self) {
        self.indent_less();
        self.line("}");
    }

    /// Get the generated code
    pub fn build(self) -> String {
        self.code
    }

    /// Get current code length
    pub fn len(&self) -> usize {
        self.code.len()
    }

    /// Check if builder is empty
    pub fn is_empty(&self) -> bool {
        self.code.is_empty()
    }
}

impl Default for YulBuilder {
    fn default() -> Self {
        Self::new()
    }
}

/// Helper functions for common Yul patterns
pub mod helpers {
    /// Generate safe add with overflow check
    pub fn safe_add(a: &str, b: &str, revert_on_overflow: bool) -> String {
        if revert_on_overflow {
            format!(
                "{{\n          let result := add({}, {})\n          if lt(result, {}) {{ revert(0, 0) }}\n          result\n        }}",
                a, b, a
            )
        } else {
            format!("add({}, {})", a, b)
        }
    }

    /// Generate safe sub with underflow check
    pub fn safe_sub(a: &str, b: &str, revert_on_underflow: bool) -> String {
        if revert_on_underflow {
            format!(
                "{{\n          if lt({}, {}) {{ revert(0, 0) }}\n          sub({}, {})\n        }}",
                a, b, a, b
            )
        } else {
            format!("sub({}, {})", a, b)
        }
    }

    /// Generate safe mul with overflow check
    pub fn safe_mul(a: &str, b: &str, revert_on_overflow: bool) -> String {
        if revert_on_overflow {
            format!(
                "{{\n          let result := mul({}, {})\n          if iszero(or(iszero({}), eq(div(result, {}), {}))) {{ revert(0, 0) }}\n          result\n        }}",
                a, b, b, b, a
            )
        } else {
            format!("mul({}, {})", a, b)
        }
    }

    /// Generate safe div with division by zero check
    pub fn safe_div(a: &str, b: &str) -> String {
        format!(
            "{{\n          if iszero({}) {{ revert(0, 0) }}\n          div({}, {})\n        }}",
            b, a, b
        )
    }

    /// Generate mapping storage slot calculation
    pub fn mapping_slot(key: &str, base_slot: usize) -> String {
        format!(
            "{{\n          mstore(0, {})\n          mstore(32, {})\n          keccak256(0, 64)\n        }}",
            key, base_slot
        )
    }

    /// Generate nested mapping storage slot calculation
    pub fn nested_mapping_slot(key1: &str, key2: &str, base_slot: usize) -> String {
        format!(
            "{{\n          mstore(0, {})\n          mstore(32, {})\n          let first_slot := keccak256(0, 64)\n          mstore(0, {})\n          mstore(32, first_slot)\n          keccak256(0, 64)\n        }}",
            key1, base_slot, key2
        )
    }

    /// Generate require statement
    pub fn require(condition: &str, message: Option<&str>) -> String {
        if let Some(msg) = message {
            format!("if iszero({}) {{ revert(0, 0) }} // {}", condition, msg)
        } else {
            format!("if iszero({}) {{ revert(0, 0) }}", condition)
        }
    }

    /// Generate event log
    pub fn log_event(data_offset: usize, data_size: usize, topic: &str, indexed_count: u8) -> String {
        match indexed_count {
            0 => format!("log0({}, {})", data_offset, data_size),
            1 => format!("log1({}, {}, {})", data_offset, data_size, topic),
            2 => format!("log2({}, {}, {}, topic1)", data_offset, data_size, topic),
            3 => format!("log3({}, {}, {}, topic1, topic2)", data_offset, data_size, topic),
            4 => format!("log4({}, {}, {}, topic1, topic2, topic3)", data_offset, data_size, topic),
            _ => format!("log0({}, {})", data_offset, data_size),
        }
    }

    /// Generate function selector from calldata
    pub fn function_selector() -> &'static str {
        "div(calldataload(0), 0x100000000000000000000000000000000000000000000000000000000)"
    }

    /// Load parameter from calldata
    pub fn load_param(index: usize) -> String {
        let offset = 4 + (index * 32);
        format!("calldataload({})", offset)
    }

    /// Return single value
    pub fn return_value(value: &str) -> String {
        format!("mstore(0, {})\n        return(0, 32)", value)
    }

    /// Return nothing
    pub fn return_empty() -> &'static str {
        "return(0, 0)"
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_yul_builder() {
        let mut builder = YulBuilder::new();
        builder.line("function test()");
        builder.open_block();
        builder.line("let x := 5");
        builder.close_block();

        let code = builder.build();
        assert!(code.contains("function test()"));
        assert!(code.contains("let x := 5"));
        assert!(code.contains("{"));
        assert!(code.contains("}"));
    }

    #[test]
    fn test_safe_add() {
        let code = helpers::safe_add("a", "b", true);
        assert!(code.contains("add(a, b)"));
        assert!(code.contains("revert"));
    }

    #[test]
    fn test_mapping_slot() {
        let code = helpers::mapping_slot("key", 5);
        assert!(code.contains("keccak256"));
        assert!(code.contains("key"));
        assert!(code.contains("5"));
    }
}
