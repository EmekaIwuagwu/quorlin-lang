#!/bin/bash
# Quorlin → Solana Full Pipeline
# Compiles Quorlin contract and deploys to Solana DevNet

set -e

echo "╔════════════════════════════════════════════════════════════╗"
echo "║        🔥 Quorlin → Solana DevNet Pipeline 🔥            ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Configuration
QUORLIN_SOURCE="../examples/token.ql"
OUTPUT_FILE="./programs/quorlin-token/src/lib_generated.rs"
NETWORK="devnet"

# Step 1: Compile Quorlin → Solana/Anchor
echo "[1/6] Compiling Quorlin → Solana/Anchor..."
if [ ! -f "../target/release/qlc" ]; then
    echo "Building Quorlin compiler..."
    cd ..
    cargo build --release
    cd anchor-test
fi

../target/release/qlc compile $QUORLIN_SOURCE --target solana --output $OUTPUT_FILE
echo "✅ Generated Anchor code: $OUTPUT_FILE"
echo ""

# Step 2: Check Solana CLI
echo "[2/6] Checking Solana CLI..."
if ! command -v solana &> /dev/null; then
    echo "❌ Error: Solana CLI not found"
    echo "Install: https://docs.solana.com/cli/install-solana-cli-tools"
    exit 1
fi
echo "✅ Solana version: $(solana --version)"
echo ""

# Step 3: Check Anchor CLI
echo "[3/6] Checking Anchor CLI..."
if ! command -v anchor &> /dev/null; then
    echo "❌ Error: Anchor CLI not found"
    echo "Install: https://www.anchor-lang.com/docs/installation"
    exit 1
fi
echo "✅ Anchor version: $(anchor --version)"
echo ""

# Step 4: Configure network
echo "[4/6] Configuring Solana for $NETWORK..."
solana config set --url https://api.$NETWORK.solana.com
echo "✅ Network: $(solana config get | grep 'RPC URL' | awk '{print $3}')"
echo ""

# Step 5: Check wallet
echo "[5/6] Checking wallet..."
WALLET=$(solana address)
BALANCE=$(solana balance --url $NETWORK 2>/dev/null | awk '{print $1}' || echo "0")
echo "📍 Wallet: $WALLET"
echo "💰 Balance: $BALANCE SOL"

if (( $(echo "$BALANCE < 0.5" | bc -l) )); then
    echo ""
    echo "⚠️  Low balance! Requesting airdrop..."
    solana airdrop 2 --url $NETWORK || echo "Airdrop may have failed (rate limited). Please add funds manually."
    sleep 3
fi
echo ""

# Step 6: Build and deploy
echo "[6/6] Building and deploying to $NETWORK..."
echo "This may take a few minutes..."
echo ""

anchor build

if [ "$NETWORK" == "devnet" ]; then
    anchor deploy --provider.cluster devnet
elif [ "$NETWORK" == "localnet" ]; then
    anchor deploy
fi

PROGRAM_ID=$(solana address -k target/deploy/quorlin_token-keypair.json)

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║              ✨ DEPLOYMENT SUCCESSFUL ✨                  ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "  📦 Program ID: $PROGRAM_ID"
echo "  🌐 Network: $NETWORK"
echo "  💰 Wallet: $WALLET"
echo ""
echo "  🔗 View on Explorer:"
echo "     https://explorer.solana.com/address/$PROGRAM_ID?cluster=$NETWORK"
echo ""
echo "Next Steps:"
echo "  1. Update Anchor.toml with the Program ID"
echo "  2. Test: anchor test --skip-local-validator"
echo "  3. Interact via client SDK"
