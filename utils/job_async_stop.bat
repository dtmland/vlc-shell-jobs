@echo off
REM ============================================================================
REM job_async_stop.bat
REM 
REM Purpose: Stop a running async job by its UUID
REM
REM Usage: job_async_stop.bat "job_uuid"
REM
REM Arguments:
REM   job_uuid - The UUID of the job to stop (required)
REM
REM Example:
REM   job_async_stop.bat "78f734c4-496c-40d0-83f4-127d43e97195"
REM
REM This batch file replicates the stop_job function from executor.lua
REM ============================================================================

setlocal EnableDelayedExpansion

REM Check for UUID argument
if "%~1"=="" (
    echo ERROR: No job UUID specified
    echo Usage: job_async_stop.bat "job_uuid"
    echo.
    echo To find running jobs, check: %APPDATA%\jobrunner\
    exit /b 1
)

set "JOB_UUID=%~1"
set "INTERNALS_DIR=%APPDATA%\jobrunner\%JOB_UUID%"
set "PID_FILE=%INTERNALS_DIR%\job_pid.txt"
set "STATUS_FILE=%INTERNALS_DIR%\job_status.txt"

echo ============================================================================
echo STOP JOB
echo ============================================================================
echo Job UUID: %JOB_UUID%
echo Internals Directory: %INTERNALS_DIR%
echo ============================================================================
echo.

REM Check if internals directory exists
if not exist "%INTERNALS_DIR%" (
    echo ERROR: Job directory not found: %INTERNALS_DIR%
    echo The job may not exist or has already been cleaned up.
    exit /b 1
)

REM Read current status
set "CURRENT_STATUS="
if exist "%STATUS_FILE%" (
    for /f "usebackq tokens=*" %%s in ("%STATUS_FILE%") do set "CURRENT_STATUS=%%s"
)
for /f "tokens=* delims= " %%a in ("%CURRENT_STATUS%") do set "CURRENT_STATUS=%%a"

echo Current job status: %CURRENT_STATUS%

REM Check if job is already finished
if "%CURRENT_STATUS%"=="SUCCESS" (
    echo Job has already completed successfully. No need to stop.
    exit /b 0
)
if "%CURRENT_STATUS%"=="FAILURE" (
    echo Job has already failed. No need to stop.
    exit /b 0
)

REM Read PID from file
set "JOB_PID="
if exist "%PID_FILE%" (
    echo PID file found: %PID_FILE%
    echo PID file contents:
    type "%PID_FILE%"
    echo.
    for /f "usebackq tokens=*" %%p in ("%PID_FILE%") do set "JOB_PID=%%p"
) else (
    echo PID file not found: %PID_FILE%
)

if "%JOB_PID%"=="" (
    echo ERROR: Could not find PID file or PID is empty
    echo The job may still be starting or has already completed.
    exit /b 1
)

echo Job PID: %JOB_PID%
echo.
echo Attempting to stop the job and its child processes...
echo.

REM Get the directory where this script is located (to find create_job_async_stop.ps1)
set "SCRIPT_DIR=%~dp0"

REM Define path for the generated kill script
set "KILL_BAT=%INTERNALS_DIR%\kill_tree_runner.bat"

REM Call the PowerShell script to generate the kill tree batch file
REM This avoids complex bat-to-bat escaping issues
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%create_job_async_stop.ps1" -JobPID %JOB_PID% -JobUUID "%JOB_UUID%" -OutputBatFile "%KILL_BAT%"

REM Execute the generated kill script
call "%KILL_BAT%"

echo.
echo ============================================================================
echo Job stop command executed.
echo ============================================================================
echo.

REM Update status file to indicate stopped
echo STOPPED>"%STATUS_FILE%"
echo Job status updated to STOPPED.

REM Show final output
echo.
echo --- STDOUT (at time of stop) ---
if exist "%INTERNALS_DIR%\stdout.txt" (
    type "%INTERNALS_DIR%\stdout.txt"
) else (
    echo [No stdout captured]
)
echo.

echo --- STDERR (at time of stop) ---
if exist "%INTERNALS_DIR%\stderr.txt" (
    type "%INTERNALS_DIR%\stderr.txt"
) else (
    echo [No stderr captured]
)
echo.

echo ============================================================================
echo Session files located in: %INTERNALS_DIR%
echo ============================================================================

endlocal
exit /b 0