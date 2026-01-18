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

REM Define file paths
set "RUNNER_SCRIPT=%INTERNALS_DIR%\block_runner.bat"

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

REM Build and write the runner bat file
REM This mirrors the logic in executor.blocking_command() from executor.lua
REM Writing to a bat file allows manual inspection and troubleshooting
REM
REM The PowerShell command structure:
REM   1. Create ProcessStartInfo to launch cmd.exe with the command
REM   2. Configure output redirection and hidden window
REM   3. Start process and wait for completion
REM   4. Read stdout/stderr and display formatted results
REM   5. Check for SUCCESS/FAILURE designators to determine status
REM
REM We write the PowerShell script to a .ps1 file for cleaner escaping,
REM then create a .bat wrapper that calls it.

set "PS_SCRIPT=%INTERNALS_DIR%\block_runner.ps1"

REM Write the PowerShell script (no batch escaping issues)
REM Note: ^^ becomes ^ after echo processing, so ^^&^^& writes ^&^& to the file
>"%PS_SCRIPT%" (
echo $psi = New-Object System.Diagnostics.ProcessStartInfo
echo $psi.FileName = 'cmd.exe'
echo $psi.Arguments = '/c cd %COMMAND_DIR% ^^&^^& %COMMAND% ^^&^^& echo %SUCCESS_DESIGNATOR% ^^|^^| echo %FAILURE_DESIGNATOR%'
echo $psi.RedirectStandardOutput = $true
echo $psi.RedirectStandardError = $true
echo $psi.UseShellExecute = $false
echo $psi.CreateNoWindow = $true
echo $process = [System.Diagnostics.Process]::Start($psi^)
echo $process.WaitForExit(^)
echo $stdout = $process.StandardOutput.ReadToEnd(^)
echo $stderr = $process.StandardError.ReadToEnd(^)
echo $exitCode = $process.ExitCode
echo Write-Host ''
echo Write-Host '============================================================================'
echo Write-Host 'RESULT'
echo Write-Host '============================================================================'
echo if ($stdout -match '%SUCCESS_DESIGNATOR%'^) { Write-Host 'Status: SUCCESS' } else { Write-Host 'Status: FAILURE' }
echo Write-Host 'Exit Code:' $exitCode
echo Write-Host ''
echo Write-Host '============================================================================'
echo Write-Host 'STDOUT'
echo Write-Host '============================================================================'
echo $stdoutClean = $stdout -replace '%SUCCESS_DESIGNATOR%', '' -replace '%FAILURE_DESIGNATOR%', ''
echo Write-Host $stdoutClean
echo Write-Host ''
echo Write-Host '============================================================================'
echo Write-Host 'STDERR'
echo Write-Host '============================================================================'
echo Write-Host $stderr
echo Write-Host ''
)

REM Write the batch wrapper that calls the PowerShell script
>"%RUNNER_SCRIPT%" (
echo @echo off
echo powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%PS_SCRIPT%"
)

REM Execute the runner script
call "%RUNNER_SCRIPT%"

REM Clean up the temporary scripts
if exist "%RUNNER_SCRIPT%" del "%RUNNER_SCRIPT%"
if exist "%PS_SCRIPT%" del "%PS_SCRIPT%"
if exist "%INTERNALS_DIR%" rmdir "%INTERNALS_DIR%" 2>nul

echo.
echo ============================================================================
echo EXECUTION COMPLETE
echo ============================================================================

endlocal
