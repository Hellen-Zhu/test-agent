#!/bin/bash
#
# refresh-step-catalog.sh
#
# Scans the project for custom step definitions and updates
# src/test/resources/step-catalog.md (Parts B and C only).
# Part A (genie built-in steps) is hardcoded and preserved.
#
# Usage:
#   ./scripts/refresh-step-catalog.sh [E2E_DIR]
#
# Integrate with git hook:
#   Add to .git/hooks/pre-commit:
#     git diff --cached --name-only | grep -qE '\.(snippet|java|feature)$' && ./scripts/refresh-step-catalog.sh

E2E_DIR="${1:-.}"

SNIPPET_FILES=$(find "$E2E_DIR/src/test" -name "*.snippet" 2>/dev/null)
JAVA_FILES=$(find "$E2E_DIR/src/test/java" -name "*.java" 2>/dev/null)

echo "=== Scanning custom step definitions ==="

# --- Part B: Custom Snippet Steps ---
echo ""
echo "--- Part B: Custom Snippet Steps ---"

if [ -z "$SNIPPET_FILES" ]; then
    echo "| _No custom snippets found_ | |"
else
    for file in $SNIPPET_FILES; do
        grep -n "@Given\|@When\|@Then" "$file" 2>/dev/null | while read -r line; do
            pattern=$(echo "$line" | sed 's/.*"\(.*\)".*/\1/')
            echo "| \`$pattern\` | $file |"
        done
    done
fi

# --- Part C: Custom Java Step Definitions ---
echo ""
echo "--- Part C: Custom Java Step Definitions ---"

if [ -z "$JAVA_FILES" ]; then
    echo "| _No custom Java steps found_ | |"
else
    for file in $JAVA_FILES; do
        grep -n "@Given\|@When\|@Then" "$file" 2>/dev/null | while read -r line; do
            pattern=$(echo "$line" | sed 's/.*"\(.*\)".*/\1/')
            echo "| \`$pattern\` | $file |"
        done
    done
fi

echo ""
echo "=== Done ==="
