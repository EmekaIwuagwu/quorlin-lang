# Polkadot/ink! Backend for Quorlin Compiler
# Generates ink! smart contract code from QIR

from compiler.runtime.stdlib import Vec, HashMap, Option, Result
from compiler.runtime.stdlib import to_string, str_join
from compiler.middle.ir_builder import *

# ============================================================================
# ink! Code Generator
# ============================================================================

contract InkGenerator:
    """Generates ink! Rust code from QIR."""
    
    output: Vec[str]
    indent_level: uint256
    
    @constructor
    fn __init__():
        """Create new ink! generator."""
        self.output = Vec[str]()
        self.indent_level = 0
    
    @external
    fn generate(qir: QIRModule) -> Result[str, str]:
        """Generate ink! code from QIR module."""
        // Emit ink! attribute
        self.emit_line("#![cfg_attr(not(feature = \"std\"), no_std)]")
        self.emit_line("")
        
        // Generate contracts
        for contract in qir.contracts:
            self.generate_contract(contract)?
        
        // Join all lines
        let result = str_join(self.output, "\n")
        return Result.Ok(result)
    
    @internal
    fn generate_contract(contract: QIRContract) -> Result[(), str]:
        """Generate ink! code for a contract."""
        // Contract module
        self.emit_line("#[ink::contract]")
        self.emit_line(f"mod {contract.name.to_lowercase()} {{")
        self.indent()
        
        // Storage structure
        self.emit_line("#[ink(storage)]")
        self.emit_line(f"pub struct {contract.name} {{")
        self.indent()
        
        for state_var in contract.state_vars:
            let ink_type = self.map_type_to_ink(state_var.ty)
            self.emit_line(f"{state_var.name}: {ink_type},")
        
        self.dedent()
        self.emit_line("}")
        self.emit_line("")
        
        // Events
        for event in contract.events:
            self.generate_event(event)?
        
        // Implementation block
        self.emit_line(f"impl {contract.name} {{")
        self.indent()
        
        // Generate functions
        for func in contract.functions:
            self.generate_function(func, contract)?
            self.emit_line("")
        
        self.dedent()
        self.emit_line("}")
        
        self.dedent()
        self.emit_line("}")
        
        return Result.Ok(())
    
    @internal
    fn generate_event(event: EventDecl) -> Result[(), str]:
        """Generate ink! event."""
        self.emit_line("#[ink(event)]")
        self.emit_line(f"pub struct {event.name} {{")
        self.indent()
        
        for param in event.params:
            let ink_type = self.map_type_to_ink(param.ty)
            
            if param.indexed:
                self.emit_line("#[ink(topic)]")
            
            self.emit_line(f"pub {param.name}: {ink_type},")
        
        self.dedent()
        self.emit_line("}")
        self.emit_line("")
        
        return Result.Ok(())
    
    @internal
    fn generate_function(func: QIRFunction, contract: QIRContract) -> Result[(), str]:
        """Generate ink! function."""
        // Determine function attributes
        let is_constructor = self.is_constructor(func.name)
        let is_view = self.is_view_function(func)
        
        if is_constructor:
            self.emit_line("#[ink(constructor)]")
        else:
            if is_view:
                self.emit_line("#[ink(message)]")
            else:
                self.emit_line("#[ink(message)]")
        
        // Function signature
        let params = self.generate_params(func.params)
        let return_type = match func.return_type:
            Option.Some(ty):
                f" -> {self.map_type_to_ink(ty)}"
            Option.None:
                ""
        
        if is_constructor:
            self.emit_line(f"pub fn new({params}) -> Self {{")
        else:
            if is_view:
                self.emit_line(f"pub fn {func.name}(&self{params}){return_type} {{")
            else:
                self.emit_line(f"pub fn {func.name}(&mut self{params}){return_type} {{")
        
        self.indent()
        
        // Generate function body
        if is_constructor:
            self.generate_constructor_body(func, contract)?
        else:
            self.generate_function_body(func, contract)?
        
        self.dedent()
        self.emit_line("}")
        
        return Result.Ok(())
    
    @internal
    fn generate_constructor_body(func: QIRFunction, contract: QIRContract) -> Result[(), str]:
        """Generate constructor body."""
        self.emit_line("Self {")
        self.indent()
        
        for state_var in contract.state_vars:
            if state_var.initial_value.is_some():
                self.emit_line(f"{state_var.name}: /* initial value */,")
            else:
                self.emit_line(f"{state_var.name}: Default::default(),")
        
        self.dedent()
        self.emit_line("}")
        
        return Result.Ok(())
    
    @internal
    fn generate_function_body(func: QIRFunction, contract: QIRContract) -> Result[(), str]:
        """Generate function body."""
        // Generate instructions from IR
        for instr in func.entry_block.instructions:
            self.generate_instruction(instr, contract)?
        
        // Handle terminator
        match func.entry_block.terminator:
            QIRTerminator.Return(value):
                match value:
                    Option.Some(val):
                        let value_code = self.generate_value(val)
                        self.emit_line(f"{value_code}")
                    Option.None:
                        pass
            _:
                pass
        
        return Result.Ok(())
    
    @internal
    fn generate_instruction(instr: QIRInstruction, contract: QIRContract) -> Result[(), str]:
        """Generate Rust code for an instruction."""
        match instr:
            QIRInstruction.StorageLoad(dest, slot):
                let var_name = self.get_var_name(slot, contract)
                self.emit_line(f"let r{dest} = self.{var_name};")
            
            QIRInstruction.StorageStore(slot, value):
                let var_name = self.get_var_name(slot, contract)
                let value_code = self.generate_value(value)
                self.emit_line(f"self.{var_name} = {value_code};")
            
            QIRInstruction.Add(dest, left, right, checked):
                let left_code = self.generate_value(left)
                let right_code = self.generate_value(right)
                
                if checked:
                    self.emit_line(f"let r{dest} = {left_code}.checked_add({right_code})")
                    self.emit_line(f"    .expect(\"Overflow\");")
                else:
                    self.emit_line(f"let r{dest} = {left_code} + {right_code};")
            
            QIRInstruction.Sub(dest, left, right, checked):
                let left_code = self.generate_value(left)
                let right_code = self.generate_value(right)
                
                if checked:
                    self.emit_line(f"let r{dest} = {left_code}.checked_sub({right_code})")
                    self.emit_line(f"    .expect(\"Underflow\");")
                else:
                    self.emit_line(f"let r{dest} = {left_code} - {right_code};")
            
            QIRInstruction.Mul(dest, left, right, checked):
                let left_code = self.generate_value(left)
                let right_code = self.generate_value(right)
                
                if checked:
                    self.emit_line(f"let r{dest} = {left_code}.checked_mul({right_code})")
                    self.emit_line(f"    .expect(\"Overflow\");")
                else:
                    self.emit_line(f"let r{dest} = {left_code} * {right_code};")
            
            QIRInstruction.Eq(dest, left, right):
                let left_code = self.generate_value(left)
                let right_code = self.generate_value(right)
                self.emit_line(f"let r{dest} = {left_code} == {right_code};")
            
            QIRInstruction.Lt(dest, left, right):
                let left_code = self.generate_value(left)
                let right_code = self.generate_value(right)
                self.emit_line(f"let r{dest} = {left_code} < {right_code};")
            
            QIRInstruction.EmitEvent(event_id, args):
                self.emit_line(f"self.env().emit_event(EventName {{ /* fields */ }});")
            
            _:
                pass
        
        return Result.Ok(())
    
    @internal
    fn generate_value(value: QIRValue) -> str:
        """Generate Rust code for a value."""
        match value:
            QIRValue.Register(id, _):
                return f"r{id}"
            
            QIRValue.Constant(val):
                return to_string(val)
            
            QIRValue.GlobalVar(name):
                return f"self.{name}"
            
            QIRValue.LocalVar(name):
                return name
    
    @internal
    fn generate_params(params: Vec[Parameter]) -> str:
        """Generate function parameters."""
        if params.len() == 0:
            return ""
        
        let mut param_strs = Vec[str]()
        for param in params:
            let ink_type = self.map_type_to_ink(param.ty)
            param_strs.push(f", {param.name}: {ink_type}")
        
        return str_join(param_strs, "")
    
    @internal
    fn map_type_to_ink(ty: Type) -> str:
        """Map Quorlin type to ink! type."""
        match ty:
            Type.Int(256, false):
                return "u128"  // ink! commonly uses u128
            Type.Int(256, true):
                return "i128"
            Type.Int(64, false):
                return "u64"
            Type.Int(32, false):
                return "u32"
            Type.Bool:
                return "bool"
            Type.String:
                return "String"
            Type.Address:
                return "AccountId"
            Type.Mapping(key_ty, value_ty):
                let key_ink = self.map_type_to_ink(*key_ty)
                let value_ink = self.map_type_to_ink(*value_ty)
                return f"ink::storage::Mapping<{key_ink}, {value_ink}>"
            _:
                return "u128"
    
    @internal
    fn get_var_name(slot: uint256, contract: QIRContract) -> str:
        """Get variable name from storage slot."""
        for (name, s) in contract.storage_layout:
            if s == slot:
                return name
        return f"var_{slot}"
    
    @internal
    fn is_constructor(func_name: str) -> bool:
        """Check if function is a constructor."""
        return func_name == "__init__" or func_name == "new"
    
    @internal
    fn is_view_function(func: QIRFunction) -> bool:
        """Check if function is view-only."""
        // Check if function modifies storage
        for instr in func.entry_block.instructions:
            match instr:
                QIRInstruction.StorageStore(_, _):
                    return false
                _:
                    pass
        return true
    
    @internal
    fn emit_line(line: str):
        """Emit a line of code with proper indentation."""
        let indent = str_repeat("    ", self.indent_level)
        self.output.push(indent + line)
    
    @internal
    fn indent():
        """Increase indentation level."""
        self.indent_level = self.indent_level + 1
    
    @internal
    fn dedent():
        """Decrease indentation level."""
        if self.indent_level > 0:
            self.indent_level = self.indent_level - 1

# ============================================================================
# Helper Functions
# ============================================================================

fn generate_ink(qir: QIRModule) -> Result[str, str]:
    """Convenience function to generate ink! code."""
    let generator = InkGenerator()
    return generator.generate(qir)
