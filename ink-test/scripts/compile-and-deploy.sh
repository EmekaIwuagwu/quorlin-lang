#!/bin/bash

# Quorlin → Polkadot ink! - Automated Compilation and Deployment Script
# This script automates the process of compiling Quorlin contracts to ink! and deploying them

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONTRACT_NAME="token"
QLC_BINARY="${PROJECT_ROOT}/target/release/qlc"
SOURCE_FILE="${PROJECT_ROOT}/examples/${CONTRACT_NAME}.ql"
OUTPUT_DIR="${PROJECT_ROOT}/ink-test/contracts/quorlin-token"
OUTPUT_FILE="${OUTPUT_DIR}/src/lib.rs"
ARTIFACTS_DIR="${PROJECT_ROOT}/ink-test/target/ink/quorlin_token"

# Default values
DEPLOY=false
NODE_URL="ws://127.0.0.1:9944"
SURI="//Alice"
INITIAL_SUPPLY="1000000"

# Help function
show_help() {
    cat << EOF
Quorlin → Polkadot ink! Deployment Script

Usage: $0 [OPTIONS]

OPTIONS:
    -h, --help              Show this help message
    -d, --deploy            Deploy after building (requires running node)
    -u, --url URL           Node WebSocket URL (default: ws://127.0.0.1:9944)
    -s, --suri SURI         Account URI (default: //Alice)
    -i, --initial SUPPLY    Initial token supply (default: 1000000)
    --clean                 Clean build artifacts before compiling

EXAMPLES:
    # Just compile and build
    $0

    # Compile, build, and deploy to local node
    $0 --deploy

    # Deploy to testnet
    $0 --deploy --url wss://rococo-contracts-rpc.polkadot.io --suri "your mnemonic"

EOF
}

# Parse command line arguments
CLEAN=false
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -d|--deploy)
            DEPLOY=true
            shift
            ;;
        -u|--url)
            NODE_URL="$2"
            shift 2
            ;;
        -s|--suri)
            SURI="$2"
            shift 2
            ;;
        -i|--initial)
            INITIAL_SUPPLY="$2"
            shift 2
            ;;
        --clean)
            CLEAN=true
            shift
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            show_help
            exit 1
            ;;
    esac
done

# Print banner
echo -e "${BLUE}"
echo "╔════════════════════════════════════════════════════════════╗"
echo "║     🚀 Quorlin → Polkadot ink! Deployment Script 🚀      ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Step 1: Check prerequisites
echo -e "${YELLOW}[1/6]${NC} Checking prerequisites..."

if [ ! -f "$QLC_BINARY" ]; then
    echo -e "${YELLOW}  → Building Quorlin compiler...${NC}"
    cd "$PROJECT_ROOT"
    cargo build --release --bin qlc
fi

if ! command -v cargo-contract &> /dev/null; then
    echo -e "${RED}  ✗ cargo-contract not found!${NC}"
    echo -e "${YELLOW}  → Installing cargo-contract...${NC}"
    cargo install cargo-contract --version 4.1.1
fi

# Check rust-src component
if ! rustup component list | grep -q "rust-src.*installed"; then
    echo -e "${YELLOW}  → Adding rust-src component...${NC}"
    rustup component add rust-src --toolchain stable
fi

echo -e "${GREEN}  ✓ Prerequisites OK${NC}\n"

# Step 2: Clean if requested
if [ "$CLEAN" = true ]; then
    echo -e "${YELLOW}[2/6]${NC} Cleaning build artifacts..."
    cd "$OUTPUT_DIR"
    cargo clean
    rm -rf "$ARTIFACTS_DIR"
    echo -e "${GREEN}  ✓ Clean complete${NC}\n"
else
    echo -e "${YELLOW}[2/6]${NC} Skipping clean (use --clean to clean build artifacts)\n"
fi

# Step 3: Compile Quorlin to ink!
echo -e "${YELLOW}[3/6]${NC} Compiling Quorlin → ink!..."
echo -e "  Source: ${SOURCE_FILE}"
echo -e "  Output: ${OUTPUT_FILE}"

"$QLC_BINARY" compile "$SOURCE_FILE" --target ink --output "$OUTPUT_FILE"

if [ $? -eq 0 ]; then
    FILE_SIZE=$(du -h "$OUTPUT_FILE" | cut -f1)
    echo -e "${GREEN}  ✓ Compilation successful (${FILE_SIZE})${NC}\n"
else
    echo -e "${RED}  ✗ Compilation failed!${NC}"
    exit 1
fi

# Step 4: Build ink! contract
echo -e "${YELLOW}[4/6]${NC} Building ink! contract to WASM..."
cd "$OUTPUT_DIR"

cargo contract build --release

