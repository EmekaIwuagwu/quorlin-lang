#!/usr/bin/env pwsh
# ============================================================================
# Quorlin Multi-Chain Compilation Test
# Tests compilation to all 6 blockchain targets
# ============================================================================

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptDir

Write-Host ""
Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "     Quorlin Multi-Chain Compilation Test Suite                       " -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host ""

$qlc = "$projectRoot\target\release\qlc.exe"
$outputDir = "$projectRoot\output\multi-chain-tests"

# Create output directory
if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

# Test results
$passedCount = 0
$failedCount = 0
$resultsArr = @()

$targets = @(
    @{ Name = "EVM/Yul"; Target = "evm"; Ext = "yul" },
    @{ Name = "Solana/Anchor"; Target = "solana"; Ext = "rs" },
    @{ Name = "Polkadot/ink!"; Target = "ink"; Ext = "rs" },
    @{ Name = "Aptos/Move"; Target = "move"; Ext = "move" },
    @{ Name = "Cardano/Aiken"; Target = "cardano"; Ext = "ak" },
    @{ Name = "Quorlin Bytecode"; Target = "quorlin"; Ext = "qbc" }
)

$testFile = "$projectRoot\compiler\bootstrap_minimal.ql"

Write-Host "Testing: $testFile" -ForegroundColor Yellow
Write-Host ""

foreach ($t in $targets) {
    $outputFile = "$outputDir\bootstrap_$($t.Target).$($t.Ext)"
    
    # Run compiler and capture output
    $ErrorActionPreference = "Continue"
    $null = & $qlc compile $testFile --target $t.Target --output $outputFile 2>&1
    $ErrorActionPreference = "Stop"
    
    if (Test-Path $outputFile) {
        $size = (Get-Item $outputFile).Length
        $sizeStr = if ($size -lt 1024) { "$size B" } else { "$([math]::Round($size/1024, 2)) KB" }
        Write-Host "  [PASS] $($t.Name): $sizeStr" -ForegroundColor Green
        $passedCount++
        $resultsArr += @{ Target = $t.Name; Status = "PASS"; Size = $sizeStr }
    } else {
        Write-Host "  [FAIL] $($t.Name): Compilation failed" -ForegroundColor Red
        $failedCount++
        $resultsArr += @{ Target = $t.Name; Status = "FAIL"; Size = "N/A" }
    }
}

# Summary
Write-Host ""
Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "                          Summary                                     " -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host ""

$total = $passedCount + $failedCount

Write-Host "  Targets Tested:  $total" -ForegroundColor White
Write-Host "  Passed:          $passedCount" -ForegroundColor Green
Write-Host "  Failed:          $failedCount" -ForegroundColor $(if ($failedCount -eq 0) { "Green" } else { "Red" })
Write-Host ""

Write-Host "  Blockchain Targets:" -ForegroundColor Yellow
foreach ($r in $resultsArr) {
    $statusColor = if ($r.Status -eq "PASS") { "Green" } else { "Red" }
    Write-Host "    - $($r.Target): $($r.Status) ($($r.Size))" -ForegroundColor $statusColor
}

Write-Host ""

if ($failedCount -eq 0) {
    Write-Host "[SUCCESS] All 6 blockchain targets compile successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Quorlin now supports:" -ForegroundColor White
    Write-Host "    1. EVM (Ethereum, Polygon, BSC, etc.) - Yul output" -ForegroundColor Cyan
    Write-Host "    2. Solana - Anchor/Rust output" -ForegroundColor Cyan
    Write-Host "    3. Polkadot - ink! Rust output" -ForegroundColor Cyan
    Write-Host "    4. Aptos - Move language output" -ForegroundColor Cyan
    Write-Host "    5. Cardano - Aiken output (NEW!)" -ForegroundColor Cyan
    Write-Host "    6. Quorlin Bytecode - Self-hosting VM target" -ForegroundColor Cyan
    exit 0
} else {
    Write-Host "[WARNING] Some targets failed to compile." -ForegroundColor Yellow
    exit 1
}
