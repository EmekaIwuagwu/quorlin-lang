#!/bin/bash
# Quorlin Token - Solana DevNet Deployment Script

set -e

echo "╔════════════════════════════════════════════════════════════╗"
echo "║          🚀 Deploying to Solana DevNet 🚀                ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Step 1: Check Solana installation
echo "[1/5] Checking Solana CLI..."
if ! command -v solana &> /dev/null; then
    echo "❌ Error: Solana CLI not found"
    echo "Install from: https://docs.solana.com/cli/install-solana-cli-tools"
    exit 1
fi
echo "✅ Solana CLI version: $(solana --version)"
echo ""

# Step 2: Check Anchor installation
echo "[2/5] Checking Anchor CLI..."
if ! command -v anchor &> /dev/null; then
    echo "❌ Error: Anchor CLI not found"
    echo "Install from: https://www.anchor-lang.com/docs/installation"
    exit 1
fi
echo "✅ Anchor CLI version: $(anchor --version)"
echo ""

# Step 3: Set Solana to DevNet
echo "[3/5] Configuring Solana for DevNet..."
solana config set --url https://api.devnet.solana.com
NETWORK=$(solana config get | grep "RPC URL" | awk '{print $3}')
echo "✅ Network: $NETWORK"
echo ""

# Step 4: Check wallet balance
echo "[4/5] Checking wallet balance..."
WALLET=$(solana address)
BALANCE=$(solana balance --url devnet | awk '{print $1}')
echo "📍 Wallet: $WALLET"
echo "💰 Balance: $BALANCE SOL"

if (( $(echo "$BALANCE < 0.5" | bc -l) )); then
    echo ""
    echo "⚠️  Low balance detected! Requesting airdrop..."
    solana airdrop 2 --url devnet || true
    sleep 5
    BALANCE=$(solana balance --url devnet | awk '{print $1}')
    echo "💰 New balance: $BALANCE SOL"
fi
echo ""

# Step 5: Build and deploy
echo "[5/5] Building and deploying program..."
anchor build
anchor deploy --provider.cluster devnet

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║              ✨ DEPLOYMENT SUCCESSFUL ✨                  ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "📦 Program deployed to DevNet"
echo "🔗 Explorer: https://explorer.solana.com/address/$(solana address)?cluster=devnet"
echo ""
echo "Next steps:"
echo "1. Save your program ID from above"
echo "2. Update Anchor.toml with the program ID"
echo "3. Run: anchor test --skip-local-validator"
