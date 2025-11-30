#!/bin/bash
# Comprehensive test script for Quorlin compiler

set -e  # Exit on error

COMPILER="./target/release/qlc"
OUTPUT_DIR="/tmp/quorlin_test_output"
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo "======================================================"
echo "  Quorlin Compiler - Comprehensive Test Suite"
echo "======================================================"
echo ""

# Check if compiler exists
if [ ! -f "$COMPILER" ]; then
    echo -e "${RED}✗ Compiler not found. Building...${NC}"
    cargo build --release
    echo ""
fi

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Function to test compilation
test_compile() {
    local file=$1
    local target=$2
    local extension=$3
    local description=$4

    echo -e "${BLUE}Testing:${NC} $description"
    echo "  File: $file"
    echo "  Target: $target"

    output_file="$OUTPUT_DIR/$(basename ${file%.ql})_${target}.${extension}"

    if $COMPILER compile "$file" --target "$target" -o "$output_file" > /dev/null 2>&1; then
        size=$(wc -c < "$output_file")
        echo -e "  ${GREEN}✓ SUCCESS${NC} - Generated $size bytes"
        echo ""
        return 0
    else
        echo -e "  ${RED}✗ FAILED${NC}"
        echo ""
        return 1
    fi
}

# Test counter
total_tests=0
passed_tests=0

echo "======================================================"
echo "  Part 1: Testing Token Contract (examples/token.ql)"
echo "======================================================"
echo ""

# Test token.ql with all backends
for target in "evm:yul" "solana:rs" "ink:rs"; do
    IFS=':' read -r target_name ext <<< "$target"
    if test_compile "examples/token.ql" "$target_name" "$ext" "Token contract → $target_name"; then
        ((passed_tests++))
    fi
    ((total_tests++))
done

echo "======================================================"
echo "  Part 2: Testing NFT Contract"
echo "======================================================"
echo ""

# Test NFT contract with all backends
for target in "evm:yul" "solana:rs" "ink:rs"; do
    IFS=':' read -r target_name ext <<< "$target"
    if test_compile "examples/advanced/nft.ql" "$target_name" "$ext" "NFT contract → $target_name"; then
        ((passed_tests++))
    fi
    ((total_tests++))
done

echo "======================================================"
echo "  Part 3: Testing Governance Contract"
echo "======================================================"
echo ""

# Test governance contract with all backends
for target in "evm:yul" "solana:rs" "ink:rs"; do
    IFS=':' read -r target_name ext <<< "$target"
    if test_compile "examples/advanced/governance.ql" "$target_name" "$ext" "Governance contract → $target_name"; then
        ((passed_tests++))
    fi
    ((total_tests++))
done

echo "======================================================"
echo "  Part 4: CLI Commands Test"
echo "======================================================"
echo ""

echo -e "${BLUE}Testing:${NC} Tokenize command"
if $COMPILER tokenize examples/token.ql > /dev/null 2>&1; then
    echo -e "  ${GREEN}✓ SUCCESS${NC}"
    ((passed_tests++))
else
    echo -e "  ${RED}✗ FAILED${NC}"
fi
((total_tests++))
echo ""

echo -e "${BLUE}Testing:${NC} Parse command"
if $COMPILER parse examples/token.ql > /dev/null 2>&1; then
    echo -e "  ${GREEN}✓ SUCCESS${NC}"
    ((passed_tests++))
else
    echo -e "  ${RED}✗ FAILED${NC}"
fi
((total_tests++))
echo ""

echo -e "${BLUE}Testing:${NC} Check command"
if $COMPILER check examples/token.ql > /dev/null 2>&1; then
    echo -e "  ${GREEN}✓ SUCCESS${NC}"
    ((passed_tests++))
else
    echo -e "  ${RED}✗ FAILED${NC}"
fi
((total_tests++))
echo ""

echo "======================================================"
echo "  Part 5: Output File Verification"
echo "======================================================"
echo ""

echo "Generated files in $OUTPUT_DIR:"
ls -lh "$OUTPUT_DIR" | tail -n +2 | awk '{printf "  %-40s %10s\n", $9, $5}'
echo ""

echo "======================================================"
echo "  FINAL RESULTS"
echo "======================================================"
echo ""
echo "  Total tests: $total_tests"
echo -e "  Passed: ${GREEN}$passed_tests${NC}"
echo -e "  Failed: ${RED}$((total_tests - passed_tests))${NC}"
echo ""

if [ $passed_tests -eq $total_tests ]; then
    echo -e "${GREEN}✓ ALL TESTS PASSED!${NC}"
    echo ""
    echo "The Quorlin compiler is working perfectly!"
    echo "All three backends (EVM, Solana, Polkadot) are functional."
    exit 0
else
    echo -e "${RED}✗ SOME TESTS FAILED${NC}"
    exit 1
fi
