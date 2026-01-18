@echo off
REM ============================================================================
REM test_async_job.bat
REM
REM Tests for async_job.bat - asynchronous job execution
REM Runs PowerShell test script for comprehensive testing
REM ============================================================================

setlocal EnableDelayedExpansion

echo ============================================================================
echo TEST RUNNER: async_job.bat Tests
echo ============================================================================

set "SCRIPT_DIR=%~dp0"
set "UTILS_DIR=%SCRIPT_DIR%.."

REM Run the PowerShell test script
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%test_async_job.ps1" -UtilsDir "%UTILS_DIR%"
set "TEST_RESULT=%ERRORLEVEL%"

if %TEST_RESULT% EQU 0 (
    echo.
    echo All async_job.bat tests passed!
) else (
    echo.
    echo Some async_job.bat tests failed!
)

endlocal
exit /b %TEST_RESULT%
