//! Storage layout calculation for EVM
//!
//! Calculates and manages storage slot assignments for contract state variables.

use quorlin_parser::{ContractMember, StateVar, Type};
use std::collections::HashMap;

/// Storage layout information for a contract
#[derive(Debug, Clone)]
pub struct StorageLayout {
    /// Map from variable name to storage slot
    pub slots: HashMap<String, SlotInfo>,
    /// Next available storage slot
    pub next_slot: usize,
}

/// Information about a storage slot
#[derive(Debug, Clone)]
pub struct SlotInfo {
    /// Storage slot number
    pub slot: usize,
    /// Variable type
    pub var_type: Type,
    /// Size in slots (for complex types)
    pub size: usize,
}

impl StorageLayout {
    /// Create a new empty storage layout
    pub fn new() -> Self {
        StorageLayout {
            slots: HashMap::new(),
            next_slot: 0,
        }
    }

    /// Allocate storage for contract members
    pub fn allocate(&mut self, members: &[ContractMember]) -> Result<(), String> {
        for member in members {
            if let ContractMember::StateVar(var) = member {
                self.allocate_variable(var)?;
            }
        }
        Ok(())
    }

    /// Allocate storage for a single variable
    fn allocate_variable(&mut self, var: &StateVar) -> Result<(), String> {
        let size = self.calculate_type_size(&var.type_annotation);

        self.slots.insert(
            var.name.clone(),
            SlotInfo {
                slot: self.next_slot,
                var_type: var.type_annotation.clone(),
                size,
            },
        );

        self.next_slot += size;
        Ok(())
    }

    /// Calculate how many storage slots a type occupies
    fn calculate_type_size(&self, typ: &Type) -> usize {
        match typ {
            // Simple types take 1 slot
            Type::Simple(_) => 1,

            // Mappings and dynamic arrays take 1 slot for the base pointer
            Type::Mapping(_, _) => 1,
            Type::List(_) => 1,

            // Fixed arrays take size * element_size slots
            Type::FixedArray(inner, size) => {
                size * self.calculate_type_size(inner)
            }

            // Optional types same as inner type
            Type::Optional(inner) => self.calculate_type_size(inner),

            // Tuples take sum of all element sizes
            Type::Tuple(types) => {
                types.iter().map(|t| self.calculate_type_size(t)).sum()
            }
        }
    }

    /// Get storage slot for a variable
    pub fn get_slot(&self, name: &str) -> Option<usize> {
        self.slots.get(name).map(|info| info.slot)
    }

    /// Get storage information for a variable
    pub fn get_info(&self, name: &str) -> Option<&SlotInfo> {
        self.slots.get(name)
    }

    /// Calculate storage slot for mapping access
    /// Returns the slot calculation expression as a string
    pub fn calculate_mapping_slot(base_slot: usize, key_expr: &str) -> String {
        // In EVM, mapping slot = keccak256(key . base_slot)
        format!("keccak256({}, {})", key_expr, base_slot)
    }

    /// Calculate storage slot for nested mapping access
    pub fn calculate_nested_mapping_slot(
        base_slot: usize,
        key1_expr: &str,
        key2_expr: &str,
    ) -> String {
        // First level: keccak256(key1 . base_slot)
        // Second level: keccak256(key2 . first_slot)
        format!(
            "keccak256({}, keccak256({}, {}))",
            key2_expr, key1_expr, base_slot
        )
    }

    /// Generate a storage layout report
    pub fn generate_report(&self) -> String {
        let mut report = String::new();
        report.push_str("Storage Layout:\n");
        report.push_str("===============\n\n");

        let mut slots: Vec<_> = self.slots.iter().collect();
        slots.sort_by_key(|(_, info)| info.slot);

        for (name, info) in slots {
            report.push_str(&format!(
                "Slot {}: {} (type: {:?}, size: {} slot{})\n",
                info.slot,
                name,
                info.var_type,
                info.size,
                if info.size == 1 { "" } else { "s" }
            ));
        }

        report.push_str(&format!("\nTotal slots used: {}\n", self.next_slot));
        report
    }
}

impl Default for StorageLayout {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_simple_type_size() {
        let layout = StorageLayout::new();
        assert_eq!(layout.calculate_type_size(&Type::Simple("uint256".to_string())), 1);
        assert_eq!(layout.calculate_type_size(&Type::Simple("address".to_string())), 1);
    }

    #[test]
    fn test_mapping_slot_calculation() {
        let slot_expr = StorageLayout::calculate_mapping_slot(5, "key");
        assert!(slot_expr.contains("keccak256"));
        assert!(slot_expr.contains("key"));
        assert!(slot_expr.contains("5"));
    }

    #[test]
    fn test_storage_allocation() {
        let mut layout = StorageLayout::new();

        let var1 = StateVar {
            name: "balance".to_string(),
            type_annotation: Type::Simple("uint256".to_string()),
            initial_value: None,
        };

        let var2 = StateVar {
            name: "owner".to_string(),
            type_annotation: Type::Simple("address".to_string()),
            initial_value: None,
        };

        layout.allocate_variable(&var1).unwrap();
        layout.allocate_variable(&var2).unwrap();

        assert_eq!(layout.get_slot("balance"), Some(0));
        assert_eq!(layout.get_slot("owner"), Some(1));
        assert_eq!(layout.next_slot, 2);
    }
}
