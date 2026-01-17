@echo off
REM ============================================================================
REM test_block_command.bat
REM
REM Tests for block_command.bat - synchronous command execution
REM Runs PowerShell test script for comprehensive testing
REM ============================================================================

setlocal EnableDelayedExpansion

echo ============================================================================
echo TEST RUNNER: block_command.bat Tests
echo ============================================================================

set "SCRIPT_DIR=%~dp0"
set "UTILS_DIR=%SCRIPT_DIR%.."

REM Run the PowerShell test script
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%test_block_command.ps1" -UtilsDir "%UTILS_DIR%"
set "TEST_RESULT=%ERRORLEVEL%"

if %TEST_RESULT% EQU 0 (
    echo.
    echo All block_command.bat tests passed!
) else (
    echo.
    echo Some block_command.bat tests failed!
)

endlocal
exit /b %TEST_RESULT%
