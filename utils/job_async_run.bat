@echo off
REM ============================================================================
REM job_async_run.bat
REM 
REM Purpose: Run a command asynchronously in the background, poll for status,
REM          display ongoing output, and handle Ctrl+C for graceful shutdown.
REM
REM Usage: job_async_run.bat "command" ["working_directory"] ["job_name"]
REM
REM Arguments:
REM   command           - The command to execute (required)
REM   working_directory - Directory to run command from (optional, defaults to %USERPROFILE%)
REM   job_name          - Display name for the job (optional, defaults to "AsyncJob")
REM
REM Example:
REM   job_async_run.bat "ping -n 10 localhost"
REM   job_async_run.bat "ping -n 10 localhost" "C:\Windows" "PingTest"
REM
REM This batch file replicates the async job runner from executor.lua and job_runner.lua
REM ============================================================================

setlocal EnableDelayedExpansion

REM Check for command argument
if "%~1"=="" (
    echo ERROR: No command specified
    echo Usage: job_async_run.bat "command" ["working_directory"] ["job_name"]
    exit /b 1
)

set "COMMAND=%~1"
set "COMMAND_DIR=%~2"
set "JOB_NAME=%~3"

REM Default working directory to USERPROFILE if not specified
if "%COMMAND_DIR%"=="" (
    set "COMMAND_DIR=%USERPROFILE%"
)

REM Default job name
if "%JOB_NAME%"=="" (
    set "JOB_NAME=AsyncJob"
)

REM Generate a UUID for this job (simulating generate_uuid from job_runner.lua)
for /f "delims=" %%a in ('powershell -NoProfile -Command "[guid]::NewGuid().ToString()"') do set "JOB_UUID=%%a"

REM Create internals directory in APPDATA
set "INTERNALS_DIR=%APPDATA%\jobrunner\%JOB_UUID%"
mkdir "%INTERNALS_DIR%" 2>nul

REM Define file paths (matching job_runner.lua)
set "STATUS_FILE=%INTERNALS_DIR%\job_status.txt"
set "UUID_FILE=%INTERNALS_DIR%\job_uuid.txt"
set "PID_FILE=%INTERNALS_DIR%\job_pid.txt"
set "STDOUT_FILE=%INTERNALS_DIR%\stdout.txt"
set "STDERR_FILE=%INTERNALS_DIR%\stderr.txt"

REM Store UUID in file
echo %JOB_UUID%>"%UUID_FILE%"

echo ============================================================================
echo ASYNC JOB LAUNCHER
echo ============================================================================
echo Job Name: %JOB_NAME%
echo Job UUID: %JOB_UUID%
echo Command: %COMMAND%
echo Working Directory: %COMMAND_DIR%
echo Internals Directory: %INTERNALS_DIR%
echo.
echo Status File: %STATUS_FILE%
echo PID File: %PID_FILE%
echo Stdout File: %STDOUT_FILE%
echo Stderr File: %STDERR_FILE%
echo ============================================================================
echo.
echo Note: Ctrl+C in batch will prompt "Terminate batch job (Y/N)?". If you
echo       answer Y, the polling stops but the background job continues running.
echo       To stop a running job, use: job_async_stop.bat "%JOB_UUID%"
echo       Or run the stop command manually from the Internals Directory.
echo.
echo ============================================================================
echo LAUNCHING JOB...
echo ============================================================================
echo.

REM Build the background command (matching executor.run_cmd_job from executor.lua)
REM This uses start /min to launch in background, records PID, redirects output to files,
REM and writes status to file on completion

REM Get the directory where this script is located (to find create_job_async_run.ps1)
set "SCRIPT_DIR=%~dp0"

REM Define path for the generated launch script
set "LAUNCH_SCRIPT=%INTERNALS_DIR%\launch_job.bat"

REM Call the PowerShell script to generate the launch batch file
REM This avoids complex bat-to-bat escaping issues
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%create_job_async_run.ps1" -Command "%COMMAND%" -JobUUID "%JOB_UUID%" -StatusFile "%STATUS_FILE%" -PidFile "%PID_FILE%" -StdoutFile "%STDOUT_FILE%" -StderrFile "%STDERR_FILE%" -OutputBatFile "%LAUNCH_SCRIPT%"

start "%JOB_NAME%" /d "%COMMAND_DIR%" /min cmd.exe /c "%LAUNCH_SCRIPT%"

REM Give it a moment to start
timeout /t 1 /nobreak >nul 2>&1

echo Job launched. Beginning status polling...
echo.

REM Track last displayed content to avoid reprinting
set "LAST_STDOUT_LEN=0"
set "POLL_COUNT=0"

:POLL_LOOP
set /a POLL_COUNT+=1

REM Read current status from file
set "CURRENT_STATUS="
if exist "%STATUS_FILE%" (
    for /f "usebackq tokens=*" %%s in ("%STATUS_FILE%") do set "CURRENT_STATUS=%%s"
)

REM Display status header
echo ============================================================================
echo [Poll #%POLL_COUNT%] Status: [%CURRENT_STATUS%]
echo ============================================================================

REM Display current stdout
echo --- STDOUT ---
if exist "%STDOUT_FILE%" (
    type "%STDOUT_FILE%"
)
echo.

REM Display current stderr
echo --- STDERR ---
if exist "%STDERR_FILE%" (
    type "%STDERR_FILE%"
)
echo.

REM Check if job is finished using findstr for more robust matching
if exist "%STATUS_FILE%" (
    findstr /C:"SUCCESS" "%STATUS_FILE%" >nul 2>&1
    if not errorlevel 1 goto :JOB_COMPLETE
    findstr /C:"FAILURE" "%STATUS_FILE%" >nul 2>&1
    if not errorlevel 1 goto :JOB_COMPLETE
    findstr /C:"STOPPED" "%STATUS_FILE%" >nul 2>&1
    if not errorlevel 1 goto :JOB_COMPLETE
)

REM Wait 2 seconds before next poll
timeout /t 2 /nobreak >nul 2>&1

goto :POLL_LOOP

:JOB_COMPLETE
echo.
echo ============================================================================
echo JOB COMPLETED
echo ============================================================================
echo.

:FINAL_STATUS
echo ============================================================================
echo FINAL STATUS
echo ============================================================================
echo.

REM Read final status
set "FINAL_STATUS="
if exist "%STATUS_FILE%" (
    for /f "usebackq delims=" %%s in ("%STATUS_FILE%") do set "FINAL_STATUS=%%s"
)
echo Job Status: %FINAL_STATUS%
echo.

echo --- FINAL STDOUT ---
if exist "%STDOUT_FILE%" (
    type "%STDOUT_FILE%"
) else (
    echo [No stdout captured]
)
echo.

echo --- FINAL STDERR ---
if exist "%STDERR_FILE%" (
    type "%STDERR_FILE%"
) else (
    echo [No stderr captured]
)
echo.

echo ============================================================================
echo Session files located in: %INTERNALS_DIR%
echo ============================================================================

endlocal
exit /b 0