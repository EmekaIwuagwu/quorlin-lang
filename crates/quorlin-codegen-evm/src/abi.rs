//! ABI generation for EVM contracts
//!
//! Generates Ethereum Contract ABI (Application Binary Interface) from Quorlin contracts.

use quorlin_parser::{ContractDecl, ContractMember, Function, Type, EventDecl};
use serde::{Deserialize, Serialize};
use serde_json;

/// ABI specification for a contract
#[derive(Debug, Serialize, Deserialize)]
pub struct ContractAbi {
    pub functions: Vec<AbiFunction>,
    pub events: Vec<AbiEvent>,
}

/// ABI specification for a function
#[derive(Debug, Serialize, Deserialize)]
pub struct AbiFunction {
    #[serde(rename = "type")]
    pub typ: String,
    pub name: String,
    pub inputs: Vec<AbiParam>,
    pub outputs: Vec<AbiParam>,
    #[serde(rename = "stateMutability")]
    pub state_mutability: String,
}

/// ABI specification for an event
#[derive(Debug, Serialize, Deserialize)]
pub struct AbiEvent {
    #[serde(rename = "type")]
    pub typ: String,
    pub name: String,
    pub inputs: Vec<AbiEventParam>,
    pub anonymous: bool,
}

/// ABI parameter
#[derive(Debug, Serialize, Deserialize)]
pub struct AbiParam {
    pub name: String,
    #[serde(rename = "type")]
    pub typ: String,
    #[serde(rename = "internalType")]
    pub internal_type: String,
}

/// ABI event parameter with indexed support
#[derive(Debug, Serialize, Deserialize)]
pub struct AbiEventParam {
    pub name: String,
    #[serde(rename = "type")]
    pub typ: String,
    pub indexed: bool,
    #[serde(rename = "internalType")]
    pub internal_type: String,
}

impl ContractAbi {
    /// Generate ABI from a contract declaration
    pub fn from_contract(contract: &ContractDecl, events: &[EventDecl]) -> Self {
        let mut functions = Vec::new();

        for member in &contract.body {
            if let ContractMember::Function(func) = member {
                // Skip constructor
                if func.name == "__init__" {
                    continue;
                }

                functions.push(AbiFunction::from_function(func));
            }
        }

        let abi_events = events.iter().map(AbiEvent::from_event).collect();

        ContractAbi {
            functions,
            events: abi_events,
        }
    }

    /// Convert ABI to JSON string
    pub fn to_json(&self) -> Result<String, serde_json::Error> {
        let mut items = Vec::new();

        // Add functions
        for func in &self.functions {
            items.push(serde_json::to_value(func)?);
        }

        // Add events
        for event in &self.events {
            items.push(serde_json::to_value(event)?);
        }

        serde_json::to_string_pretty(&items)
    }
}

impl AbiFunction {
    fn from_function(func: &Function) -> Self {
        let inputs = func.params.iter().map(|p| AbiParam {
            name: p.name.clone(),
            typ: type_to_abi_string(&p.type_annotation),
            internal_type: type_to_abi_string(&p.type_annotation),
        }).collect();

        let outputs = if let Some(ret_type) = &func.return_type {
            vec![AbiParam {
                name: String::new(),
                typ: type_to_abi_string(ret_type),
                internal_type: type_to_abi_string(ret_type),
            }]
        } else {
            Vec::new()
        };

        let state_mutability = if func.decorators.contains(&"view".to_string()) {
            "view"
        } else if func.decorators.contains(&"payable".to_string()) {
            "payable"
        } else {
            "nonpayable"
        }.to_string();

        AbiFunction {
            typ: "function".to_string(),
            name: func.name.clone(),
            inputs,
            outputs,
            state_mutability,
        }
    }
}

impl AbiEvent {
    fn from_event(event: &EventDecl) -> Self {
        let inputs = event.params.iter().map(|p| AbiEventParam {
            name: p.name.clone(),
            typ: type_to_abi_string(&p.type_annotation),
            indexed: p.indexed,
            internal_type: type_to_abi_string(&p.type_annotation),
        }).collect();

        AbiEvent {
            typ: "event".to_string(),
            name: event.name.clone(),
            inputs,
            anonymous: false,
        }
    }
}

/// Convert Quorlin type to ABI type string
fn type_to_abi_string(typ: &Type) -> String {
    match typ {
        Type::Simple(name) => match name.as_str() {
            "uint256" => "uint256".to_string(),
            "int256" => "int256".to_string(),
            "address" => "address".to_string(),
            "bool" => "bool".to_string(),
            "bytes32" => "bytes32".to_string(),
            "string" => "string".to_string(),
            _ => name.clone(),
        },
        Type::Mapping(key, val) => {
            // Mappings don't appear in ABI (they're internal state)
            format!("mapping({} => {})", type_to_abi_string(key), type_to_abi_string(val))
        }
        Type::List(inner) => format!("{}[]", type_to_abi_string(inner)),
        Type::FixedArray(inner, size) => format!("{}[{}]", type_to_abi_string(inner), size),
        Type::Optional(inner) => type_to_abi_string(inner),
        Type::Tuple(types) => {
            let type_strs: Vec<String> = types.iter().map(type_to_abi_string).collect();
            format!("({})", type_strs.join(","))
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_type_to_abi_string() {
        assert_eq!(type_to_abi_string(&Type::Simple("uint256".to_string())), "uint256");
        assert_eq!(type_to_abi_string(&Type::Simple("address".to_string())), "address");
        assert_eq!(type_to_abi_string(&Type::Simple("bool".to_string())), "bool");
    }
}
