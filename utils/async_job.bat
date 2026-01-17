@echo off
REM ============================================================================
REM async_job.bat
REM 
REM Purpose: Run a command asynchronously in the background, poll for status,
REM          display ongoing output, and handle Ctrl+C for graceful shutdown.
REM
REM Usage: async_job.bat "command" ["working_directory"] ["job_name"]
REM
REM Arguments:
REM   command           - The command to execute (required)
REM   working_directory - Directory to run command from (optional, defaults to %USERPROFILE%)
REM   job_name          - Display name for the job (optional, defaults to "AsyncJob")
REM
REM Example:
REM   async_job.bat "ping -n 10 localhost"
REM   async_job.bat "ping -n 10 localhost" "C:\Windows" "PingTest"
REM
REM This batch file replicates the async job runner from executor.lua and job_runner.lua
REM ============================================================================

setlocal EnableDelayedExpansion

REM Check for command argument
if "%~1"=="" (
    echo ERROR: No command specified
    echo Usage: async_job.bat "command" ["working_directory"] ["job_name"]
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
echo Note: To stop a running job, press Ctrl+C. The job will be terminated
echo       and you can check the status files in the Internals Directory.
echo.
echo ============================================================================
echo LAUNCHING JOB...
echo ============================================================================
echo.

REM Build the background command (matching executor.run_cmd_job from executor.lua)
REM This uses start /min to launch in background, records PID, redirects output to files,
REM and writes status to file on completion

REM Note: In the PowerShell command below, $PID is PowerShell's automatic variable for
REM the current process ID. We get its ParentProcessId to find the cmd.exe process.
REM The quoting is complex due to nested cmd.exe and powershell invocations.

REM Write the job launch script to a temporary file to avoid escaping issues
set "LAUNCH_SCRIPT=%INTERNALS_DIR%\launch_job.cmd"
echo @echo off > "%LAUNCH_SCRIPT%"
echo echo RUNNING ^> "%STATUS_FILE%" >> "%LAUNCH_SCRIPT%"
echo echo %JOB_UUID% ^>NUL >> "%LAUNCH_SCRIPT%"
echo powershell -NoProfile -ExecutionPolicy Bypass -Command "(Get-CimInstance Win32_Process -Filter 'ProcessId=$PID').ParentProcessId" ^> "%PID_FILE%" >> "%LAUNCH_SCRIPT%"
echo %COMMAND% 2^> "%STDERR_FILE%" ^> "%STDOUT_FILE%" >> "%LAUNCH_SCRIPT%"
echo if errorlevel 1 (echo FAILURE ^> "%STATUS_FILE%") else (echo SUCCESS ^> "%STATUS_FILE%") >> "%LAUNCH_SCRIPT%"

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

REM Read current status
set "CURRENT_STATUS="
if exist "%STATUS_FILE%" (
    for /f "usebackq delims=" %%s in ("%STATUS_FILE%") do set "CURRENT_STATUS=%%s"
)

REM Display status header
echo ============================================================================
echo [Poll #%POLL_COUNT%] Status: %CURRENT_STATUS%
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

REM Check if job is finished
if "%CURRENT_STATUS%"=="SUCCESS" goto :JOB_COMPLETE
if "%CURRENT_STATUS%"=="FAILURE" goto :JOB_COMPLETE

REM Wait 2 seconds before next poll
REM Note: timeout may return errorlevel 1 on Ctrl+C, but we only handle
REM Ctrl+C manually if job is still running. If status is already FAILURE,
REM we should go to JOB_COMPLETE instead.
timeout /t 2 /nobreak >nul 2>&1

goto :POLL_LOOP

:CTRL_C_HANDLER
echo.
echo ============================================================================
echo Ctrl+C detected! Stopping job...
echo ============================================================================
echo.

REM Read PID from file
set "JOB_PID="
if exist "%PID_FILE%" (
    for /f "usebackq delims=" %%p in ("%PID_FILE%") do set "JOB_PID=%%p"
)

if "%JOB_PID%"=="" (
    echo WARNING: Could not find PID to stop the job
    goto :FINAL_STATUS
)

echo Attempting to stop job with PID: %JOB_PID%
echo Job UUID: %JOB_UUID%
echo.

REM Stop the job using the Kill-Tree function from executor.stop_job
REM This walks the process tree and kills matching processes
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
"function Kill-Tree { ^
    param([int] $ppid, [string] $matchString, [bool] $matchFound = $false); ^
    $process = Get-CimInstance Win32_Process | Where-Object { $_.ProcessId -eq $ppid }; ^
    if (-not $process) { Write-Host 'Process with PID' $ppid 'not found.'; return }; ^
    if (-not $matchFound -and $process.CommandLine -like \"*$matchString*\") { ^
        Write-Host 'Match found for process PID' $ppid 'and' $matchString; ^
        $matchFound = $true ^
    } elseif (-not $matchFound) { ^
        Write-Host 'No match for process PID' $ppid 'and' $matchString '. Skipping.'; ^
    } else { ^
        Write-Host 'Killing process PID' $ppid; ^
        if ($matchFound) { Stop-Process -Id $ppid -Force -ErrorAction SilentlyContinue } ^
    }; ^
    Get-CimInstance Win32_Process | Where-Object { $_.ParentProcessId -eq $ppid } | ForEach-Object { Kill-Tree -ppid $_.ProcessId -matchString $matchString -matchFound $matchFound } ^
}; ^
Kill-Tree -ppid %JOB_PID% -matchString '%JOB_UUID%'"

echo.
echo Job stop command executed.
goto :FINAL_STATUS

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

REM Clean up the temporary launch script
if exist "%LAUNCH_SCRIPT%" del "%LAUNCH_SCRIPT%"

endlocal
exit /b 0
