//! Type mapping from Quorlin to Move

use quorlin_parser::ast::Type;
use crate::AptosCodegenError;

pub struct TypeMapper;

impl TypeMapper {
    /// Converts a Quorlin type to Move type
    pub fn to_move_type(ty: &Type) -> Result<String, AptosCodegenError> {
        match ty {
            Type::Simple(name) => Self::map_simple_type(name),
            Type::List(inner) => {
                let inner_type = Self::to_move_type(inner)?;
                Ok(format!("vector<{}>", inner_type))
            }
            Type::Mapping(key, value) => {
                let key_type = Self::to_move_type(key)?;
                let value_type = Self::to_move_type(value)?;
                // Move uses Table for mappings
                Ok(format!("Table<{}, {}>", key_type, value_type))
            }
            Type::Optional(inner) => {
                let inner_type = Self::to_move_type(inner)?;
                Ok(format!("Option<{}>", inner_type))
            }
            Type::Tuple(types) => {
                let move_types: Result<Vec<_>, _> = types.iter()
                    .map(|t| Self::to_move_type(t))
                    .collect();
                Ok(format!("({})", move_types?.join(", ")))
            }
            Type::FixedArray(inner, size) => {
                // Move doesn't have fixed-size arrays, use vector
                let inner_type = Self::to_move_type(inner)?;
                Ok(format!("vector<{}> /* size: {} */", inner_type, size))
            }
        }
    }
    
    fn map_simple_type(name: &str) -> Result<String, AptosCodegenError> {
        let move_type = match name {
            // Integers
            "uint8" => "u8",
            "uint16" => "u16",
            "uint32" => "u32",
            "uint64" => "u64",
            "uint128" => "u128",
            "uint256" => "u256", // Aptos supports u256
            
            "int8" => "u8",   // Move doesn't have signed ints, use unsigned
            "int16" => "u16",
            "int32" => "u32",
            "int64" => "u64",
            "int128" => "u128",
            "int256" => "u256",
            
            // Boolean
            "bool" => "bool",
            
            // Address
            "address" => "address",
            
            // Bytes
            "bytes" => "vector<u8>",
            "bytes32" => "vector<u8>", // 32-byte vector
            "bytes4" => "vector<u8>",  // 4-byte vector
            
            // String
            "string" | "str" => "String",
            
            // Special types
            "none" => "()", // Unit type in Move
            
            // Default: assume it's a custom type
            custom => custom,
        };
        
        Ok(move_type.to_string())
    }
    
    /// Gets the default value for a type
    pub fn default_value(ty: &Type) -> Result<String, AptosCodegenError> {
        match ty {
            Type::Simple(name) => Self::simple_default(name),
            Type::List(_) => Ok("vector::empty()".to_string()),
            Type::Mapping(_, _) => Ok("table::new()".to_string()),
            Type::Optional(_) => Ok("option::none()".to_string()),
            Type::Tuple(_) => Ok("()".to_string()),
            Type::FixedArray(_, _) => Ok("vector::empty()".to_string()),
        }
    }
    
    fn simple_default(name: &str) -> Result<String, AptosCodegenError> {
        let default = match name {
            "uint8" | "uint16" | "uint32" | "uint64" | "uint128" | "uint256" => "0",
            "int8" | "int16" | "int32" | "int64" | "int128" | "int256" => "0",
            "bool" => "false",
            "address" => "@0x0",
            "bytes" | "bytes32" | "bytes4" => "vector::empty()",
            "string" | "str" => "string::utf8(b\"\")",
            "none" => "()",
            _ => "/* custom default */",
        };
        
        Ok(default.to_string())
    }
    
    /// Checks if a type needs to be stored as a resource
    pub fn is_resource_type(name: &str) -> bool {
        matches!(name, "address" | "signer")
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn test_simple_types() {
        assert_eq!(
            TypeMapper::map_simple_type("uint256").unwrap(),
            "u256"
        );
        assert_eq!(
            TypeMapper::map_simple_type("address").unwrap(),
            "address"
        );
        assert_eq!(
            TypeMapper::map_simple_type("bool").unwrap(),
            "bool"
        );
    }
    
    #[test]
    fn test_list_type() {
        let list_type = Type::List(Box::new(Type::Simple("uint256".to_string())));
        assert_eq!(
            TypeMapper::to_move_type(&list_type).unwrap(),
            "vector<u256>"
        );
    }
    
    #[test]
    fn test_mapping_type() {
        let mapping = Type::Mapping(
            Box::new(Type::Simple("address".to_string())),
            Box::new(Type::Simple("uint256".to_string()))
        );
        assert_eq!(
            TypeMapper::to_move_type(&mapping).unwrap(),
            "Table<address, u256>"
        );
    }
}