if [ $? -eq 0 ]; then
    echo -e "${GREEN}  ✓ Build successful${NC}"

    # Show artifact information
    if [ -f "${ARTIFACTS_DIR}/quorlin_token.contract" ]; then
        CONTRACT_SIZE=$(du -h "${ARTIFACTS_DIR}/quorlin_token.contract" | cut -f1)
        WASM_SIZE=$(du -h "${ARTIFACTS_DIR}/quorlin_token.wasm" | cut -f1)
        METADATA_SIZE=$(du -h "${ARTIFACTS_DIR}/quorlin_token.json" | cut -f1)

        echo -e "  ${BLUE}Contract Artifacts:${NC}"
        echo -e "    • Contract bundle: ${CONTRACT_SIZE}"
        echo -e "    • WASM bytecode:   ${WASM_SIZE}"
        echo -e "    • Metadata:        ${METADATA_SIZE}"
        echo -e "    • Location:        ${ARTIFACTS_DIR}/"
    fi
    echo ""
else
    echo -e "${RED}  ✗ Build failed!${NC}"
    exit 1
fi

# Step 5: Deploy (if requested)
if [ "$DEPLOY" = true ]; then
    echo -e "${YELLOW}[5/6]${NC} Deploying to Polkadot node..."
    echo -e "  Node URL:       ${NODE_URL}"
    echo -e "  Account:        ${SURI}"
    echo -e "  Initial Supply: ${INITIAL_SUPPLY}"
    echo ""

    # Check if node is accessible (only for local nodes)
    if [[ "$NODE_URL" == ws://127.0.0.1:* ]]; then
        if ! nc -z 127.0.0.1 9944 2>/dev/null; then
            echo -e "${RED}  ✗ Local node not running!${NC}"
            echo -e "${YELLOW}  → Start it with: substrate-contracts-node --dev${NC}"
            exit 1
        fi
    fi

    # Deploy the contract
    cargo contract instantiate \
        "${ARTIFACTS_DIR}/quorlin_token.contract" \
        --constructor new \
        --args "$INITIAL_SUPPLY" \
        --suri "$SURI" \
        --url "$NODE_URL" \
        --execute \
        --skip-confirm

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}  ✓ Deployment successful!${NC}\n"
        echo -e "${BLUE}Next Steps:${NC}"
        echo -e "  1. Note the contract address from the output above"
        echo -e "  2. Interact using: cargo contract call --contract <ADDRESS> ..."
        echo -e "  3. Or use Contracts UI: https://contracts-ui.substrate.io/"
    else
        echo -e "${RED}  ✗ Deployment failed!${NC}"
        exit 1
    fi
else
    echo -e "${YELLOW}[5/6]${NC} Skipping deployment (use --deploy to deploy)\n"
    echo -e "${BLUE}To deploy manually:${NC}"
    echo -e "  1. Start local node: ${YELLOW}substrate-contracts-node --dev${NC}"
    echo -e "  2. Deploy: ${YELLOW}cargo contract instantiate \\${NC}"
    echo -e "     ${YELLOW}  ${ARTIFACTS_DIR}/quorlin_token.contract \\${NC}"
    echo -e "     ${YELLOW}  --constructor new --args ${INITIAL_SUPPLY} \\${NC}"
    echo -e "     ${YELLOW}  --suri //Alice --execute${NC}"
    echo -e "  3. Or use Contracts UI: ${YELLOW}https://contracts-ui.substrate.io/${NC}"
    echo ""
fi

# Step 6: Summary
echo -e "${YELLOW}[6/6]${NC} Summary"
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗"
echo -e "║              ✨ BUILD SUCCESSFUL ✨                        ║"
echo -e "╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Write-Once, Deploy-Everywhere Achievement:${NC}"
echo -e "  ✅ EVM      (Ethereum, Polygon, BSC, etc.)"
echo -e "  ✅ Solana   (Deployed to DevNet)"
echo -e "  ✅ Polkadot (ink! v5 / Substrate) ${GREEN}← YOU ARE HERE${NC}"
echo ""
echo -e "${BLUE}Contract Details:${NC}"
echo -e "  • Source:    ${SOURCE_FILE}"
echo -e "  • Target:    ink! v5.0.0 (Polkadot/Substrate)"
echo -e "  • Functions: 6 (new, transfer, approve, transfer_from, balance_of, allowance, get_total_supply)"
echo -e "  • Events:    2 (Transfer, Approval)"
echo ""
echo -e "${BLUE}Documentation:${NC}"
echo -e "  • Deployment Guide: ${PROJECT_ROOT}/docs/Deployment-Polkadot.md"
echo -e "  • Architecture:     ${PROJECT_ROOT}/docs/ARCHITECTURE_DETAILED.md"
echo ""
echo -e "${GREEN}🎉 Congratulations! Your Quorlin contract is ready for Polkadot!${NC}"
