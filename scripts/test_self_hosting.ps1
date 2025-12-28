#!/usr/bin/env pwsh
# ============================================================================
# Quorlin Self-Hosting Compiler Test Suite
# Tests all self-hosted compiler components using the Rust bootstrap compiler
# ============================================================================

param(
    [switch]$Verbose,
    [switch]$Quick,
    [string]$Target = "evm"
)

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptDir

Write-Host ""
Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "     Quorlin Self-Hosting Compiler Test Suite                         " -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host ""

# Configuration - use nested Join-Path for compatibility
$compilerDir = "$projectRoot\compiler"
$outputDir = "$projectRoot\output\self-hosting-tests"
$qlc = "$projectRoot\target\release\qlc.exe"

# Test results
$script:testsRun = 0
$script:testsPassed = 0
$script:testsFailed = 0
$script:failedTests = @()

# ============================================================================
# Helper Functions
# ============================================================================

function Write-TestHeader {
    param([string]$Title)
    Write-Host ""
    Write-Host "----------------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host "  $Title" -ForegroundColor Yellow
    Write-Host "----------------------------------------------------------------------" -ForegroundColor DarkGray
}

function Test-Component {
    param(
        [string]$Name,
        [string]$SourceFile,
        [string]$OutputBase
    )
    
    $script:testsRun++
    
    if (-not (Test-Path $SourceFile)) {
        Write-Host "  [FAIL] $Name : File not found: $SourceFile" -ForegroundColor Red
        $script:testsFailed++
        $script:failedTests += "$Name (File not found)"
        return $false
    }
    
    $outputFile = "$outputDir\$OutputBase.yul"
    
    try {
        # Compile with the Rust compiler
        $result = & $qlc compile $SourceFile --target $Target --output $outputFile 2>&1
        $exitCode = $LASTEXITCODE
        
        if ($exitCode -eq 0 -and (Test-Path $outputFile)) {
            $fileSize = (Get-Item $outputFile).Length
            Write-Host "  [PASS] $Name ($fileSize bytes)" -ForegroundColor Green
            $script:testsPassed++
            
            if ($Verbose) {
                Write-Host "    Output: $outputFile" -ForegroundColor DarkGray
            }
            return $true
        }
        else {
            Write-Host "  [FAIL] $Name : Compilation error" -ForegroundColor Red
            if ($Verbose -and $result) {
                Write-Host "    Error: $result" -ForegroundColor DarkGray
            }
            $script:testsFailed++
            $script:failedTests += "$Name (Compilation failed)"
            return $false
        }
    }
    catch {
        Write-Host "  [FAIL] $Name : Exception: $_" -ForegroundColor Red
        $script:testsFailed++
        $script:failedTests += "$Name (Exception)"
        return $false
    }
}

function Test-FileExists {
    param(
        [string]$Name,
        [string]$FilePath
    )
    
    $script:testsRun++
    
    if (Test-Path $FilePath) {
        $fileSize = (Get-Item $FilePath).Length
        Write-Host "  [PASS] $Name exists ($fileSize bytes)" -ForegroundColor Green
        $script:testsPassed++
        return $true
    }
    else {
        Write-Host "  [FAIL] $Name not found: $FilePath" -ForegroundColor Red
        $script:testsFailed++
        $script:failedTests += "$Name (Not found)"
        return $false
    }
}

function Test-SyntaxCheck {
    param(
        [string]$Name,
        [string]$SourceFile
    )
    
    $script:testsRun++
    
    if (-not (Test-Path $SourceFile)) {
        Write-Host "  [FAIL] $Name : File not found" -ForegroundColor Red
        $script:testsFailed++
        $script:failedTests += "$Name (File not found)"
        return $false
    }
    
    try {
        $result = & $qlc tokenize $SourceFile 2>&1
        $exitCode = $LASTEXITCODE
        
        if ($exitCode -eq 0) {
            Write-Host "  [PASS] $Name syntax valid" -ForegroundColor Green
            $script:testsPassed++
            return $true
        }
        else {
            Write-Host "  [FAIL] $Name : Syntax error" -ForegroundColor Red
            if ($Verbose) {
                Write-Host "    Error: $result" -ForegroundColor DarkGray
            }
            $script:testsFailed++
            $script:failedTests += "$Name (Syntax error)"
            return $false
        }
    }
    catch {
        Write-Host "  [FAIL] $Name : Exception: $_" -ForegroundColor Red
        $script:testsFailed++
        $script:failedTests += "$Name (Exception)"
        return $false
    }
}

