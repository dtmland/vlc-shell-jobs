@echo off
REM ============================================================================
REM test_job_async_run.bat
REM
REM Tests for job_async_run.bat - asynchronous job execution
REM Runs PowerShell test script for comprehensive testing
REM ============================================================================

setlocal EnableDelayedExpansion

echo ============================================================================
echo TEST RUNNER: job_async_run.bat Tests
echo ============================================================================

set "SCRIPT_DIR=%~dp0"
set "UTILS_DIR=%SCRIPT_DIR%.."

REM Run the PowerShell test script
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%test_job_async_run.ps1" -UtilsDir "%UTILS_DIR%"
set "TEST_RESULT=%ERRORLEVEL%"

if %TEST_RESULT% EQU 0 (
    echo.
    echo All job_async_run.bat tests passed!
) else (
    echo.
    echo Some job_async_run.bat tests failed!
)

endlocal
exit /b %TEST_RESULT%