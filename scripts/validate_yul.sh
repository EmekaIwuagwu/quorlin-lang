#!/bin/bash
# Validate Yul files for basic syntax errors

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

validate_file() {
    local file="$1"
    local basename=$(basename "$file")

    echo -n "Validating $basename... "

    # Check if file exists
    if [ ! -f "$file" ]; then
        echo "❌ File not found"
        return 1
    fi

    # Check balanced parentheses
    local open_parens=$(grep -o '(' "$file" | wc -l)
    local close_parens=$(grep -o ')' "$file" | wc -l)
    if [ "$open_parens" != "$close_parens" ]; then
        echo "❌ Unbalanced parentheses: $open_parens opening, $close_parens closing"
        return 1
    fi

    # Check balanced braces
    local open_braces=$(grep -o '{' "$file" | wc -l)
    local close_braces=$(grep -o '}' "$file" | wc -l)
    if [ "$open_braces" != "$close_braces" ]; then
        echo "❌ Unbalanced braces: $open_braces opening, $close_braces closing"
        return 1
    fi

    # Check for Yul object structure
    if ! grep -q 'object "Contract"' "$file"; then
        echo "⚠️  Warning: No Yul object structure found"
    fi

    # Check for runtime object
    if ! grep -q 'object "runtime"' "$file"; then
        echo "⚠️  Warning: No runtime object found"
    fi

    echo "✅ Valid"
    return 0
}

echo "=================================================="
echo "  Quorlin Yul Validation Script"
echo "=================================================="
echo

# Validate all Yul files in output directory
failed=0
total=0

for yul_file in "$PROJECT_ROOT"/output/*.yul; do
    if [ -f "$yul_file" ]; then
        total=$((total + 1))
        if ! validate_file "$yul_file"; then
            failed=$((failed + 1))
        fi
    fi
done

echo
echo "=================================================="
echo "  Summary: $((total - failed))/$total files passed"
echo "=================================================="

if [ $failed -gt 0 ]; then
    echo "❌ $failed file(s) failed validation"
    exit 1
else
    echo "✅ All files passed validation"
    exit 0
fi
