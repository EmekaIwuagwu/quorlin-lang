# Quorlin Compiler Test Suite
# Comprehensive tests for all compiler components

from compiler.runtime.stdlib import Vec, HashMap, Option, Result
from compiler.frontend.lexer import Lexer, tokenize_source, LexerError
from compiler.frontend.parser import Parser, parse_source, ParseError
from compiler.frontend.ast import *
from compiler.middle.semantic import SemanticAnalyzer, analyze_module, SemanticError
from compiler.middle.ir_builder import IRBuilder, build_ir, IRError

# ============================================================================
# Test Framework
# ============================================================================

struct TestResult:
    """Result of a test."""
    name: str
    passed: bool
    message: str

contract TestSuite:
    """Test suite runner."""
    
    tests_run: uint256
    tests_passed: uint256
    tests_failed: uint256
    results: Vec[TestResult]
    
    @constructor
    fn __init__():
        """Create new test suite."""
        self.tests_run = 0
        self.tests_passed = 0
        self.tests_failed = 0
        self.results = Vec[TestResult]()
    
    @external
    fn run_test(name: str, test_fn: fn() -> Result[(), str]):
        """Run a single test."""
        self.tests_run = self.tests_run + 1
        
        let result = test_fn()
        match result:
            Result.Ok(_):
                self.tests_passed = self.tests_passed + 1
                self.results.push(TestResult(
                    name: name,
                    passed: true,
                    message: "PASS"
                ))
                println(f"✓ {name}")
            
            Result.Err(error):
                self.tests_failed = self.tests_failed + 1
                self.results.push(TestResult(
                    name: name,
                    passed: false,
                    message: error
                ))
                println(f"✗ {name}: {error}")
    
    @external
    fn print_summary():
        """Print test summary."""
        println("")
        println("═══════════════════════════════════════════")
        println(f"Test Results: {self.tests_passed}/{self.tests_run} passed")
        println("═══════════════════════════════════════════")
        
        if self.tests_failed > 0:
            println(f"Failed tests: {self.tests_failed}")
            for result in self.results:
                if not result.passed:
                    println(f"  ✗ {result.name}: {result.message}")
        else:
            println("All tests passed! 🎉")

# ============================================================================
# Lexer Tests
# ============================================================================

fn test_lexer_integers() -> Result[(), str]:
    """Test integer literal tokenization."""
    let source = "123 456 0x1a2b"
    let lexer = Lexer(source, "test.ql")
    let result = lexer.tokenize()
    
    match result:
        Result.Ok(tokens):
            if tokens.len() < 3:
                return Result.Err("Expected at least 3 tokens")
            
            // Check first token is integer
            let first = tokens.get(0).unwrap()
            match first.kind:
                TokenKind.IntLiteral(value):
                    if value != 123:
                        return Result.Err(f"Expected 123, got {value}")
                _:
                    return Result.Err("Expected IntLiteral")
            
            return Result.Ok(())
        
        Result.Err(error):
            return Result.Err(error.to_string())

fn test_lexer_strings() -> Result[(), str]:
    """Test string literal tokenization."""
    let source = '"hello" "world"'
    let lexer = Lexer(source, "test.ql")
    let result = lexer.tokenize()
    
    match result:
        Result.Ok(tokens):
            if tokens.len() < 2:
                return Result.Err("Expected at least 2 tokens")
            
            let first = tokens.get(0).unwrap()
            match first.kind:
                TokenKind.StringLiteral(value):
                    if value != "hello":
                        return Result.Err(f"Expected 'hello', got '{value}'")
                _:
                    return Result.Err("Expected StringLiteral")
            
            return Result.Ok(())
        
        Result.Err(error):
            return Result.Err(error.to_string())

fn test_lexer_keywords() -> Result[(), str]:
    """Test keyword tokenization."""
    let source = "fn contract if while for return"
    let lexer = Lexer(source, "test.ql")
    let result = lexer.tokenize()
    
    match result:
        Result.Ok(tokens):
            if tokens.len() < 6:
                return Result.Err("Expected at least 6 tokens")
            
            let first = tokens.get(0).unwrap()
            match first.kind:
                TokenKind.Keyword(kw):
                    if kw != "fn":
                        return Result.Err(f"Expected 'fn', got '{kw}'")
                _:
                    return Result.Err("Expected Keyword")
            
            return Result.Ok(())
        
        Result.Err(error):
            return Result.Err(error.to_string())

fn test_lexer_operators() -> Result[(), str]:
    """Test operator tokenization."""
    let source = "+ - * / == != <= >= and or"
    let lexer = Lexer(source, "test.ql")
    let result = lexer.tokenize()
    
    match result:
        Result.Ok(tokens):
            if tokens.len() < 10:
                return Result.Err("Expected at least 10 tokens")
            
            return Result.Ok(())
        
        Result.Err(error):
            return Result.Err(error.to_string())