# ============================================================================
# Pre-flight Checks
# ============================================================================

Write-TestHeader "Pre-flight Checks"

# Check if Rust compiler exists
if (-not (Test-Path $qlc)) {
    Write-Host "  [WARN] Rust compiler not found. Building..." -ForegroundColor Yellow
    Push-Location $projectRoot
    try {
        & cargo build --release
        if ($LASTEXITCODE -ne 0) {
            Write-Host "  [FAIL] Failed to build Rust compiler" -ForegroundColor Red
            exit 1
        }
        Write-Host "  [PASS] Rust compiler built successfully" -ForegroundColor Green
    }
    finally {
        Pop-Location
    }
}
else {
    Write-Host "  [PASS] Rust compiler found: $qlc" -ForegroundColor Green
}

# Create output directory
if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}
Write-Host "  [PASS] Output directory: $outputDir" -ForegroundColor Green

# ============================================================================
# Test 1: Verify Self-Hosting Component Files Exist
# ============================================================================

Write-TestHeader "Step 1: Verify Component Files Exist"

# Frontend components
Test-FileExists "AST Definitions" "$compilerDir\frontend\ast.ql"
Test-FileExists "Lexer" "$compilerDir\frontend\lexer.ql"
Test-FileExists "Parser" "$compilerDir\frontend\parser.ql"

# Middle-end components
Test-FileExists "Semantic Analyzer" "$compilerDir\middle\semantic.ql"
Test-FileExists "IR Builder" "$compilerDir\middle\ir_builder.ql"
Test-FileExists "Optimizer" "$compilerDir\middle\optimizer.ql"
Test-FileExists "Advanced Optimizer" "$compilerDir\middle\advanced_optimizer.ql"

# Backend components
Test-FileExists "EVM Backend" "$compilerDir\backends\evm.ql"
Test-FileExists "Solana Backend" "$compilerDir\backends\solana.ql"
Test-FileExists "Ink Backend" "$compilerDir\backends\ink.ql"
Test-FileExists "Move Backend" "$compilerDir\backends\move.ql"
Test-FileExists "Quorlin Backend" "$compilerDir\backends\quorlin.ql"

# Runtime components
Test-FileExists "Standard Library" "$compilerDir\runtime\stdlib.ql"
Test-FileExists "Virtual Machine" "$compilerDir\runtime\vm.ql"

# Main compiler
Test-FileExists "Main Entry Point" "$compilerDir\main.ql"
Test-FileExists "Test Suite" "$compilerDir\tests.ql"

# ============================================================================
# Test 2: Syntax Validation (Tokenize)
# ============================================================================

if (-not $Quick) {
    Write-TestHeader "Step 2: Syntax Validation (Tokenize)"
    
    # Frontend
    Test-SyntaxCheck "AST Definitions" "$compilerDir\frontend\ast.ql"
    Test-SyntaxCheck "Lexer" "$compilerDir\frontend\lexer.ql"
    Test-SyntaxCheck "Parser" "$compilerDir\frontend\parser.ql"
    
    # Middle-end
    Test-SyntaxCheck "Semantic Analyzer" "$compilerDir\middle\semantic.ql"
    Test-SyntaxCheck "IR Builder" "$compilerDir\middle\ir_builder.ql"
    Test-SyntaxCheck "Optimizer" "$compilerDir\middle\optimizer.ql"
    
    # Backends
    Test-SyntaxCheck "EVM Backend" "$compilerDir\backends\evm.ql"
    Test-SyntaxCheck "Solana Backend" "$compilerDir\backends\solana.ql"
    Test-SyntaxCheck "Ink Backend" "$compilerDir\backends\ink.ql"
    Test-SyntaxCheck "Move Backend" "$compilerDir\backends\move.ql"
    Test-SyntaxCheck "Quorlin Backend" "$compilerDir\backends\quorlin.ql"
    
    # Runtime
    Test-SyntaxCheck "Standard Library" "$compilerDir\runtime\stdlib.ql"
    Test-SyntaxCheck "Virtual Machine" "$compilerDir\runtime\vm.ql"
    
    # Main
    Test-SyntaxCheck "Main Entry Point" "$compilerDir\main.ql"
}

