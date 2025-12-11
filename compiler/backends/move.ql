# Aptos/Move Backend for Quorlin Compiler
# Generates Move smart contract code from QIR

from compiler.runtime.stdlib import Vec, HashMap, Option, Result
from compiler.runtime.stdlib import to_string, str_join
from compiler.middle.ir_builder import *

# ============================================================================
# Move Code Generator
# ============================================================================

contract MoveGenerator:
    """Generates Move code from QIR."""
    
    output: Vec[str]
    indent_level: uint256
    
    @constructor
    fn __init__():
        """Create new Move generator."""
        self.output = Vec[str]()
        self.indent_level = 0
    
    @external
    fn generate(qir: QIRModule) -> Result[str, str]:
        """Generate Move code from QIR module."""
        // Module declaration
        self.emit_line("module quorlin::contract {")
        self.indent()
        
        // Imports
        self.emit_line("use std::signer;")
        self.emit_line("use aptos_framework::event;")
        self.emit_line("")
        
        // Generate contracts
        for contract in qir.contracts:
            self.generate_contract(contract)?
        
        self.dedent()
        self.emit_line("}")
        
        // Join all lines
        let result = str_join(self.output, "\n")
        return Result.Ok(result)
    
    @internal
    fn generate_contract(contract: QIRContract) -> Result[(), str]:
        """Generate Move code for a contract."""
        // Resource structure
        self.emit_line(f"struct {contract.name} has key {{")
        self.indent()
        
        for state_var in contract.state_vars:
            let move_type = self.map_type_to_move(state_var.ty)
            self.emit_line(f"{state_var.name}: {move_type},")
        
        self.dedent()
        self.emit_line("}")
        self.emit_line("")
        
        // Events
        for event in contract.events:
            self.generate_event(event)?
        
        // Generate functions
        for func in contract.functions:
            self.generate_function(func, contract)?
            self.emit_line("")
        
        return Result.Ok(())
    
    @internal
    fn generate_event(event: EventDecl) -> Result[(), str]:
        """Generate Move event structure."""
        self.emit_line(f"struct {event.name}Event has drop, store {{")
        self.indent()
        
        for param in event.params:
            let move_type = self.map_type_to_move(param.ty)
            self.emit_line(f"{param.name}: {move_type},")
        
        self.dedent()
        self.emit_line("}")
        self.emit_line("")
        
        return Result.Ok(())
    
    @internal
    fn generate_function(func: QIRFunction, contract: QIRContract) -> Result[(), str]:
        """Generate Move function."""
        let is_constructor = self.is_constructor(func.name)
        let is_public = not is_constructor
        
        // Function visibility
        let visibility = if is_public: "public entry " else: "public "
        
        // Function signature
        let params = self.generate_params(func.params, is_constructor)
        let return_type = match func.return_type:
            Option.Some(ty):
                f": {self.map_type_to_move(ty)}"
            Option.None:
                ""
        
        if is_constructor:
            self.emit_line(f"{visibility}fun initialize(account: &signer{params}) {{")
        else:
            self.emit_line(f"{visibility}fun {func.name}(account: &signer{params}){return_type} {{")
        
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
        self.emit_line("let addr = signer::address_of(account);")
        self.emit_line("")
        
        self.emit_line(f"move_to(account, {contract.name} {{")
        self.indent()
        
        for state_var in contract.state_vars:
            if state_var.initial_value.is_some():
                self.emit_line(f"{state_var.name}: /* initial value */,")
            else:
                let default_val = self.get_default_value(state_var.ty)
                self.emit_line(f"{state_var.name}: {default_val},")
        
        self.dedent()
        self.emit_line("});")
        
        return Result.Ok(())
    
    @internal
    fn generate_function_body(func: QIRFunction, contract: QIRContract) -> Result[(), str]:
        """Generate function body."""
        self.emit_line("let addr = signer::address_of(account);")
        self.emit_line(f"let state = borrow_global_mut<{contract.name}>(addr);")
        self.emit_line("")
        
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
        """Generate Move code for an instruction."""
        match instr:
            QIRInstruction.StorageLoad(dest, slot):
                let var_name = self.get_var_name(slot, contract)
                self.emit_line(f"let r{dest} = state.{var_name};")
            
            QIRInstruction.StorageStore(slot, value):
                let var_name = self.get_var_name(slot, contract)
                let value_code = self.generate_value(value)
                self.emit_line(f"state.{var_name} = {value_code};")
            
            QIRInstruction.Add(dest, left, right, checked):
                let left_code = self.generate_value(left)
                let right_code = self.generate_value(right)
                self.emit_line(f"let r{dest} = {left_code} + {right_code};")
            
            QIRInstruction.Sub(dest, left, right, checked):
                let left_code = self.generate_value(left)
                let right_code = self.generate_value(right)
                self.emit_line(f"let r{dest} = {left_code} - {right_code};")
            
            QIRInstruction.Mul(dest, left, right, checked):
                let left_code = self.generate_value(left)
                let right_code = self.generate_value(right)
                self.emit_line(f"let r{dest} = {left_code} * {right_code};")
            
            QIRInstruction.Div(dest, left, right, checked):
                let left_code = self.generate_value(left)
                let right_code = self.generate_value(right)
                self.emit_line(f"let r{dest} = {left_code} / {right_code};")
            
            QIRInstruction.Eq(dest, left, right):
                let left_code = self.generate_value(left)
                let right_code = self.generate_value(right)
                self.emit_line(f"let r{dest} = {left_code} == {right_code};")
            
            QIRInstruction.Lt(dest, left, right):
                let left_code = self.generate_value(left)
                let right_code = self.generate_value(right)
                self.emit_line(f"let r{dest} = {left_code} < {right_code};")
            
            QIRInstruction.EmitEvent(event_id, args):
                self.emit_line(f"event::emit(EventName {{ /* fields */ }});")
            
            _:
                pass
        
        return Result.Ok(())
    
    @internal
    fn generate_value(value: QIRValue) -> str:
        """Generate Move code for a value."""
        match value:
            QIRValue.Register(id, _):
                return f"r{id}"
            
            QIRValue.Constant(val):
                return to_string(val)
            
            QIRValue.GlobalVar(name):
                return f"state.{name}"
            
            QIRValue.LocalVar(name):
                return name
    
    @internal
    fn generate_params(params: Vec[Parameter], is_constructor: bool) -> str:
        """Generate function parameters."""
        if params.len() == 0:
            return ""
        
        let mut param_strs = Vec[str]()
        for param in params:
            let move_type = self.map_type_to_move(param.ty)
            param_strs.push(f", {param.name}: {move_type}")
        
        return str_join(param_strs, "")
    
    @internal
    fn map_type_to_move(ty: Type) -> str:
        """Map Quorlin type to Move type."""
        match ty:
            Type.Int(256, false):
                return "u64"  // Move uses u64/u128
            Type.Int(128, false):
                return "u128"
            Type.Int(64, false):
                return "u64"
            Type.Int(8, false):
                return "u8"
            Type.Bool:
                return "bool"
            Type.String:
                return "vector<u8>"  // Move strings are byte vectors
            Type.Address:
                return "address"
            Type.Array(element_ty, _):
                let element_move = self.map_type_to_move(*element_ty)
                return f"vector<{element_move}>"
            _:
                return "u64"
    
    @internal
    fn get_default_value(ty: Type) -> str:
        """Get default value for a type."""
        match ty:
            Type.Int(_, _):
                return "0"
            Type.Bool:
                return "false"
            Type.String:
                return "vector::empty()"
            Type.Address:
                return "@0x0"
            _:
                return "0"
    
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
        return func_name == "__init__" or func_name == "initialize"
    
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

fn generate_move(qir: QIRModule) -> Result[str, str]:
    """Convenience function to generate Move code."""
    let generator = MoveGenerator()
    return generator.generate(qir)
