# create_async_job.ps1
# PowerShell script that generates the launch_job.bat file for troubleshooting
# This avoids complex batch escaping by writing batch from PowerShell

param(
    [Parameter(Mandatory=$true)]
    [string]$Command,
    
    [Parameter(Mandatory=$true)]
    [string]$JobUUID,
    
    [Parameter(Mandatory=$true)]
    [string]$StatusFile,
    
    [Parameter(Mandatory=$true)]
    [string]$PidFile,
    
    [Parameter(Mandatory=$true)]
    [string]$StdoutFile,
    
    [Parameter(Mandatory=$true)]
    [string]$StderrFile,
    
    [Parameter(Mandatory=$true)]
    [string]$OutputBatFile
)

# Build the batch file content
# This matches the pattern from executor.run_cmd_job in executor.lua
$batContent = @"
@echo off
REM Generated batch file for async job execution
REM This file can be run manually for troubleshooting
REM Job UUID: $JobUUID
REM Command: $Command

REM Set status to RUNNING
echo RUNNING>"$StatusFile"

REM Echo UUID (for matching in process tree)
echo $JobUUID >NUL

REM Get the parent process ID and write to PID file
powershell -NoProfile -ExecutionPolicy Bypass -Command "(Get-CimInstance Win32_Process -Filter \"ProcessId=`$PID\").ParentProcessId" >"$PidFile" 2>&1

REM Execute the command with output redirection
$Command 2>"$StderrFile" >"$StdoutFile"

REM Check exit code and update status
if errorlevel 1 (echo FAILURE>"$StatusFile") else (echo SUCCESS>"$StatusFile")
"@

# Write to file
Set-Content -Path $OutputBatFile -Value $batContent -Encoding ASCII

# Return the path for confirmation
Write-Output $OutputBatFile
