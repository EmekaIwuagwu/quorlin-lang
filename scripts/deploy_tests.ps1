$date = Get-Date -Format "ddMMyyyy"
$baseDir = Join-Path $PSScriptRoot "..\tests"

Write-Host "🚀 Deploying Validation Tests for Date: $date" -ForegroundColor Cyan

# Ensure base directory exists
if (!(Test-Path $baseDir)) { New-Item -ItemType Directory -Force $baseDir | Out-Null }

# --- 1. Hardhat (EVM) ---
$hardhatDir = Join-Path $baseDir "Hardhat-evm-$date"
$hardhatContracts = Join-Path $hardhatDir "contracts"
New-Item -ItemType Directory -Force $hardhatContracts | Out-Null

Write-Host "→ Compiling for Hardhat (EVM)..." -ForegroundColor Yellow
cargo run --quiet -- compile examples/token.ql --target evm --output "$hardhatContracts\Token.yul"

# Generate scaffolding
Set-Content (Join-Path $hardhatDir "hardhat.config.js") @"
require("@nomicfoundation/hardhat-toolbox");

module.exports = {
  solidity: "0.8.19",
};
"@

Set-Content (Join-Path $hardhatDir "package.json") @"
{
  "name": "quorlin-hardhat-test",
  "version": "1.0.0",
  "description": "Generated test for Quorlin EVM target",
  "scripts": {
    "test": "hardhat test"
  },
  "devDependencies": {
    "hardhat": "^2.19.0",
    "@nomicfoundation/hardhat-toolbox": "^4.0.0"
  }
}
"@

# --- 2. Solana (Anchor) ---
$solDir = Join-Path $baseDir "solana-$date"
$solSrc = Join-Path $solDir "src"
New-Item -ItemType Directory -Force $solSrc | Out-Null

Write-Host "→ Compiling for Solana (Anchor)..." -ForegroundColor Yellow
cargo run --quiet -- compile examples/token.ql --target solana --output "$solSrc\lib.rs"

# Generate scaffolding
Set-Content (Join-Path $solDir "Cargo.toml") @"
[package]
name = "quorlin_solana_test"
version = "0.1.0"
edition = "2021"

[dependencies]
anchor-lang = "0.29.0"
"@

Set-Content (Join-Path $solDir "Anchor.toml") @"
[features]
seeds = false
skip-lint = false
[programs.localnet]
quorlin_solana_test = "Fg6PaFpoGXkYsidMpWTK6W2BeZ7FEfcYkg476zPFsLnS"
[registry]
url = "https://api.apr.dev"
[provider]
cluster = "Localnet"
wallet = "~/.config/solana/id.json"
"@

# --- 3. Cardano (Aiken) ---
$cardanoDir = Join-Path $baseDir "cardano-$date"
$cardanoValidators = Join-Path $cardanoDir "validators"
New-Item -ItemType Directory -Force $cardanoValidators | Out-Null

Write-Host "→ Compiling for Cardano (Aiken)..." -ForegroundColor Yellow
cargo run --quiet -- compile examples/token.ql --target cardano --output "$cardanoValidators\token.ak"

# Generate scaffolding
Set-Content (Join-Path $cardanoDir "aiken.toml") @"
name = "quorlin/cardano-test"
version = "0.0.0"
licences = ["Apache-2.0"]
description = "Generated test for Quorlin Cardano target"
"@

# --- 4. Aptos (Move) ---
$aptosDir = Join-Path $baseDir "aptos-$date"
$aptosSources = Join-Path $aptosDir "sources"
New-Item -ItemType Directory -Force $aptosSources | Out-Null

Write-Host "→ Compiling for Aptos (Move)..." -ForegroundColor Yellow
cargo run --quiet -- compile examples/token.ql --target aptos --output "$aptosSources\Token.move"

# Generate scaffolding
Set-Content (Join-Path $aptosDir "Move.toml") @"
[package]
name = "QuorlinAptosTest"
version = "0.0.0"

[dependencies]
AptosFramework = { git = "https://github.com/aptos-labs/aptos-core.git", subdir = "aptos-move/framework/aptos-framework", rev = "main" }
"@

Write-Host "`n✅ All tests generated successfully in $baseDir" -ForegroundColor Green
