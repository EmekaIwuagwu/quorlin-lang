# EVM/Yul Backend for Quorlin Compiler
# Generates Yul intermediate representation from QIR

from compiler.runtime.stdlib import Vec, HashMap, Option, Result
from compiler.runtime.stdlib import to_string, str_join
from compiler.middle.ir_builder import *

# ============================================================================
# Yul Code Generator
# ============================================================================

contract YulGenerator:
    """Generates Yul code from QIR."""
    
    output: Vec[str]
    indent_level: uint256
    storage_layout: HashMap[str, uint256]
    
    @constructor
    fn __init__():
        """Create new Yul generator."""
        self.output = Vec[str]()
        self.indent_level = 0
        self.storage_layout = HashMap[str, uint256]()
    
    @external
    fn generate(qir: QIRModule) -> Result[str, str]:
        """Generate Yul code from QIR module."""
        self.emit_line("object \"QuorlinContract\" {")
        self.indent()
        
        self.emit_line("code {")
        self.indent()
        
        // Generate constructor
        self.emit_line("// Constructor")
        self.emit_line("datacopy(0, dataoffset(\"runtime\"), datasize(\"runtime\"))")
        self.emit_line("return(0, datasize(\"runtime\"))")
        
        self.dedent()
        self.emit_line("}")
        
        // Generate runtime code
        self.emit_line("")
        self.emit_line("object \"runtime\" {")
        self.indent()
        
        self.emit_line("code {")
        self.indent()
        
        // Generate contracts
        for contract in qir.contracts:
            self.generate_contract(contract)?
        
        self.dedent()
        self.emit_line("}")
        
        self.dedent()
        self.emit_line("}")
        
        self.dedent()
        self.emit_line("}")
        
        // Join all lines
        let result = str_join(self.output, "\n")
        return Result.Ok(result)
    
    @internal
    fn generate_contract(contract: QIRContract) -> Result[(), str]:
        """Generate Yul code for a contract."""
        self.storage_layout = contract.storage_layout
        
        // Generate dispatcher
        self.emit_line("// Function dispatcher")
        self.emit_line("switch selector()")
        
        for func in contract.functions:
            // Generate function selector
            let selector = self.function_selector(func.name)
            self.emit_line(f"case {selector} {{")
            self.indent()
            
            // Call function
            self.emit_line(f"{func.name}()")
            
            self.dedent()
            self.emit_line("}")
        
        self.emit_line("default {")
        self.indent()
        self.emit_line("revert(0, 0)")
        self.dedent()
        self.emit_line("}")
        
        self.emit_line("")
        
        // Generate functions
        for func in contract.functions:
            self.generate_function(func)?
            self.emit_line("")
        
        // Generate helper functions
        self.generate_helpers()
        
        return Result.Ok(())
    
    @internal
    fn generate_function(func: QIRFunction) -> Result[(), str]:
        """Generate Yul code for a function."""
        self.emit_line(f"function {func.name}() {{")
        self.indent()
        
        // Declare local variables (registers)
        for i in range(func.next_register):
            self.emit_line(f"let r{i} := 0")
        
        // Generate entry block
        self.generate_block(func.entry_block)?
        
        // Generate other blocks
        for (label, block) in func.blocks:
            if label != "entry":
                self.emit_line(f"{label}:")
                self.generate_block(block)?
        
        self.dedent()
        self.emit_line("}")
        
        return Result.Ok(())
    
    @internal
    fn generate_block(block: QIRBasicBlock) -> Result[(), str]:
        """Generate Yul code for a basic block."""
        // Generate instructions
        for instr in block.instructions:
            self.generate_instruction(instr)?
        
        // Generate terminator
        self.generate_terminator(block.terminator)?
        
        return Result.Ok(())
    
    @internal
    fn generate_instruction(instr: QIRInstruction) -> Result[(), str]:
        """Generate Yul code for an instruction."""
        match instr:
            QIRInstruction.Assign(dest, value):
                let value_code = self.generate_value(value)
                self.emit_line(f"r{dest} := {value_code}")
            
            QIRInstruction.Add(dest, left, right, checked):
                let left_code = self.generate_value(left)
                let right_code = self.generate_value(right)
                
                if checked:
                    self.emit_line(f"r{dest} := checked_add({left_code}, {right_code})")
                else:
                    self.emit_line(f"r{dest} := add({left_code}, {right_code})")
            
            QIRInstruction.Sub(dest, left, right, checked):
                let left_code = self.generate_value(left)
                let right_code = self.generate_value(right)
                
                if checked:
                    self.emit_line(f"r{dest} := checked_sub({left_code}, {right_code})")
                else:
                    self.emit_line(f"r{dest} := sub({left_code}, {right_code})")
            
            QIRInstruction.Mul(dest, left, right, checked):
                let left_code = self.generate_value(left)
                let right_code = self.generate_value(right)
                
                if checked:
                    self.emit_line(f"r{dest} := checked_mul({left_code}, {right_code})")
                else:
                    self.emit_line(f"r{dest} := mul({left_code}, {right_code})")
            
            QIRInstruction.Div(dest, left, right, checked):
                let left_code = self.generate_value(left)
                let right_code = self.generate_value(right)
                self.emit_line(f"r{dest} := div({left_code}, {right_code})")
            
            QIRInstruction.Eq(dest, left, right):
                let left_code = self.generate_value(left)
                let right_code = self.generate_value(right)
                self.emit_line(f"r{dest} := eq({left_code}, {right_code})")
            
            QIRInstruction.Lt(dest, left, right):
                let left_code = self.generate_value(left)
                let right_code = self.generate_value(right)
                self.emit_line(f"r{dest} := lt({left_code}, {right_code})")
            
            QIRInstruction.StorageLoad(dest, slot):
                self.emit_line(f"r{dest} := sload({slot})")
            
            QIRInstruction.StorageStore(slot, value):
                let value_code = self.generate_value(value)
                self.emit_line(f"sstore({slot}, {value_code})")
            
            QIRInstruction.Call(dest, function, args):
                let mut arg_codes = Vec[str]()
                for arg in args:
                    arg_codes.push(self.generate_value(arg))
                
                let args_str = str_join(arg_codes, ", ")
                
                match dest:
                    Option.Some(reg):
                        self.emit_line(f"r{reg} := {function}({args_str})")
                    Option.None:
                        self.emit_line(f"{function}({args_str})")
            
            _:
                pass
        
        return Result.Ok(())
    
    @internal
    fn generate_terminator(term: QIRTerminator) -> Result[(), str]:
        """Generate Yul code for a terminator."""
        match term:
            QIRTerminator.Return(value):
                match value:
                    Option.Some(val):
                        let value_code = self.generate_value(val)
                        self.emit_line(f"mstore(0, {value_code})")
                        self.emit_line("return(0, 32)")
                    Option.None:
                        self.emit_line("return(0, 0)")
            
            QIRTerminator.Jump(target):
                self.emit_line(f"jump({target})")
            
            QIRTerminator.Branch(condition, true_target, false_target):
                let cond_code = self.generate_value(condition)
                self.emit_line(f"switch {cond_code}")
                self.emit_line(f"case 1 {{ jump({true_target}) }}")
                self.emit_line(f"default {{ jump({false_target}) }}")
            
            _:
                pass
        
        return Result.Ok(())
    
    @internal
    fn generate_value(value: QIRValue) -> str:
        """Generate Yul code for a value."""
        match value:
            QIRValue.Register(id, _):
                return f"r{id}"
            
            QIRValue.Constant(val):
                return to_string(val)
            
            QIRValue.GlobalVar(name):
                let slot = self.storage_layout.get(name).unwrap_or(0)
                return f"sload({slot})"
            
            QIRValue.LocalVar(name):
                return name
    
    @internal
    fn generate_helpers():
        """Generate helper functions."""
        self.emit_line("// Helper functions")
        self.emit_line("")
        
        // Function selector
        self.emit_line("function selector() -> s {")
        self.indent()
        self.emit_line("s := div(calldataload(0), 0x100000000000000000000000000000000000000000000000000000000)")
        self.dedent()
        self.emit_line("}")
        self.emit_line("")
        
        // Checked arithmetic
        self.emit_line("function checked_add(a, b) -> result {")
        self.indent()
        self.emit_line("result := add(a, b)")
        self.emit_line("if lt(result, a) { revert(0, 0) }")
        self.dedent()
        self.emit_line("}")
        self.emit_line("")
        
        self.emit_line("function checked_sub(a, b) -> result {")
        self.indent()
        self.emit_line("if lt(a, b) { revert(0, 0) }")
        self.emit_line("result := sub(a, b)")
        self.dedent()
        self.emit_line("}")
        self.emit_line("")
        
        self.emit_line("function checked_mul(a, b) -> result {")
        self.indent()
        self.emit_line("result := mul(a, b)")
        self.emit_line("if iszero(eq(div(result, a), b)) { revert(0, 0) }")
        self.dedent()
        self.emit_line("}")
    
    @internal
    fn function_selector(name: str) -> str:
        """Calculate function selector (simplified)."""
        // In real implementation, would use keccak256
        // For now, return placeholder
        return "0x12345678"
    
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

fn generate_yul(qir: QIRModule) -> Result[str, str]:
    """Convenience function to generate Yul code."""
    let generator = YulGenerator()
    return generator.generate(qir)
