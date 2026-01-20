@echo off
REM Test wrapper for job_cleanup.bat
REM Runs the PowerShell test script with proper arguments

setlocal EnableDelayedExpansion

REM Get the directory containing this script
set "SCRIPT_DIR=%~dp0"
set "UTILS_DIR=%SCRIPT_DIR%.."

REM Run the PowerShell test script
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%test_job_cleanup.ps1" -UtilsDir "%UTILS_DIR%"

set "EXIT_CODE=%ERRORLEVEL%"

REM Wait for user if running interactively
if "%1"=="" (
    echo.
    echo Press any key to exit...
    pause >nul
)

exit /b %EXIT_CODE%
