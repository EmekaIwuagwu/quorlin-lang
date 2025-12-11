# Compile ALL Examples to ALL Backends
# Final comprehensive compilation

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  FINAL COMPILATION - ALL EXAMPLES TO ALL BACKENDS" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

$ErrorActionPreference = "Continue"

$EXAMPLES_DIR = "examples"
$OUTPUT_DIR = "compiled_contracts"
$BACKENDS = @("evm", "solana", "polkadot", "aptos", "quorlin")

# Get all .ql files
$contracts = Get-ChildItem -Path $EXAMPLES_DIR -Filter "*.ql" -File

Write-Host "Found" $contracts.Count "contracts" -ForegroundColor Green
Write-Host "Backends: 5 (EVM, Solana, Polkadot, Aptos, Quorlin)" -ForegroundColor Green
Write-Host ""

$totalCompilations = $contracts.Count * $BACKENDS.Count
$successCount = 0
$failCount = 0

foreach ($contract in $contracts) {
    $contractName = $contract.BaseName
    
    Write-Host "Compiling: $contractName" -ForegroundColor Yellow
    
    foreach ($backend in $BACKENDS) {
        $extension = switch ($backend) {
            "evm" { ".yul" }
            "solana" { ".rs" }
            "polkadot" { ".rs" }
            "aptos" { ".move" }
            "quorlin" { ".qbc" }
        }
        
        $outputFile = "$OUTPUT_DIR\$backend\$contractName$extension"
        
        Write-Host "  -> $backend" -NoNewline -ForegroundColor Cyan
        
        $result = & ".\target\release\qlc.exe" compile $contract.FullName --target $backend --output $outputFile 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            $successCount++
            Write-Host " [OK]" -ForegroundColor Green
        } else {
            $failCount++
            Write-Host " [FAIL]" -ForegroundColor Red
        }
    }
    
    Write-Host ""
}

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  FINAL RESULTS" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Total Compilations:" $totalCompilations -ForegroundColor White
Write-Host "Successful:" $successCount -ForegroundColor Green
Write-Host "Failed:" $failCount -ForegroundColor Red
$successRate = [math]::Round(($successCount / $totalCompilations) * 100, 2)
Write-Host "Success Rate:" "$successRate%" -ForegroundColor $(if ($successRate -eq 100) { "Green" } elseif ($successRate -gt 75) { "Yellow" } else { "Red" })
Write-Host ""

# List generated files
Write-Host "Generated Files by Backend:" -ForegroundColor Yellow
foreach ($backend in $BACKENDS) {
    $files = Get-ChildItem -Path "$OUTPUT_DIR\$backend" -File -ErrorAction SilentlyContinue
    if ($files) {
        $count = $files.Count
        Write-Host "  ${backend}: $count files" -ForegroundColor Cyan
    }
}
Write-Host ""

if ($successRate -eq 100) {
    Write-Host "🎉 100% SUCCESS! ALL EXAMPLES COMPILED TO ALL BACKENDS! 🎉" -ForegroundColor Green
} else {
    Write-Host "⚠️  Some compilations failed. Check errors above." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Output Directory: $OUTPUT_DIR" -ForegroundColor White
Write-Host ""
