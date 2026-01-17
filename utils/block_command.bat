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

echo ============================================================================
echo BLOCK COMMAND EXECUTOR
echo ============================================================================
echo Command: %COMMAND%
echo Working Directory: %COMMAND_DIR%
echo ============================================================================
echo.

REM Define exit code designators (matching executor.lua)
set "SUCCESS_DESIGNATOR=EXITCODE:SUCCESS"
set "FAILURE_DESIGNATOR=EXITCODE:FAILURE"

REM Build and execute the PowerShell command
REM This mirrors the logic in executor.blocking_command() from executor.lua
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
"$psi = New-Object System.Diagnostics.ProcessStartInfo; ^
$psi.FileName = 'cmd.exe'; ^
$psi.Arguments = '/c cd %COMMAND_DIR% ^&^& %COMMAND% ^&^& echo %SUCCESS_DESIGNATOR% ^|^| echo %FAILURE_DESIGNATOR%'; ^
$psi.RedirectStandardOutput = $true; ^
$psi.RedirectStandardError = $true; ^
$psi.UseShellExecute = $false; ^
$psi.CreateNoWindow = $true; ^
$process = [System.Diagnostics.Process]::Start($psi); ^
$process.WaitForExit(); ^
$stdout = $process.StandardOutput.ReadToEnd(); ^
$stderr = $process.StandardError.ReadToEnd(); ^
$exitCode = $process.ExitCode; ^
Write-Host ''; ^
Write-Host '============================================================================'; ^
Write-Host 'RESULT'; ^
Write-Host '============================================================================'; ^
if ($stdout -match '%SUCCESS_DESIGNATOR%') { ^
    Write-Host 'Status: SUCCESS'; ^
} else { ^
    Write-Host 'Status: FAILURE'; ^
} ^
Write-Host 'Exit Code:' $exitCode; ^
Write-Host ''; ^
Write-Host '============================================================================'; ^
Write-Host 'STDOUT'; ^
Write-Host '============================================================================'; ^
$stdoutClean = $stdout -replace '%SUCCESS_DESIGNATOR%', '' -replace '%FAILURE_DESIGNATOR%', ''; ^
Write-Host $stdoutClean; ^
Write-Host ''; ^
Write-Host '============================================================================'; ^
Write-Host 'STDERR'; ^
Write-Host '============================================================================'; ^
Write-Host $stderr; ^
Write-Host ''"

echo.
echo ============================================================================
echo EXECUTION COMPLETE
echo ============================================================================

endlocal
