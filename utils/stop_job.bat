@echo off
REM ============================================================================
REM stop_job.bat
REM 
REM Purpose: Stop a running async job by its UUID
REM
REM Usage: stop_job.bat "job_uuid"
REM
REM Arguments:
REM   job_uuid - The UUID of the job to stop (required)
REM
REM Example:
REM   stop_job.bat "78f734c4-496c-40d0-83f4-127d43e97195"
REM
REM This batch file replicates the stop_job function from executor.lua
REM ============================================================================

setlocal EnableDelayedExpansion

REM Check for UUID argument
if "%~1"=="" (
    echo ERROR: No job UUID specified
    echo Usage: stop_job.bat "job_uuid"
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

REM Create a temporary bat file for the kill tree command
REM This mirrors the one_liner pattern in executor.stop_job() from executor.lua
set "KILL_SCRIPT=%INTERNALS_DIR%\kill_tree_runner.bat"

REM Build the kill tree PowerShell command as a bat file
REM This matches the inline Kill-Tree function from executor.lua
REM
REM The Kill-Tree function (written as one line to match the lua one_liner pattern):
REM   1. Define Kill-Tree function with parameters: ppid, matchString, matchFound
REM   2. Get process by PID from Win32_Process
REM   3. If process not found, log and return
REM   4. If matchString found in CommandLine, set matchFound=true
REM   5. If matchFound, kill the process; otherwise skip
REM   6. Recursively call Kill-Tree for all child processes
REM   7. Finally invoke Kill-Tree with the job PID and UUID
REM
REM Note: The ^^| escaping produces ^| in the output file,
REM       which cmd.exe interprets correctly when running the generated bat file.
echo @echo off>"%KILL_SCRIPT%"
echo powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command "function Kill-Tree { param([int] $ppid, [string] $matchString, [bool] $matchFound = $false); $process = Get-CimInstance Win32_Process ^^| Where-Object { $_.ProcessId -eq $ppid }; if (-not $process) { Write-Host 'Process with PID' $ppid 'not found.'; return }; if (-not $matchFound -and $process.CommandLine -like '*'+$matchString+'*') { Write-Host 'Match found for process PID' $ppid 'and' $matchString; $matchFound = $true } elseif (-not $matchFound) { Write-Host 'No match for process PID' $ppid 'and' $matchString '. Skipping.' } else { Write-Host 'Killing process PID' $ppid; if ($matchFound) { Stop-Process -Id $ppid -Force -ErrorAction SilentlyContinue } }; Get-CimInstance Win32_Process ^^| Where-Object { $_.ParentProcessId -eq $ppid } ^^| ForEach-Object { Kill-Tree -ppid $_.ProcessId -matchString $matchString -matchFound $matchFound } }; Kill-Tree -ppid %JOB_PID% -matchString '%JOB_UUID%'">>"%KILL_SCRIPT%"

REM Execute the kill script
call "%KILL_SCRIPT%"

REM Clean up the temporary script
if exist "%KILL_SCRIPT%" del "%KILL_SCRIPT%"

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
