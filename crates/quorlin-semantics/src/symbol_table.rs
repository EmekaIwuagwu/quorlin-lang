//! Symbol table for name resolution and scope management

use crate::{SemanticError, SemanticResult};
use quorlin_parser::Type;
use std::collections::HashMap;

/// Symbol information
#[derive(Debug, Clone)]
pub enum Symbol {
    Variable { ty: Type },
    Function { name: String },
    Event { name: String },
    Contract { name: String },
}

/// Scope for symbol resolution
#[derive(Debug, Clone)]
struct Scope {
    symbols: HashMap<String, Symbol>,
}

impl Scope {
    fn new() -> Self {
        Self {
            symbols: HashMap::new(),
        }
    }

    fn define(&mut self, name: String, symbol: Symbol) -> SemanticResult<()> {
        if self.symbols.contains_key(&name) {
            return Err(SemanticError::DuplicateDefinition(name));
        }
        self.symbols.insert(name, symbol);
        Ok(())
    }

    fn lookup(&self, name: &str) -> Option<&Symbol> {
        self.symbols.get(name)
    }
}

/// Symbol table with scope stack
pub struct SymbolTable {
    scopes: Vec<Scope>,
    events: HashMap<String, Symbol>,
    contracts: HashMap<String, Symbol>,
}

impl SymbolTable {
    /// Create a new symbol table
    pub fn new() -> Self {
        Self {
            scopes: vec![Scope::new()], // Start with global scope
            events: HashMap::new(),
            contracts: HashMap::new(),
        }
    }

    /// Enter a new scope
    pub fn enter_scope(&mut self) {
        self.scopes.push(Scope::new());
    }

    /// Exit the current scope
    pub fn exit_scope(&mut self) {
        if self.scopes.len() > 1 {
            self.scopes.pop();
        }
    }

    /// Define a variable in the current scope
    pub fn define_variable(&mut self, name: &str, ty: &Type) -> SemanticResult<()> {
        if let Some(scope) = self.scopes.last_mut() {
            scope.define(
                name.to_string(),
                Symbol::Variable { ty: ty.clone() },
            )
        } else {
            Err(SemanticError::ValidationError(
                "No active scope".to_string(),
            ))
        }
    }

    /// Define a function in the current scope
    pub fn define_function(&mut self, name: &str) -> SemanticResult<()> {
        if let Some(scope) = self.scopes.last_mut() {
            scope.define(
                name.to_string(),
                Symbol::Function {
                    name: name.to_string(),
                },
            )
        } else {
            Err(SemanticError::ValidationError(
                "No active scope".to_string(),
            ))
        }
    }

    /// Define an event (global)
    pub fn define_event(&mut self, name: &str) -> SemanticResult<()> {
        if self.events.contains_key(name) {
            return Err(SemanticError::DuplicateDefinition(name.to_string()));
        }
        self.events.insert(
            name.to_string(),
            Symbol::Event {
                name: name.to_string(),
            },
        );
        Ok(())
    }

    /// Define a contract (global)
    pub fn define_contract(&mut self, name: &str) -> SemanticResult<()> {
        if self.contracts.contains_key(name) {
            return Err(SemanticError::DuplicateDefinition(name.to_string()));
        }
        self.contracts.insert(
            name.to_string(),
            Symbol::Contract {
                name: name.to_string(),
            },
        );
        Ok(())
    }

    /// Look up a variable in the scope chain
    pub fn lookup_variable(&self, name: &str) -> Option<&Type> {
        // Search from innermost to outermost scope
        for scope in self.scopes.iter().rev() {
            if let Some(Symbol::Variable { ty }) = scope.lookup(name) {
                return Some(ty);
            }
        }
        None
    }

    /// Check if an event is defined
    pub fn is_event_defined(&self, name: &str) -> bool {
        self.events.contains_key(name)
    }

    /// Check if a contract is defined
    pub fn is_contract_defined(&self, name: &str) -> bool {
        self.contracts.contains_key(name)
    }
}

impl Default for SymbolTable {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_symbol_table() {
        let mut table = SymbolTable::new();

        // Define a variable
        let uint_type = Type::Simple("uint256".to_string());
        table.define_variable("balance", &uint_type).unwrap();

        // Lookup the variable
        assert!(table.lookup_variable("balance").is_some());
        assert!(table.lookup_variable("unknown").is_none());

        // Test scoping
        table.enter_scope();
        let addr_type = Type::Simple("address".to_string());
        table.define_variable("owner", &addr_type).unwrap();
        assert!(table.lookup_variable("owner").is_some());
        assert!(table.lookup_variable("balance").is_some()); // From outer scope

        table.exit_scope();
        assert!(table.lookup_variable("owner").is_none()); // No longer in scope
        assert!(table.lookup_variable("balance").is_some()); // Still in scope
    }

    #[test]
    fn test_duplicate_definition() {
        let mut table = SymbolTable::new();
        let uint_type = Type::Simple("uint256".to_string());

        table.define_variable("balance", &uint_type).unwrap();
        let result = table.define_variable("balance", &uint_type);

        assert!(result.is_err());
        assert!(matches!(result, Err(SemanticError::DuplicateDefinition(_))));
    }
}