# ============================================================================
# Test 3: Compile Self-Hosting Components
# ============================================================================

Write-TestHeader "Step 3: Compile Self-Hosting Components"

# Compile each component to verify it works with the Rust compiler
Test-Component "AST Definitions" "$compilerDir\frontend\ast.ql" "ast_compiled"
Test-Component "Lexer" "$compilerDir\frontend\lexer.ql" "lexer_compiled"
Test-Component "Parser" "$compilerDir\frontend\parser.ql" "parser_compiled"
Test-Component "Semantic Analyzer" "$compilerDir\middle\semantic.ql" "semantic_compiled"
Test-Component "IR Builder" "$compilerDir\middle\ir_builder.ql" "ir_builder_compiled"
Test-Component "EVM Backend" "$compilerDir\backends\evm.ql" "evm_backend_compiled"
Test-Component "Quorlin Backend" "$compilerDir\backends\quorlin.ql" "quorlin_backend_compiled"
Test-Component "Standard Library" "$compilerDir\runtime\stdlib.ql" "stdlib_compiled"
Test-Component "Virtual Machine" "$compilerDir\runtime\vm.ql" "vm_compiled"
Test-Component "Main Entry Point" "$compilerDir\main.ql" "main_compiled"
Test-Component "Test Suite" "$compilerDir\tests.ql" "tests_compiled"

# ============================================================================
# Test 4: Compile Example Contracts (Validation)
# ============================================================================

Write-TestHeader "Step 4: Compile Example Contracts (Validation)"

$examplesDir = "$projectRoot\examples"
$examples = @(
    "00_counter_simple.ql",
    "01_hello_world.ql",
    "02_variables.ql",
    "03_arithmetic.ql",
    "04_functions.ql",
    "05_control_flow.ql",
    "06_data_structures.ql",
    "token.ql"
)

foreach ($example in $examples) {
    $examplePath = "$examplesDir\$example"
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($example)
    Test-Component "Example: $baseName" $examplePath "example_$baseName"
}

# ============================================================================
# Summary
# ============================================================================

Write-Host ""
Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "     Test Summary                                                     " -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host ""

$passRate = if ($script:testsRun -gt 0) { [math]::Round(($script:testsPassed / $script:testsRun) * 100, 1) } else { 0 }

Write-Host "  Total Tests:   $($script:testsRun)" -ForegroundColor White
Write-Host "  Passed:        $($script:testsPassed)" -ForegroundColor Green
Write-Host "  Failed:        $($script:testsFailed)" -ForegroundColor $(if ($script:testsFailed -gt 0) { "Red" } else { "Green" })
Write-Host "  Pass Rate:     $passRate%" -ForegroundColor $(if ($passRate -eq 100) { "Green" } elseif ($passRate -ge 80) { "Yellow" } else { "Red" })

if ($script:testsFailed -gt 0) {
    Write-Host ""
    Write-Host "Failed Tests:" -ForegroundColor Red
    foreach ($failed in $script:failedTests) {
        Write-Host "  - $failed" -ForegroundColor Red
    }
}

Write-Host ""

if ($script:testsFailed -eq 0) {
    Write-Host "[SUCCESS] All tests passed! Self-hosting compiler components are ready." -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps for full self-hosting:" -ForegroundColor Yellow
    Write-Host "  1. Compile compiler/main.ql with --target quorlin to generate bytecode" -ForegroundColor White
    Write-Host "  2. Execute the bytecode with the VM to verify functionality" -ForegroundColor White
    Write-Host "  3. Use the self-compiled compiler to compile itself (Stage 2)" -ForegroundColor White
    exit 0
}
else {
    Write-Host "[WARNING] Some tests failed. Please fix the issues above." -ForegroundColor Yellow
    exit 1
}
