#!/bin/bash
# run_lua_tests.sh
# Runs all Lua unit tests

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

echo "============================================================================"
echo "LUA TEST RUNNER"
echo "============================================================================"
echo ""
echo "Running Lua unit tests..."
echo "Repository: $REPO_DIR"
echo ""

cd "$REPO_DIR"

PASSED_COUNT=0
FAILED_COUNT=0
FAILED_TESTS=""

# Run test_shell_job_defs.lua
echo ""
echo "############################################################################"
echo "RUNNING: test_shell_job_defs.lua"
echo "############################################################################"
echo ""

if lua tests/test_shell_job_defs.lua; then
    PASSED_COUNT=$((PASSED_COUNT + 1))
    echo "[SUITE PASSED] test_shell_job_defs.lua"
else
    FAILED_COUNT=$((FAILED_COUNT + 1))
    FAILED_TESTS="$FAILED_TESTS test_shell_job_defs.lua"
    echo "[SUITE FAILED] test_shell_job_defs.lua"
fi

# Run test_shell_operator_fileio.lua
echo ""
echo "############################################################################"
echo "RUNNING: test_shell_operator_fileio.lua"
echo "############################################################################"
echo ""

if lua tests/test_shell_operator_fileio.lua; then
    PASSED_COUNT=$((PASSED_COUNT + 1))
    echo "[SUITE PASSED] test_shell_operator_fileio.lua"
else
    FAILED_COUNT=$((FAILED_COUNT + 1))
    FAILED_TESTS="$FAILED_TESTS test_shell_operator_fileio.lua"
    echo "[SUITE FAILED] test_shell_operator_fileio.lua"
fi

# Run test_shell_job_state.lua
echo ""
echo "############################################################################"
echo "RUNNING: test_shell_job_state.lua"
echo "############################################################################"
echo ""

if lua tests/test_shell_job_state.lua; then
    PASSED_COUNT=$((PASSED_COUNT + 1))
    echo "[SUITE PASSED] test_shell_job_state.lua"
else
    FAILED_COUNT=$((FAILED_COUNT + 1))
    FAILED_TESTS="$FAILED_TESTS test_shell_job_state.lua"
    echo "[SUITE FAILED] test_shell_job_state.lua"
fi

# Summary
TOTAL_COUNT=$((PASSED_COUNT + FAILED_COUNT))

echo ""
echo "############################################################################"
echo "LUA TEST SUMMARY"
echo "############################################################################"
echo ""
echo "Test Suites Passed: $PASSED_COUNT / $TOTAL_COUNT"
echo "Test Suites Failed: $FAILED_COUNT / $TOTAL_COUNT"
echo ""

if [ $FAILED_COUNT -gt 0 ]; then
    echo "Failed test suites:$FAILED_TESTS"
    echo ""
    echo "============================================================================"
    echo "RESULT: SOME TEST SUITES FAILED"
    echo "============================================================================"
    exit 1
else
    echo "============================================================================"
    echo "RESULT: ALL TEST SUITES PASSED"
    echo "============================================================================"
    exit 0
fi
