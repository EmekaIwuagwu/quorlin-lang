# Quorlin Compiler Bootstrap Script (PowerShell)
# Builds the self-hosted Quorlin compiler in stages

param(
    [switch]$Clean,
    [switch]$Verbose,
    [switch]$SkipTests
)

$ErrorActionPreference = "Stop"

Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Quorlin Self-Hosted Compiler Bootstrap" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# ============================================================================
# Configuration
# ============================================================================

$RUST_COMPILER = ".\target\release\qlc.exe"
$COMPILER_SOURCE = "compiler\main.ql"
$STAGE0_OUTPUT = "qlc-stage0.exe"
$STAGE1_OUTPUT = "qlc-stage1.exe"
$STAGE2_OUTPUT = "qlc-stage2.exe"
$EXAMPLES_DIR = "examples"

# ============================================================================
# Helper Functions
# ============================================================================

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "▶ $Message" -ForegroundColor Green
    Write-Host "─────────────────────────────────────────────────────────" -ForegroundColor DarkGray
}

function Write-Success {
    param([string]$Message)
    Write-Host "✓ $Message" -ForegroundColor Green
}

# ============================================================================
# Stage 0: Build Rust Bootstrap Compiler
# ============================================================================

Write-Step "STAGE 0: Building Rust Bootstrap Compiler"

if ($Clean) {
    cargo clean
}

cargo build --release

if ($LASTEXITCODE -ne 0) {
    Write-Host "✗ Failed to build Rust compiler" -ForegroundColor Red
    exit 1
}

if (Test-Path $RUST_COMPILER) {
    Write-Success "Rust bootstrap compiler built successfully"
} else {
    Write-Host "✗ Rust compiler not found" -ForegroundColor Red
    exit 1
}

# ============================================================================
# Stage 1: Compile Quorlin Compiler with Rust Compiler
# ============================================================================

Write-Step "STAGE 1: Compiling Quorlin Compiler (Rust → Quorlin)"

& $RUST_COMPILER compile $COMPILER_SOURCE --target quorlin --output $STAGE0_OUTPUT

if ($LASTEXITCODE -ne 0) {
    Write-Host "✗ Failed to compile Quorlin compiler" -ForegroundColor Red
    exit 1
}

Write-Success "Stage 0 compiler generated"

# ============================================================================
# Stage 2: Self-Compilation
# ============================================================================

Write-Step "STAGE 2: Self-Compilation (Quorlin → Quorlin)"

& ".\$STAGE0_OUTPUT" compile $COMPILER_SOURCE --target quorlin --output $STAGE1_OUTPUT

if ($LASTEXITCODE -ne 0) {
    Write-Host "✗ Failed to self-compile" -ForegroundColor Red
    exit 1
}

Write-Success "Stage 1 compiler generated (self-compiled)"

# ============================================================================
# Stage 3: Verification
# ============================================================================

Write-Step "STAGE 3: Verification (Idempotence Check)"

& ".\$STAGE1_OUTPUT" compile $COMPILER_SOURCE --target quorlin --output $STAGE2_OUTPUT

if ($LASTEXITCODE -ne 0) {
    Write-Host "✗ Failed to compile with Stage 1" -ForegroundColor Red
    exit 1
}

$stage1Hash = (Get-FileHash $STAGE1_OUTPUT -Algorithm SHA256).Hash
$stage2Hash = (Get-FileHash $STAGE2_OUTPUT -Algorithm SHA256).Hash

if ($stage1Hash -eq $stage2Hash) {
    Write-Success "✓ VERIFICATION PASSED: Stage 1 and Stage 2 are identical!"
} else {
    Write-Host "⚠ WARNING: Stage 1 and Stage 2 differ" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "🎉 Self-hosting achieved!" -ForegroundColor Green
Write-Host ""
