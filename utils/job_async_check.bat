@echo off
REM ============================================================================
REM job_async_check.bat
REM
REM Purpose: Show status, PID, and recent output for a job by UUID
REM
REM Usage: job_async_check.bat "job_uuid" [tail_lines]
REM   job_uuid   - required
REM   tail_lines - optional, number of lines to show from stdout/stderr (default 50)
REM Example:
REM   job_async_check.bat "78f734c4-496c-40d0-83f4-127d43e97195"
REM   job_async_check.bat "78f734c4-496c-40d0-83f4-127d43e97195" 200
REM ============================================================================

setlocal EnableDelayedExpansion

if "%~1"=="" (
    echo ERROR: No job UUID specified
    echo Usage: job_async_check.bat "job_uuid" [tail_lines]
    exit /b 1
)

set "JOB_UUID=%~1"
set "TAIL_LINES=%~2"
if "%TAIL_LINES%"=="" set "TAIL_LINES=50"

set "INTERNALS_DIR=%APPDATA%\jobrunner\%JOB_UUID%"
set "STATUS_FILE=%INTERNALS_DIR%\job_status.txt"
set "PID_FILE=%INTERNALS_DIR%\job_pid.txt"
set "STDOUT_FILE=%INTERNALS_DIR%\stdout.txt"
set "STDERR_FILE=%INTERNALS_DIR%\stderr.txt"

echo ============================================================================
echo CHECK JOB
echo ============================================================================
echo Job UUID: %JOB_UUID%
echo Internals Directory: %INTERNALS_DIR%
echo Tail lines: %TAIL_LINES%
echo ============================================================================

if not exist "%INTERNALS_DIR%" (
    echo ERROR: Job directory not found: %INTERNALS_DIR%
    exit /b 1
)

echo.
echo --- STATUS ---
set "CURRENT_STATUS="
if exist "%STATUS_FILE%" (
    for /f "usebackq tokens=*" %%s in ("%STATUS_FILE%") do set "CURRENT_STATUS=%%s"
)
if "!CURRENT_STATUS!"=="" (
    echo [No status file yet]
) else (
    echo !CURRENT_STATUS!
)
echo.

echo --- PID ---
if exist "%PID_FILE%" (
    for /f "usebackq tokens=* delims= " %%p in ("%PID_FILE%") do set "JOB_PID=%%p"
    echo !JOB_PID!
) else (
    echo [No PID file found]
)
echo.

echo --- LAST %TAIL_LINES% LINES OF STDOUT ---
if exist "%STDOUT_FILE%" (
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-Content -Path '%STDOUT_FILE%' -Tail %TAIL_LINES%" 2>nul || type "%STDOUT_FILE%"
) else (
    echo [No stdout captured]
)
echo.

echo --- LAST %TAIL_LINES% LINES OF STDERR ---
if exist "%STDERR_FILE%" (
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-Content -Path '%STDERR_FILE%' -Tail %TAIL_LINES%" 2>nul || type "%STDERR_FILE%"
) else (
    echo [No stderr captured]
)
echo.

echo ============================================================================
echo Session files: %INTERNALS_DIR%
echo ============================================================================
endlocal
exit /b 0