fn test_lexer_indentation() -> Result[(), str]:
    """Test indentation handling."""
    let source = "fn test():\n    x = 1\n    y = 2"
    let lexer = Lexer(source, "test.ql")
    let result = lexer.tokenize()
    
    match result:
        Result.Ok(tokens):
            // Should have INDENT and DEDENT tokens
            let mut has_indent = false
            let mut has_dedent = false
            
            for token in tokens:
                match token.kind:
                    TokenKind.Indent(_):
                        has_indent = true
                    TokenKind.Dedent:
                        has_dedent = true
                    _:
                        pass
            
            if not has_indent:
                return Result.Err("Expected INDENT token")
            if not has_dedent:
                return Result.Err("Expected DEDENT token")
            
            return Result.Ok(())
        
        Result.Err(error):
            return Result.Err(error.to_string())

# ============================================================================
# Parser Tests
# ============================================================================

fn test_parser_simple_contract() -> Result[(), str]:
    """Test parsing a simple contract."""
    let source = """
contract Counter:
    count: uint256
    
    fn increment():
        self.count = self.count + 1
"""
    
    let tokens = tokenize_source(source, "test.ql")?
    let result = parse_source(tokens)
    
    match result:
        Result.Ok(module):
            if module.items.len() != 1:
                return Result.Err(f"Expected 1 item, got {module.items.len()}")
            
            match module.items.get(0).unwrap():
                Item.Contract(contract):
                    if contract.name != "Counter":
                        return Result.Err(f"Expected 'Counter', got '{contract.name}'")
                    
                    if contract.state_vars.len() != 1:
                        return Result.Err("Expected 1 state variable")
                    
                    if contract.functions.len() != 1:
                        return Result.Err("Expected 1 function")
                    
                    return Result.Ok(())
                
                _:
                    return Result.Err("Expected Contract item")
        
        Result.Err(error):
            return Result.Err(error.to_string())

fn test_parser_expressions() -> Result[(), str]:
    """Test parsing expressions."""
    let source = """
fn test():
    x = 1 + 2 * 3
    y = (a + b) / c
    z = x == y and y > 0
"""
    
    let tokens = tokenize_source(source, "test.ql")?
    let result = parse_source(tokens)
    
    match result:
        Result.Ok(module):
            // Should parse without errors
            return Result.Ok(())
        
        Result.Err(error):
            return Result.Err(error.to_string())

fn test_parser_control_flow() -> Result[(), str]:
    """Test parsing control flow statements."""
    let source = """
fn test():
    if x > 0:
        y = 1
    elif x < 0:
        y = -1
    else:
        y = 0
    
    while i < 10:
        i = i + 1
    
    for item in items:
        process(item)
"""
    
    let tokens = tokenize_source(source, "test.ql")?
    let result = parse_source(tokens)
    
    match result:
        Result.Ok(module):
            return Result.Ok(())
        
        Result.Err(error):
            return Result.Err(error.to_string())

# ============================================================================
# Semantic Analyzer Tests
# ============================================================================

fn test_semantic_type_checking() -> Result[(), str]:
    """Test type checking."""
    let source = """
fn test():
    let x: uint256 = 42
    let y: uint256 = x + 10
    let z: bool = x > y
"""
    
    let tokens = tokenize_source(source, "test.ql")?
    let module = parse_source(tokens)?
    let result = analyze_module(module)
    
    match result:
        Result.Ok(_):
            return Result.Ok(())
        
        Result.Err(errors):
            return Result.Err(f"Type checking failed: {errors.len()} errors")

fn test_semantic_undefined_variable() -> Result[(), str]:
    """Test undefined variable detection."""
    let source = """
fn test():
    x = undefined_var + 1
"""
    
    let tokens = tokenize_source(source, "test.ql")?
    let module = parse_source(tokens)?
    let result = analyze_module(module)
    
    match result:
        Result.Ok(_):
            return Result.Err("Expected error for undefined variable")
        
        Result.Err(errors):
            // Should have at least one error
            if errors.len() == 0:
                return Result.Err("Expected errors")
            return Result.Ok(())

fn test_semantic_type_mismatch() -> Result[(), str]:
    """Test type mismatch detection."""
    let source = """
fn test():
    let x: uint256 = "string"
"""
    
    let tokens = tokenize_source(source, "test.ql")?
    let module = parse_source(tokens)?
    let result = analyze_module(module)
    
    match result:
        Result.Ok(_):
            return Result.Err("Expected type mismatch error")
        
        Result.Err(errors):
            if errors.len() == 0:
                return Result.Err("Expected errors")
            return Result.Ok(())

# ============================================================================
# IR Builder Tests
# ============================================================================

