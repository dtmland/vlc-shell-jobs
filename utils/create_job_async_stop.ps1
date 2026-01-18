# create_job_async_stop.ps1
# PowerShell script that generates the kill_tree_runner.bat file for troubleshooting
# This avoids complex batch escaping by writing batch from PowerShell

param(
    [Parameter(Mandatory=$true)]
    [int]$JobPID,
    
    [Parameter(Mandatory=$true)]
    [string]$JobUUID,
    
    [Parameter(Mandatory=$true)]
    [string]$OutputBatFile
)

# Build the PowerShell one-liner that matches shell_execute.lua's stop_job Kill-Tree function
# Option 2: Define clean script, then collapse
$innerScript = @"
function Kill-Tree {
    param([int] `$ppid, [string] `$matchString, [bool] `$matchFound = `$false);
    `$process = Get-CimInstance Win32_Process | Where-Object { `$_.ProcessId -eq `$ppid };
    if (-not `$process) {
        Write-Host 'Process with PID' `$ppid 'not found.';
        return
    };
    if (-not `$matchFound -and `$process.CommandLine -like '*'+`$matchString+'*') {
        Write-Host 'Match found for process PID' `$ppid 'and' `$matchString;
        `$matchFound = `$true
    } elseif (-not `$matchFound) {
        Write-Host 'No match for process PID' `$ppid 'and' `$matchString '. Skipping.'
    } else {
        Write-Host 'Killing process PID' `$ppid;
        Stop-Process -Id `$ppid -Force -ErrorAction SilentlyContinue
    };
    Get-CimInstance Win32_Process | Where-Object { `$_.ParentProcessId -eq `$ppid } | ForEach-Object {
        Kill-Tree -ppid `$_.ProcessId -matchString `$matchString -matchFound `$matchFound
    }
};
Kill-Tree -ppid $JobPID -matchString '$JobUUID'
"@

# Collapse newlines to spaces for the single-line batch argument
$flatScript = $innerScript -replace "`r`n", " " -replace "`n", " "
$psOneLiner = "powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command ""$flatScript"""

# Write the batch file
$batContent = @"
@echo off
REM Generated batch file for kill_tree execution
REM This file can be run manually for troubleshooting
REM Job PID: $JobPID
REM Job UUID: $JobUUID

$psOneLiner
"@

# Write to file
Set-Content -Path $OutputBatFile -Value $batContent -Encoding ASCII

# Return the path for confirmation
Write-Output $OutputBatFile