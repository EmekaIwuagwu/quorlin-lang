# Compile Real World Contracts to ALL Backends
# Targets files in examples/contracts/

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  REAL WORLD CONTRACTS COMPILATION" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

$ErrorActionPreference = "Continue"

$CONTRACTS_DIR = "examples\contracts"
$OUTPUT_DIR = "output"
$BACKENDS = @("evm", "solana", "polkadot", "aptos", "quorlin")

# Create output directories if they don't exist
if (-not (Test-Path $OUTPUT_DIR)) {
    New-Item -ItemType Directory -Path $OUTPUT_DIR | Out-Null
}

foreach ($backend in $BACKENDS) {
    $backendDir = "$OUTPUT_DIR\$backend"
    if (-not (Test-Path $backendDir)) {
        New-Item -ItemType Directory -Path $backendDir | Out-Null
    }
}

# Get all .ql files in contracts directory
$contracts = Get-ChildItem -Path $CONTRACTS_DIR -Filter "*.ql" -File

if ($contracts.Count -eq 0) {
    Write-Host "No contracts found in $CONTRACTS_DIR" -ForegroundColor Red
    Exit
}

Write-Host "Found" $contracts.Count "contracts in $CONTRACTS_DIR" -ForegroundColor Green
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
        
        # Run compilation using cargo run to ensure latest build
        # Using output redirection to capture stderr separately if needed, but for now just running it
        # Note: Using cargo run --quiet to minimize build output noise
        
        $process = Start-Process -FilePath "cargo" `
            -ArgumentList "run", "--quiet", "--bin", "qlc", "--", "compile", $contract.FullName, "--target", $backend, "--output", $outputFile `
            -NoNewWindow -Wait -PassThru
        
        # Check exit code and file existence
        if ($process.ExitCode -eq 0 -and (Test-Path $outputFile)) {
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
Write-Host "  COMPILATION RESULTS" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Total Compilations:" $totalCompilations -ForegroundColor White
Write-Host "Successful:" $successCount -ForegroundColor Green
Write-Host "Failed:" $failCount -ForegroundColor Red
$successRate = 0
if ($totalCompilations -gt 0) {
    $successRate = [math]::Round(($successCount / $totalCompilations) * 100, 2)
}
Write-Host "Success Rate:" "$successRate%" -ForegroundColor $(if ($successRate -eq 100) { "Green" } elseif ($successRate -gt 75) { "Yellow" } else { "Red" })
Write-Host ""

# List generated files
Write-Host "Generated Output:" -ForegroundColor Yellow
foreach ($backend in $BACKENDS) {
    $files = Get-ChildItem -Path "$OUTPUT_DIR\$backend" -File -ErrorAction SilentlyContinue
    if ($files) {
        $count = $files.Count
        Write-Host "  ${backend}: $count files" -ForegroundColor Cyan
    } else {
         Write-Host "  ${backend}: 0 files" -ForegroundColor Cyan
    }
}
Write-Host ""