fn test_ir_simple_function() -> Result[(), str]:
    """Test IR generation for simple function."""
    let source = """
fn add(a: uint256, b: uint256) -> uint256:
    return a + b
"""
    
    let tokens = tokenize_source(source, "test.ql")?
    let module = parse_source(tokens)?
    let typed_module = analyze_module(module)?
    let result = build_ir(typed_module)
    
    match result:
        Result.Ok(qir):
            if qir.functions.len() != 1:
                return Result.Err("Expected 1 function in IR")
            
            return Result.Ok(())
        
        Result.Err(error):
            return Result.Err(error.to_string())

fn test_ir_control_flow() -> Result[(), str]:
    """Test IR generation for control flow."""
    let source = """
fn test(x: uint256) -> uint256:
    if x > 10:
        return x * 2
    else:
        return x + 1
"""
    
    let tokens = tokenize_source(source, "test.ql")?
    let module = parse_source(tokens)?
    let typed_module = analyze_module(module)?
    let result = build_ir(typed_module)
    
    match result:
        Result.Ok(qir):
            // Should have multiple basic blocks
            return Result.Ok(())
        
        Result.Err(error):
            return Result.Err(error.to_string())

# ============================================================================
# Integration Tests
# ============================================================================

fn test_full_pipeline_counter() -> Result[(), str]:
    """Test full compilation pipeline with counter contract."""
    let source = """
contract Counter:
    count: uint256
    
    @constructor
    fn __init__():
        self.count = 0
    
    @external
    fn increment():
        self.count = self.count + 1
    
    @view
    fn get_count() -> uint256:
        return self.count
"""
    
    // Lex
    let tokens = tokenize_source(source, "counter.ql")?
    
    // Parse
    let module = parse_source(tokens)?
    
    // Semantic analysis
    let typed_module = analyze_module(module)?
    
    // IR generation
    let qir = build_ir(typed_module)?
    
    // Verify IR
    if qir.contracts.len() != 1:
        return Result.Err("Expected 1 contract in IR")
    
    let contract = qir.contracts.get(0).unwrap()
    if contract.functions.len() != 2:  // increment + get_count
        return Result.Err(f"Expected 2 functions, got {contract.functions.len()}")
    
    return Result.Ok(())

fn test_full_pipeline_token() -> Result[(), str]:
    """Test full compilation pipeline with token contract."""
    let source = """
from std.math import safe_add, safe_sub

contract Token:
    balances: mapping[address, uint256]
    total_supply: uint256
    
    @external
    fn transfer(to: address, amount: uint256) -> bool:
        self.balances[msg.sender] = safe_sub(self.balances[msg.sender], amount)
        self.balances[to] = safe_add(self.balances[to], amount)
        return true
"""
    
    // Full pipeline
    let tokens = tokenize_source(source, "token.ql")?
    let module = parse_source(tokens)?
    let typed_module = analyze_module(module)?
    let qir = build_ir(typed_module)?
    
    return Result.Ok(())

# ============================================================================
# Main Test Runner
# ============================================================================

fn run_all_tests():
    """Run all tests."""
    let suite = TestSuite()
    
    println("Running Quorlin Compiler Test Suite...")
    println("═══════════════════════════════════════════")
    println("")
    
    // Lexer tests
    println("Lexer Tests:")
    suite.run_test("Lexer: Integers", test_lexer_integers)
    suite.run_test("Lexer: Strings", test_lexer_strings)
    suite.run_test("Lexer: Keywords", test_lexer_keywords)
    suite.run_test("Lexer: Operators", test_lexer_operators)
    suite.run_test("Lexer: Indentation", test_lexer_indentation)
    println("")
    
    // Parser tests
    println("Parser Tests:")
    suite.run_test("Parser: Simple Contract", test_parser_simple_contract)
    suite.run_test("Parser: Expressions", test_parser_expressions)
    suite.run_test("Parser: Control Flow", test_parser_control_flow)
    println("")
    
    // Semantic analyzer tests
    println("Semantic Analyzer Tests:")
    suite.run_test("Semantic: Type Checking", test_semantic_type_checking)
    suite.run_test("Semantic: Undefined Variable", test_semantic_undefined_variable)
    suite.run_test("Semantic: Type Mismatch", test_semantic_type_mismatch)
    println("")
    
    // IR builder tests
    println("IR Builder Tests:")
    suite.run_test("IR: Simple Function", test_ir_simple_function)
    suite.run_test("IR: Control Flow", test_ir_control_flow)
    println("")
    
    // Integration tests
    println("Integration Tests:")
    suite.run_test("Full Pipeline: Counter", test_full_pipeline_counter)
    suite.run_test("Full Pipeline: Token", test_full_pipeline_token)
    println("")
    
    // Print summary
    suite.print_summary()
