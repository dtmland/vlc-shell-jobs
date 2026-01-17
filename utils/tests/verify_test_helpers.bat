@echo off
REM ============================================================================
REM verify_test_helpers.bat
REM
REM Diagnostic script to verify test_helpers.ps1 functions are working
REM Run this to debug issues with the test infrastructure
REM ============================================================================

echo ============================================================================
echo VERIFY TEST HELPERS
echo ============================================================================
echo.

set "SCRIPT_DIR=%~dp0"

REM Run the PowerShell verification script
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%verify_test_helpers.ps1"

echo.
echo ============================================================================
echo Done. Review output above for any [FAIL] messages.
echo ============================================================================
