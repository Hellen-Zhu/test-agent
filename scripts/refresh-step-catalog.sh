#!/bin/bash
#
# refresh-step-catalog.sh
#
# Scans the project for custom step definitions and updates
# src/test/resources/step-catalog.md (Parts B and C only).
# Part A (genie built-in steps) is preserved in the catalog file.
#
# Usage:
#   ./scripts/refresh-step-catalog.sh [E2E_DIR]
#
# Integrate with git hook:
#   Add to .git/hooks/pre-commit:
#     git diff --cached --name-only | grep -qE '\.(snippet|java|feature)$' && ./scripts/refresh-step-catalog.sh

E2E_DIR="${1:-.}"

CATALOG="$E2E_DIR/src/test/resources/step-catalog.md"
MARKER_START='<!-- CUSTOM_STEPS_MARKER -->'
MARKER_END='<!-- /CUSTOM_STEPS_MARKER -->'

if [ ! -f "$CATALOG" ]; then
    echo "ERROR: step-catalog.md not found at $CATALOG"
    exit 1
fi

echo "=== Refreshing Step Catalog ==="

# --- Part B: Custom Snippet Steps ---
echo "Scanning .snippet files..."
PART_B=""
SNIPPET_FILES=$(find "$E2E_DIR/src/test" -name "*.snippet" 2>/dev/null)

if [ -z "$SNIPPET_FILES" ]; then
    PART_B="| _No custom snippets found_ | |"
else
    PART_B="| Step Pattern | Source File |
|---|---|
"
    for file in $SNIPPET_FILES; do
        while IFS= read -r line; do
            pattern=$(echo "$line" | sed -n 's/.*@\(Given\|When\|Then\) "\(.*\)".*/\2/p')
            if [ -n "$pattern" ]; then
                PART_B="$PART_B| \`$pattern\` | $file |
"
            fi
        done < "$file"
    done
fi

# --- Part C: Custom Java Step Definitions ---
echo "Scanning Java step definitions..."
PART_C=""
JAVA_FILES=$(find "$E2E_DIR/src/test/java" -name "*.java" 2>/dev/null)

if [ -z "$JAVA_FILES" ]; then
    PART_C="| _No custom Java steps found_ | |"
else
    PART_C="| Step Pattern | Source File |
|---|---|
"
    for file in $JAVA_FILES; do
        while IFS= read -r line; do
            pattern=$(echo "$line" | sed -n 's/.*@\(Given\|When\|Then\)("\(.*\)").*/\2/p')
            if [ -n "$pattern" ]; then
                PART_C="$PART_C| \`$pattern\` | $file |
"
            fi
        done < "$file"
    done
fi

# --- Rebuild catalog with updated timestamp ---
HEADER=$(sed -n "1,/Last Updated:/p" "$CATALOG" | sed "s/(auto-updated by git hook \/ CI)/(auto-updated by refresh-step-catalog.sh)/" | sed "s/Last Updated:.*/Last Updated: $(date -u '+%Y-%m-%dT%H:%M:%SZ')/")
TAIL=$(sed -n "/$MARKER_END/,\$p" "$CATALOG")

{
    echo "$HEADER"
    echo ""
    echo "$MARKER_START"
    echo ""
    echo "## Part B: Custom Snippet Steps"
    echo ""
    echo "$PART_B"
    echo ""
    echo "## Part C: Custom Java Step Definitions"
    echo ""
    echo "$PART_C"
    echo ""
    echo "$TAIL"
} > "$CATALOG"

echo "Updated: $CATALOG"
echo "=== Done ==="
