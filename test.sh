#!/usr/bin/env bash

set -euo pipefail

SCRIPT="./get-nix-pkg-commit-hash.sh"
PASS=0
FAIL=0

run_test() {
    local name="$1"
    local expected_exit="$2"
    local expected_pattern="$3"
    shift 3

    echo "── Test: $name"
    set +e +o pipefail
    RAW_OUTPUT=$("$SCRIPT" "$@" 2>&1)
    ACTUAL_EXIT=$?
    set -e -o pipefail
    OUTPUT=$(echo "$RAW_OUTPUT" | sed 's/\x1b\[[0-9;]*m//g')

    if [[ "$ACTUAL_EXIT" -ne "$expected_exit" ]]; then
        echo "  FAIL — expected exit $expected_exit, got $ACTUAL_EXIT"
        echo "  Output: $OUTPUT"
        FAIL=$((FAIL + 1))
        return
    fi

    if [[ -n "$expected_pattern" ]] && ! echo "$OUTPUT" | grep -qiE "$expected_pattern"; then
        echo "  FAIL — output did not match pattern: $expected_pattern"
        echo "  Output: $OUTPUT"
        FAIL=$((FAIL + 1))
        return
    fi

    echo "  PASS"
    PASS=$((PASS + 1))
}

echo "Running tests..."
echo ""

# Test 1: Find virtualbox 7.2.6 commit
run_test "virtualbox 7.2.6" 0 "Found matching commit" virtualbox 7.2.6

# Test 2: Non-existing package should fail
run_test "non-existing package" 1 "not found" this-package-does-not-exist-xyz 99.99.99

echo ""
echo "──────────────────────────"
echo "Results: $PASS passed, $FAIL failed"

if [[ "$FAIL" -gt 0 ]]; then
    exit 1
fi
