//! # Backend Consistency Checker
//!
//! Validates that type mappings and semantics are consistent across all backends (EVM, Solana, ink!).
//!
//! This ensures that Quorlin code behaves consistently regardless of which blockchain it's deployed to.

use quorlin_parser::Type;
use std::collections::HashMap;

/// Backend type mapping errors
#[derive(Debug, Clone, PartialEq)]
pub enum ConsistencyError {
    /// Type not supported by all backends
    UnsupportedType {
        quorlin_type: String,
        missing_in: Vec<String>,
    },

    /// Type has different sizes across backends
    InconsistentSize {
        quorlin_type: String,
        evm_size: Option<u32>,
        solana_size: Option<u32>,
        ink_size: Option<u32>,
    },

    /// Type has different overflow behavior
    InconsistentOverflowBehavior {
        quorlin_type: String,
        details: String,
    },
}

impl std::fmt::Display for ConsistencyError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            ConsistencyError::UnsupportedType { quorlin_type, missing_in } => {
                write!(f, "Type '{}' not supported in: {}", quorlin_type, missing_in.join(", "))
            }
            ConsistencyError::InconsistentSize { quorlin_type, evm_size, solana_size, ink_size } => {
                write!(
                    f,
                    "Type '{}' has inconsistent sizes - EVM: {:?}, Solana: {:?}, ink!: {:?}",
                    quorlin_type, evm_size, solana_size, ink_size
                )
            }
            ConsistencyError::InconsistentOverflowBehavior { quorlin_type, details } => {
                write!(f, "Type '{}' has inconsistent overflow behavior: {}", quorlin_type, details)
            }
        }
    }
}

/// Type information for a backend
#[derive(Debug, Clone)]
struct BackendTypeInfo {
    supported: bool,
    bit_size: Option<u32>,
    checked_arithmetic: bool,
}

/// Backend consistency checker
pub struct BackendConsistencyChecker {
    type_mappings: HashMap<String, (BackendTypeInfo, BackendTypeInfo, BackendTypeInfo)>,
}

impl BackendConsistencyChecker {
    /// Create a new consistency checker
    pub fn new() -> Self {
        let mut checker = Self {
            type_mappings: HashMap::new(),
        };

        checker.initialize_type_mappings();
        checker
    }

    /// Initialize known type mappings
    fn initialize_type_mappings(&mut self) {
        // Unsigned integers
        self.add_type("uint8", 8, true, 8, true, 8, true);
        self.add_type("uint16", 16, true, 16, true, 16, true);
        self.add_type("uint32", 32, true, 32, true, 32, true);
        self.add_type("uint64", 64, true, 64, true, 64, true);
        self.add_type("uint128", 128, true, 128, true, 128, true);
        self.add_type("uint256", 256, true, 256, true, 256, true);

        // Signed integers
        self.add_type("int8", 8, true, 8, true, 8, true);
        self.add_type("int16", 16, true, 16, true, 16, true);
        self.add_type("int32", 32, true, 32, true, 32, true);
        self.add_type("int64", 64, true, 64, true, 64, true);
        self.add_type("int128", 128, true, 128, true, 128, true);
        self.add_type("int256", 256, true, 256, true, 256, true);

        // Boolean
        self.add_type("bool", 1, true, 1, true, 1, true);

        // Address
        self.add_type("address", 160, true, 256, true, 256, true);

        // Strings and bytes
        self.add_type_varied("str", true, None, true, None, true, None);
        self.add_type_varied("bytes", true, None, true, None, true, None);
        self.add_type("bytes32", 256, true, 256, true, 256, true);
    }

    /// Add a type with uniform support across backends
    fn add_type(
        &mut self,
        name: &str,
        evm_bits: u32,
        evm_checked: bool,
        solana_bits: u32,
        solana_checked: bool,
        ink_bits: u32,
        ink_checked: bool,
    ) {
        self.type_mappings.insert(
            name.to_string(),
            (
                BackendTypeInfo {
                    supported: true,
                    bit_size: Some(evm_bits),
                    checked_arithmetic: evm_checked,
                },
                BackendTypeInfo {
                    supported: true,
                    bit_size: Some(solana_bits),
                    checked_arithmetic: solana_checked,
                },
                BackendTypeInfo {
                    supported: true,
                    bit_size: Some(ink_bits),
                    checked_arithmetic: ink_checked,
                },
            ),
        );
    }

