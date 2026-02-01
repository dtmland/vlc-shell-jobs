#!/usr/bin/env bash
# run_lua_tests.sh
# Runs all Lua unit tests

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULE_DIR="$(dirname "$SCRIPT_DIR")"

echo "============================================================================"
echo "LUA TEST RUNNER"
echo "============================================================================"
echo ""
echo "Running Lua unit tests..."
echo "Module directory: $MODULE_DIR"
echo "Tests directory: $SCRIPT_DIR"
echo ""

cd "$SCRIPT_DIR"

PASSED_COUNT=0
FAILED_COUNT=0
FAILED_TESTS=""

# Run test_os_detect.lua
echo ""
echo "############################################################################"
echo "RUNNING: test_os_detect.lua"
echo "############################################################################"
echo ""

if lua test_os_detect.lua; then
    PASSED_COUNT=$((PASSED_COUNT + 1))
    echo "[SUITE PASSED] test_os_detect.lua"
else
    FAILED_COUNT=$((FAILED_COUNT + 1))
    FAILED_TESTS="$FAILED_TESTS test_os_detect.lua"
    echo "[SUITE FAILED] test_os_detect.lua"
fi

# Run test_path_utils.lua
echo ""
echo "############################################################################"
echo "RUNNING: test_path_utils.lua"
echo "############################################################################"
echo ""

if lua test_path_utils.lua; then
    PASSED_COUNT=$((PASSED_COUNT + 1))
    echo "[SUITE PASSED] test_path_utils.lua"
else
    FAILED_COUNT=$((FAILED_COUNT + 1))
    FAILED_TESTS="$FAILED_TESTS test_path_utils.lua"
    echo "[SUITE FAILED] test_path_utils.lua"
fi

# Run test_shell_job_defs.lua
echo ""
echo "############################################################################"
echo "RUNNING: test_shell_job_defs.lua"
echo "############################################################################"
echo ""

if lua test_shell_job_defs.lua; then
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

if lua test_shell_operator_fileio.lua; then
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

if lua test_shell_job_state.lua; then
    PASSED_COUNT=$((PASSED_COUNT + 1))
    echo "[SUITE PASSED] test_shell_job_state.lua"
else
    FAILED_COUNT=$((FAILED_COUNT + 1))
    FAILED_TESTS="$FAILED_TESTS test_shell_job_state.lua"
    echo "[SUITE FAILED] test_shell_job_state.lua"
fi

# Run test_vlc_compat.lua
echo ""
echo "############################################################################"
echo "RUNNING: test_vlc_compat.lua"
echo "############################################################################"
echo ""

if lua test_vlc_compat.lua; then
    PASSED_COUNT=$((PASSED_COUNT + 1))
    echo "[SUITE PASSED] test_vlc_compat.lua"
else
    FAILED_COUNT=$((FAILED_COUNT + 1))
    FAILED_TESTS="$FAILED_TESTS test_vlc_compat.lua"
    echo "[SUITE FAILED] test_vlc_compat.lua"
fi

# Run test_shell_execute.lua
echo ""
echo "############################################################################"
echo "RUNNING: test_shell_execute.lua"
echo "############################################################################"
echo ""

if lua test_shell_execute.lua; then
    PASSED_COUNT=$((PASSED_COUNT + 1))
    echo "[SUITE PASSED] test_shell_execute.lua"
else
    FAILED_COUNT=$((FAILED_COUNT + 1))
    FAILED_TESTS="$FAILED_TESTS test_shell_execute.lua"
    echo "[SUITE FAILED] test_shell_execute.lua"
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
