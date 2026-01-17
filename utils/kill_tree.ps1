# kill_tree.ps1
# PowerShell script to kill a process tree by PID, matching by UUID
# Usage: powershell -File kill_tree.ps1 -PID <process_id> -UUID <job_uuid>

param(
    [Parameter(Mandatory=$true)]
    [int]$ProcessId,
    
    [Parameter(Mandatory=$true)]
    [string]$MatchString
)

function Kill-Tree {
    param(
        [int]$ppid,
        [string]$matchString,
        [bool]$matchFound = $false
    )
    
    $process = Get-CimInstance Win32_Process | Where-Object { $_.ProcessId -eq $ppid }
    
    if (-not $process) {
        Write-Host "Process with PID $ppid not found."
        return
    }
    
    if (-not $matchFound -and $process.CommandLine -like "*$matchString*") {
        Write-Host "Match found for process PID $ppid and $matchString"
        $matchFound = $true
    } elseif (-not $matchFound) {
        Write-Host "No match for process PID $ppid and $matchString. Skipping."
    } else {
        Write-Host "Killing process PID $ppid"
        Stop-Process -Id $ppid -Force -ErrorAction SilentlyContinue
    }
    
    # Recursively kill child processes
    Get-CimInstance Win32_Process | Where-Object { $_.ParentProcessId -eq $ppid } | ForEach-Object {
        Kill-Tree -ppid $_.ProcessId -matchString $matchString -matchFound $matchFound
    }
}

# Start the kill tree from the given PID
Kill-Tree -ppid $ProcessId -matchString $MatchString