    /// Add a type with varied support
    fn add_type_varied(
        &mut self,
        name: &str,
        evm_supported: bool,
        evm_bits: Option<u32>,
        solana_supported: bool,
        solana_bits: Option<u32>,
        ink_supported: bool,
        ink_bits: Option<u32>,
    ) {
        self.type_mappings.insert(
            name.to_string(),
            (
                BackendTypeInfo {
                    supported: evm_supported,
                    bit_size: evm_bits,
                    checked_arithmetic: true,
                },
                BackendTypeInfo {
                    supported: solana_supported,
                    bit_size: solana_bits,
                    checked_arithmetic: true,
                },
                BackendTypeInfo {
                    supported: ink_supported,
                    bit_size: ink_bits,
                    checked_arithmetic: true,
                },
            ),
        );
    }

    /// Check a type for consistency
    pub fn check_type(&self, ty: &Type) -> Vec<ConsistencyError> {
        let mut errors = Vec::new();

        match ty {
            Type::Simple(name) => {
                if let Some((evm, solana, ink)) = self.type_mappings.get(name) {
                    // Check if supported by all backends
                    let mut missing = Vec::new();
                    if !evm.supported {
                        missing.push("EVM".to_string());
                    }
                    if !solana.supported {
                        missing.push("Solana".to_string());
                    }
                    if !ink.supported {
                        missing.push("ink!".to_string());
                    }

                    if !missing.is_empty() {
                        errors.push(ConsistencyError::UnsupportedType {
                            quorlin_type: name.clone(),
                            missing_in: missing,
                        });
                    }

                    // Check size consistency
                    if evm.bit_size != solana.bit_size || solana.bit_size != ink.bit_size {
                        errors.push(ConsistencyError::InconsistentSize {
                            quorlin_type: name.clone(),
                            evm_size: evm.bit_size,
                            solana_size: solana.bit_size,
                            ink_size: ink.bit_size,
                        });
                    }

                    // Check arithmetic consistency
                    if !evm.checked_arithmetic || !solana.checked_arithmetic || !ink.checked_arithmetic {
                        errors.push(ConsistencyError::InconsistentOverflowBehavior {
                            quorlin_type: name.clone(),
                            details: "Not all backends use checked arithmetic".to_string(),
                        });
                    }
                }
            }
            Type::Mapping(key_type, value_type) => {
                errors.extend(self.check_type(key_type));
                errors.extend(self.check_type(value_type));
            }
            Type::List(elem_type) => {
                errors.extend(self.check_type(elem_type));
            }
            Type::Tuple(types) => {
                for t in types {
                    errors.extend(self.check_type(t));
                }
            }
            _ => {}
        }

        errors
    }

    /// Generate a consistency report
    pub fn generate_report(&self) -> String {
        let mut report = String::from("# Backend Type Consistency Report\n\n");

        report.push_str("## Supported Types\n\n");
        report.push_str("| Type | EVM | Solana | ink! | Notes |\n");
        report.push_str("|------|-----|--------|------|-------|\n");

        let mut types: Vec<_> = self.type_mappings.keys().collect();
        types.sort();

        for name in types {
            if let Some((evm, solana, ink)) = self.type_mappings.get(name) {
                let evm_status = if evm.supported { "✅" } else { "❌" };
                let solana_status = if solana.supported { "✅" } else { "❌" };
                let ink_status = if ink.supported { "✅" } else { "❌" };

                let notes = if evm.bit_size == solana.bit_size && solana.bit_size == ink.bit_size {
                    format!("{} bits", evm.bit_size.map_or("variable".to_string(), |s| s.to_string()))
                } else {
                    format!(
                        "EVM: {}, Solana: {}, ink!: {}",
                        evm.bit_size.map_or("var".to_string(), |s| s.to_string()),
                        solana.bit_size.map_or("var".to_string(), |s| s.to_string()),
                        ink.bit_size.map_or("var".to_string(), |s| s.to_string())
                    )
                };

                report.push_str(&format!("| {} | {} | {} | {} | {} |\n", name, evm_status, solana_status, ink_status, notes));
            }
        }

        report.push_str("\n## Arithmetic Safety\n\n");
        report.push_str("All backends use checked arithmetic for integer operations to prevent overflow/underflow.\n");

        report
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_consistency_checker() {
        let checker = BackendConsistencyChecker::new();
        let uint256 = Type::Simple("uint256".to_string());
        let errors = checker.check_type(&uint256);
        assert_eq!(errors.len(), 0, "uint256 should be consistent across backends");
    }

    #[test]
    fn test_generate_report() {
        let checker = BackendConsistencyChecker::new();
        let report = checker.generate_report();
        assert!(report.contains("Backend Type Consistency Report"));
        assert!(report.contains("uint256"));
    }
}
