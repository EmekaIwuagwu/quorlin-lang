# Solana/Anchor Backend for Quorlin Compiler
# Generates Anchor-compatible Rust code from QIR

from compiler.runtime.stdlib import Vec, HashMap, Option, Result
from compiler.runtime.stdlib import to_string, str_join
from compiler.middle.ir_builder import *

# ============================================================================
# Solana/Anchor Code Generator
# ============================================================================

contract SolanaGenerator:
    """Generates Anchor Rust code from QIR."""
    
    output: Vec[str]
    indent_level: uint256
    
    @constructor
    fn __init__():
        """Create new Solana generator."""
        self.output = Vec[str]()
        self.indent_level = 0
    
    @external
    fn generate(qir: QIRModule) -> Result[str, str]:
        """Generate Anchor Rust code from QIR module."""
        // Emit imports
        self.emit_line("use anchor_lang::prelude::*;")
        self.emit_line("")
        
        self.emit_line("declare_id!(\"Fg6PaFpoGXkYsidMpWTK6W2BeZ7FEfcYkg476zPFsLnS\");")
        self.emit_line("")
        
        // Generate contracts
        for contract in qir.contracts:
            self.generate_contract(contract)?
        
        // Join all lines
        let result = str_join(self.output, "\n")
        return Result.Ok(result)
    
    @internal
    fn generate_contract(contract: QIRContract) -> Result[(), str]:
        """Generate Anchor code for a contract."""
        // Program module
        self.emit_line("#[program]")
        self.emit_line(f"pub mod {contract.name.to_lowercase()} {{")
        self.indent()
        
        self.emit_line("use super::*;")
        self.emit_line("")
        
        // Generate functions
        for func in contract.functions:
            self.generate_function(func, contract)?
            self.emit_line("")
        
        self.dedent()
        self.emit_line("}")
        self.emit_line("")
        
        // Generate account structures
        self.generate_accounts(contract)?
        
        return Result.Ok(())
    
    @internal
    fn generate_function(func: QIRFunction, contract: QIRContract) -> Result[(), str]:
        """Generate Anchor function."""
        // Determine function visibility
        let visibility = if self.is_constructor(func.name):
            "initialize"
        else:
            func.name
        
        self.emit_line(f"pub fn {visibility}(ctx: Context<{self.get_context_name(func.name)}>) -> Result<()> {{")
        self.indent()
        
        // Generate function body
        self.emit_line("let account = &mut ctx.accounts.account;")
        self.emit_line("")
        
        // Generate instructions from IR
        for instr in func.entry_block.instructions:
            self.generate_instruction(instr, contract)?
        
        self.emit_line("")
        self.emit_line("Ok(())")
        
        self.dedent()
        self.emit_line("}")
        
        return Result.Ok(())
    
    @internal
    fn generate_instruction(instr: QIRInstruction, contract: QIRContract) -> Result[(), str]:
        """Generate Rust code for an instruction."""
        match instr:
            QIRInstruction.StorageLoad(dest, slot):
                let var_name = self.get_var_name(slot, contract)
                self.emit_line(f"let r{dest} = account.{var_name};")
            
            QIRInstruction.StorageStore(slot, value):
                let var_name = self.get_var_name(slot, contract)
                let value_code = self.generate_value(value)
                self.emit_line(f"account.{var_name} = {value_code};")
            
            QIRInstruction.Add(dest, left, right, checked):
                let left_code = self.generate_value(left)
                let right_code = self.generate_value(right)
                
                if checked:
                    self.emit_line(f"let r{dest} = {left_code}.checked_add({right_code})")
                    self.emit_line(f"    .ok_or(ErrorCode::Overflow)?;")
                else:
                    self.emit_line(f"let r{dest} = {left_code} + {right_code};")
            
            QIRInstruction.Sub(dest, left, right, checked):
                let left_code = self.generate_value(left)
                let right_code = self.generate_value(right)
                
                if checked:
                    self.emit_line(f"let r{dest} = {left_code}.checked_sub({right_code})")
                    self.emit_line(f"    .ok_or(ErrorCode::Underflow)?;")
                else:
                    self.emit_line(f"let r{dest} = {left_code} - {right_code};")
            
            QIRInstruction.Mul(dest, left, right, checked):
                let left_code = self.generate_value(left)
                let right_code = self.generate_value(right)
                
                if checked:
                    self.emit_line(f"let r{dest} = {left_code}.checked_mul({right_code})")
                    self.emit_line(f"    .ok_or(ErrorCode::Overflow)?;")
                else:
                    self.emit_line(f"let r{dest} = {left_code} * {right_code};")
            
            QIRInstruction.EmitEvent(event_id, args):
                self.emit_line(f"// Emit event {event_id}")
                self.emit_line(f"emit!(EventName {{ /* fields */ }});")
            
            _:
                pass
        
        return Result.Ok(())
    
    @internal
    fn generate_accounts(contract: QIRContract) -> Result[(), str]:
        """Generate account structures."""
        // Main account structure
        self.emit_line("#[account]")
        self.emit_line(f"pub struct {contract.name}Account {{")
        self.indent()
        
        for state_var in contract.state_vars:
            let rust_type = self.map_type_to_rust(state_var.ty)
            self.emit_line(f"pub {state_var.name}: {rust_type},")
        
        self.dedent()
        self.emit_line("}")
        self.emit_line("")
        
        // Context structures for each function
        for func in contract.functions:
            self.generate_context(func, contract)?
        
        // Error codes
        self.emit_line("#[error_code]")
        self.emit_line("pub enum ErrorCode {")
        self.indent()
        self.emit_line("#[msg(\"Arithmetic overflow\")]")
        self.emit_line("Overflow,")
        self.emit_line("#[msg(\"Arithmetic underflow\")]")
        self.emit_line("Underflow,")
        self.dedent()
        self.emit_line("}")
        
        return Result.Ok(())
    
    @internal
    fn generate_context(func: QIRFunction, contract: QIRContract) -> Result[(), str]:
        """Generate context structure for function."""
        let context_name = self.get_context_name(func.name)
        
        self.emit_line("#[derive(Accounts)]")
        self.emit_line(f"pub struct {context_name}<'info> {{")
        self.indent()
        
        if self.is_constructor(func.name):
            self.emit_line("#[account(init, payer = user, space = 8 + 1024)]")
            self.emit_line(f"pub account: Account<'info, {contract.name}Account>,")
            self.emit_line("#[account(mut)]")
            self.emit_line("pub user: Signer<'info>,")
            self.emit_line("pub system_program: Program<'info, System>,")
        else:
            self.emit_line("#[account(mut)]")
            self.emit_line(f"pub account: Account<'info, {contract.name}Account>,")
        
        self.dedent()
        self.emit_line("}")
        self.emit_line("")
        
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
                return f"account.{name}"
            
            QIRValue.LocalVar(name):
                return name
    
    @internal
    fn map_type_to_rust(ty: Type) -> str:
        """Map Quorlin type to Rust type."""
        match ty:
            Type.Int(256, false):
                return "u64"  // Solana uses u64 for most integers
            Type.Int(256, true):
                return "i64"
            Type.Bool:
                return "bool"
            Type.String:
                return "String"
            Type.Address:
                return "Pubkey"
            _:
                return "u64"
    
    @internal
    fn get_var_name(slot: uint256, contract: QIRContract) -> str:
        """Get variable name from storage slot."""
        for (name, s) in contract.storage_layout:
            if s == slot:
                return name
        return f"var_{slot}"
    
    @internal
    fn get_context_name(func_name: str) -> str:
        """Get context struct name for function."""
        return f"{func_name.capitalize()}Context"
    
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

fn generate_solana(qir: QIRModule) -> Result[str, str]:
    """Convenience function to generate Solana code."""
    let generator = SolanaGenerator()
    return generator.generate(qir)
