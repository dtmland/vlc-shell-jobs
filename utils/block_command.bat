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

REM Define file paths for troubleshooting scripts
set "RUNNER_SCRIPT=%INTERNALS_DIR%\block_runner.bat"
set "PS_SCRIPT=%INTERNALS_DIR%\block_runner.ps1"

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

REM Write the PowerShell script to a file for troubleshooting
REM Note: This file is kept for inspection if there are issues
echo $psi = New-Object System.Diagnostics.ProcessStartInfo>"%PS_SCRIPT%"
echo $psi.FileName = 'cmd.exe'>>"%PS_SCRIPT%"
echo $psi.Arguments = '/c cd %COMMAND_DIR% ^^&^^& %COMMAND% ^^&^^& echo %SUCCESS_DESIGNATOR% ^^|^^| echo %FAILURE_DESIGNATOR%'>>"%PS_SCRIPT%"
echo $psi.RedirectStandardOutput = $true>>"%PS_SCRIPT%"
echo $psi.RedirectStandardError = $true>>"%PS_SCRIPT%"
echo $psi.UseShellExecute = $false>>"%PS_SCRIPT%"
echo $psi.CreateNoWindow = $true>>"%PS_SCRIPT%"
echo $process = [System.Diagnostics.Process]::Start($psi)>>"%PS_SCRIPT%"
echo $process.WaitForExit()>>"%PS_SCRIPT%"
echo $stdout = $process.StandardOutput.ReadToEnd()>>"%PS_SCRIPT%"
echo $stderr = $process.StandardError.ReadToEnd()>>"%PS_SCRIPT%"
echo $exitCode = $process.ExitCode>>"%PS_SCRIPT%"
echo Write-Host ''>>"%PS_SCRIPT%"
echo Write-Host '============================================================================'>>"%PS_SCRIPT%"
echo Write-Host 'RESULT'>>"%PS_SCRIPT%"
echo Write-Host '============================================================================'>>"%PS_SCRIPT%"
echo if ($stdout -match '%SUCCESS_DESIGNATOR%') { Write-Host 'Status: SUCCESS' } else { Write-Host 'Status: FAILURE' }>>"%PS_SCRIPT%"
echo Write-Host 'Exit Code:' $exitCode>>"%PS_SCRIPT%"
echo Write-Host ''>>"%PS_SCRIPT%"
echo Write-Host '============================================================================'>>"%PS_SCRIPT%"
echo Write-Host 'STDOUT'>>"%PS_SCRIPT%"
echo Write-Host '============================================================================'>>"%PS_SCRIPT%"
echo $stdoutClean = $stdout -replace '%SUCCESS_DESIGNATOR%', '' -replace '%FAILURE_DESIGNATOR%', ''>>"%PS_SCRIPT%"
echo Write-Host $stdoutClean>>"%PS_SCRIPT%"
echo Write-Host ''>>"%PS_SCRIPT%"
echo Write-Host '============================================================================'>>"%PS_SCRIPT%"
echo Write-Host 'STDERR'>>"%PS_SCRIPT%"
echo Write-Host '============================================================================'>>"%PS_SCRIPT%"
echo Write-Host $stderr>>"%PS_SCRIPT%"
echo Write-Host ''>>"%PS_SCRIPT%"

REM Write the batch wrapper for troubleshooting
echo @echo off>"%RUNNER_SCRIPT%"
echo powershell -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%">>"%RUNNER_SCRIPT%"

REM Execute the PowerShell script directly (more reliable than calling the wrapper)
powershell -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%"

REM Clean up the temporary scripts
if exist "%RUNNER_SCRIPT%" del "%RUNNER_SCRIPT%"
if exist "%PS_SCRIPT%" del "%PS_SCRIPT%"
if exist "%INTERNALS_DIR%" rmdir "%INTERNALS_DIR%" 2>nul

echo.
echo ============================================================================
echo EXECUTION COMPLETE
echo ============================================================================

endlocal
