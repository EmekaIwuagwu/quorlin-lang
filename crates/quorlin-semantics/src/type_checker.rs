//! Type checking and inference for Quorlin

use crate::{SemanticError, SemanticResult};
use quorlin_parser::Type;

/// Check if two types are compatible
pub fn types_compatible(expected: &Type, found: &Type) -> bool {
    match (expected, found) {
        (Type::Simple(e), Type::Simple(f)) => {
            // Exact match
            if e == f {
                return true;
            }

            // Allow numeric promotions: uint8 -> uint256, etc.
            if is_numeric_type(e) && is_numeric_type(f) {
                return can_promote(f, e);
            }

            false
        }
        (Type::List(e), Type::List(f)) => types_compatible(e, f),
        (Type::Mapping(ek, ev), Type::Mapping(fk, fv)) => {
            types_compatible(ek, fk) && types_compatible(ev, fv)
        }
        _ => false,
    }
}

/// Check type compatibility and return error if incompatible
pub fn check_type_compatibility(
    expected: &Type,
    found: &Type,
) -> SemanticResult<()> {
    if types_compatible(expected, found) {
        Ok(())
    } else {
        Err(SemanticError::TypeMismatch {
            expected: format!("{:?}", expected),
            found: format!("{:?}", found),
        })
    }
}

/// Check if a type is numeric
fn is_numeric_type(ty: &str) -> bool {
    matches!(
        ty,
        "uint8" | "uint16" | "uint32" | "uint64" | "uint128" | "uint256"
            | "int8" | "int16" | "int32" | "int64" | "int128" | "int256"
    )
}

/// Check if type `from` can be promoted to type `to`
fn can_promote(from: &str, to: &str) -> bool {
    let from_size = get_type_size(from);
    let to_size = get_type_size(to);

    // Can only promote to larger or equal size
    from_size <= to_size
}

/// Get the size of a numeric type (in bits)
fn get_type_size(ty: &str) -> u32 {
    match ty {
        "uint8" | "int8" => 8,
        "uint16" | "int16" => 16,
        "uint32" | "int32" => 32,
        "uint64" | "int64" => 64,
        "uint128" | "int128" => 128,
        "uint256" | "int256" => 256,
        _ => 0,
    }
}

/// Infer the result type of a binary operation
pub fn infer_binop_type(
    left: &Type,
    right: &Type,
    op: &quorlin_parser::BinOp,
) -> SemanticResult<Type> {
    use quorlin_parser::BinOp;

    match op {
        BinOp::Add | BinOp::Sub | BinOp::Mul | BinOp::Div | BinOp::Mod | BinOp::Pow => {
            // Arithmetic operations: both sides must be numeric
            if let (Type::Simple(l), Type::Simple(r)) = (left, right) {
                if is_numeric_type(l) && is_numeric_type(r) {
                    // Result type is the larger of the two
                    let result_type = if get_type_size(l) >= get_type_size(r) {
                        l.clone()
                    } else {
                        r.clone()
                    };
                    return Ok(Type::Simple(result_type));
                }
            }
            Err(SemanticError::TypeMismatch {
                expected: "numeric types".to_string(),
                found: format!("{:?} and {:?}", left, right),
            })
        }
        BinOp::Eq | BinOp::NotEq | BinOp::Lt | BinOp::LtEq | BinOp::Gt | BinOp::GtEq => {
            // Comparison operations: result is always bool
            Ok(Type::Simple("bool".to_string()))
        }
        BinOp::And | BinOp::Or => {
            // Logical operations: both sides must be bool
            if let (Type::Simple(l), Type::Simple(r)) = (left, right) {
                if l == "bool" && r == "bool" {
                    return Ok(Type::Simple("bool".to_string()));
                }
            }
            Err(SemanticError::TypeMismatch {
                expected: "bool".to_string(),
                found: format!("{:?} and {:?}", left, right),
            })
        }
        _ => Ok(Type::Simple("unknown".to_string())),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_type_compatibility() {
        let uint256 = Type::Simple("uint256".to_string());
        let uint8 = Type::Simple("uint8".to_string());
        let bool_type = Type::Simple("bool".to_string());

        // Same types are compatible
        assert!(types_compatible(&uint256, &uint256));
        assert!(types_compatible(&bool_type, &bool_type));

        // Numeric promotion
        assert!(types_compatible(&uint256, &uint8)); // uint8 can promote to uint256
        assert!(!types_compatible(&uint8, &uint256)); // uint256 cannot fit in uint8

        // Different types are not compatible
        assert!(!types_compatible(&uint256, &bool_type));
    }

    #[test]
    fn test_binop_type_inference() {
        use quorlin_parser::BinOp;

        let uint256 = Type::Simple("uint256".to_string());
        let uint8 = Type::Simple("uint8".to_string());

        // Arithmetic operations
        let result = infer_binop_type(&uint256, &uint8, &BinOp::Add).unwrap();
        assert_eq!(result, Type::Simple("uint256".to_string()));

        // Comparison operations
        let result = infer_binop_type(&uint256, &uint256, &BinOp::Lt).unwrap();
        assert_eq!(result, Type::Simple("bool".to_string()));
    }
}
