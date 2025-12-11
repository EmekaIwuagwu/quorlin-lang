# Compile All Examples Script
# Compiles all .ql files in examples/ to all supported backends

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  Quorlin Multi-Contract Compilation" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

$ErrorActionPreference = "Continue"

# Configuration
$EXAMPLES_DIR = "examples"
$OUTPUT_DIR = "compiled_contracts"
$BACKENDS = @("evm", "solana", "polkadot", "aptos")

# Create output directories
foreach ($backend in $BACKENDS) {
    New-Item -ItemType Directory -Force -Path "$OUTPUT_DIR\$backend" | Out-Null
}

# Get all .ql files (excluding subdirectories for now)
$contracts = Get-ChildItem -Path $EXAMPLES_DIR -Filter "*.ql" -File

Write-Host "Found" $contracts.Count "contracts to compile" -ForegroundColor Green
Write-Host "Backends:" ($BACKENDS -join ', ') -ForegroundColor Green
Write-Host ""

# Statistics
$totalCompilations = 0
$successCount = 0
$failCount = 0
$skippedCount = 0

# Track results
$results = @()

foreach ($contract in $contracts) {
    $contractName = $contract.BaseName
    
    Write-Host "================================================================" -ForegroundColor DarkGray
    Write-Host "Compiling:" $contract.Name -ForegroundColor Yellow
    Write-Host "================================================================" -ForegroundColor DarkGray
    Write-Host ""
    
    foreach ($backend in $BACKENDS) {
        $totalCompilations++
        
        $extension = switch ($backend) {
            "evm" { ".yul" }
            "solana" { ".rs" }
            "polkadot" { ".rs" }
            "aptos" { ".move" }
        }
        
        $outputFile = "$OUTPUT_DIR\$backend\$contractName$extension"
        
        Write-Host "  -> $backend" -NoNewline -ForegroundColor Cyan
        
        # Compile
        $result = & ".\target\release\qlc.exe" compile $contract.FullName --target $backend --output $outputFile 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            $successCount++
            Write-Host " [OK]" -ForegroundColor Green
            
            # Get file size
            if (Test-Path $outputFile) {
                $size = (Get-Item $outputFile).Length
                $results += [PSCustomObject]@{
                    Contract = $contractName
                    Backend = $backend
                    Status = "Success"
                    Size = $size
                    Output = $outputFile
                }
            }
        } else {
            # Check if it's a parse error (struct not supported)
            if ($result -match "Parse error.*Struct") {
                $skippedCount++
                Write-Host " [SKIP - Structs not supported]" -ForegroundColor Yellow
                $results += [PSCustomObject]@{
                    Contract = $contractName
                    Backend = $backend
                    Status = "Skipped"
                    Reason = "Structs not supported"
                }
            } else {
                $failCount++
                Write-Host " [FAIL]" -ForegroundColor Red
                $results += [PSCustomObject]@{
                    Contract = $contractName
                    Backend = $backend
                    Status = "Failed"
                    Error = $result
                }
            }
        }
    }
    
    Write-Host ""
}

# Summary
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  Compilation Summary" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Total Compilations:" $totalCompilations -ForegroundColor White
Write-Host "Successful:" $successCount -ForegroundColor Green
Write-Host "Failed:" $failCount -ForegroundColor Red
Write-Host "Skipped:" $skippedCount -ForegroundColor Yellow
Write-Host ""

# Success rate
$successRate = [math]::Round(($successCount / $totalCompilations) * 100, 2)
Write-Host "Success Rate:" "$successRate%" -ForegroundColor $(if ($successRate -gt 75) { "Green" } elseif ($successRate -gt 50) { "Yellow" } else { "Red" })
Write-Host ""

# List successful compilations
Write-Host "Successful Compilations:" -ForegroundColor Green
$successfulResults = $results | Where-Object { $_.Status -eq "Success" }
$successfulResults | Group-Object Backend | ForEach-Object {
    Write-Host "  $($_.Name):" $_.Count "files" -ForegroundColor Cyan
}
Write-Host ""

# List skipped
if ($skippedCount -gt 0) {
    Write-Host "Skipped (Structs not supported):" -ForegroundColor Yellow
    $skippedResults = $results | Where-Object { $_.Status -eq "Skipped" }
    $skippedResults | Select-Object -Unique Contract | ForEach-Object {
        Write-Host "  -" $_.Contract -ForegroundColor Gray
    }
    Write-Host ""
}

# List failures
if ($failCount -gt 0) {
    Write-Host "Failed Compilations:" -ForegroundColor Red
    $failedResults = $results | Where-Object { $_.Status -eq "Failed" }
    $failedResults | ForEach-Object {
        Write-Host "  - $($_.Contract) ($($_.Backend))" -ForegroundColor Gray
    }
    Write-Host ""
}

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  Compilation Complete!" -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Output Directory:" $OUTPUT_DIR -ForegroundColor White
Write-Host ""
