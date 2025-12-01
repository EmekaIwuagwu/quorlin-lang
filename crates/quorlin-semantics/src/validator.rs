//! Semantic validation rules for Quorlin

use crate::{SemanticError, SemanticResult};

/// Valid decorators for functions
const VALID_FUNCTION_DECORATORS: &[&str] = &[
    "public",
    "view",
    "internal",
    "payable",
    "external",
    "constructor",
];

/// Validate a decorator on a given construct
pub fn validate_decorator(decorator: &str, construct: &str) -> SemanticResult<()> {
    match construct {
        "function" => {
            if !VALID_FUNCTION_DECORATORS.contains(&decorator) {
                return Err(SemanticError::InvalidDecorator(
                    decorator.to_string(),
                    construct.to_string(),
                ));
            }
            Ok(())
        }
        _ => Err(SemanticError::ValidationError(format!(
            "Unknown construct type: {}",
            construct
        ))),
    }
}

/// Validate that @view functions don't modify state
pub fn validate_view_function_purity(decorators: &[String], modifies_state: bool) -> SemanticResult<()> {
    if decorators.contains(&"view".to_string()) && modifies_state {
        return Err(SemanticError::ValidationError(
            "@view functions cannot modify state".to_string(),
        ));
    }
    Ok(())
}

/// Validate constructor requirements
pub fn validate_constructor(has_init: bool, state_vars_count: usize) -> SemanticResult<()> {
    if state_vars_count > 0 && !has_init {
        return Err(SemanticError::ValidationError(
            "Contracts with state variables must have an __init__ constructor".to_string(),
        ));
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_valid_decorator() {
        assert!(validate_decorator("public", "function").is_ok());
        assert!(validate_decorator("view", "function").is_ok());
        assert!(validate_decorator("internal", "function").is_ok());
        assert!(validate_decorator("payable", "function").is_ok());
    }

    #[test]
    fn test_invalid_decorator() {
        let result = validate_decorator("invalid", "function");
        assert!(result.is_err());
        assert!(matches!(result, Err(SemanticError::InvalidDecorator(_, _))));
    }

    #[test]
    fn test_view_function_validation() {
        let view_decorators = vec!["view".to_string()];
        assert!(validate_view_function_purity(&view_decorators, false).is_ok());
        assert!(validate_view_function_purity(&view_decorators, true).is_err());

        let no_decorators: Vec<String> = vec![];
        assert!(validate_view_function_purity(&no_decorators, true).is_ok());
    }
}
