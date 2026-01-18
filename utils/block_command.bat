@echo off
REM ============================================================================
REM block_command.bat
REM 
REM Purpose: Run a command synchronously (blocking) and capture stdout/stderr
REM          separately using PowerShell's ProcessStartInfo.
REM
REM Usage: block_command.bat "command" ["working_directory"]
REM
REM Arguments:
REM   command           - The command to execute (required)
REM   working_directory - Directory to run command from (optional, defaults to %USERPROFILE%)
REM
REM Example:
REM   block_command.bat "ping -n 3 localhost"
REM   block_command.bat "dir /b" "C:\Windows"
REM   block_command.bat "ping -n 3 localhost && echo done"
REM
REM This batch file replicates the blocking_command function from executor.lua
REM ============================================================================

setlocal EnableDelayedExpansion

REM Check for command argument
if "%~1"=="" (
    echo ERROR: No command specified
    echo Usage: block_command.bat "command" ["working_directory"]
    exit /b 1
)

set "COMMAND=%~1"
set "COMMAND_DIR=%~2"

REM Default working directory to USERPROFILE if not specified
if "%COMMAND_DIR%"=="" (
    set "COMMAND_DIR=%USERPROFILE%"
)

REM Generate a UUID for this run (for unique temp directory)
for /f "delims=" %%a in ('powershell -NoProfile -Command "[guid]::NewGuid().ToString()"') do set "RUN_UUID=%%a"

REM Create internals directory for this run
set "INTERNALS_DIR=%APPDATA%\jobrunner\block_%RUN_UUID%"
mkdir "%INTERNALS_DIR%" 2>nul

REM Define file path for the generated runner script
set "RUNNER_SCRIPT=%INTERNALS_DIR%\block_runner.bat"

REM Get the directory where this script is located (to find create_block_command.ps1)
set "SCRIPT_DIR=%~dp0"

echo ============================================================================
echo BLOCK COMMAND EXECUTOR
echo ============================================================================
echo Command: %COMMAND%
echo Working Directory: %COMMAND_DIR%
echo Runner Script: %RUNNER_SCRIPT%
echo ============================================================================
echo.

REM Define exit code designators (matching executor.lua)
set "SUCCESS_DESIGNATOR=EXITCODE:SUCCESS"
set "FAILURE_DESIGNATOR=EXITCODE:FAILURE"

REM Call the PowerShell script to generate the runner batch file
REM This avoids complex bat-to-bat escaping issues
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%create_block_command.ps1" -Command "%COMMAND%" -CommandDir "%COMMAND_DIR%" -OutputBatFile "%RUNNER_SCRIPT%" -SuccessDesignator "%SUCCESS_DESIGNATOR%" -FailureDesignator "%FAILURE_DESIGNATOR%"

REM Execute the generated runner script
call "%RUNNER_SCRIPT%"

echo.
echo ============================================================================
echo EXECUTION COMPLETE
echo ============================================================================

endlocal
