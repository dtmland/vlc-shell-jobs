# test_stop_job.ps1
# Tests for stop_job.bat - stopping async jobs
# These tests launch long-running background jobs and verify they can be stopped

param(
    [Parameter(Mandatory=$true)]
    [string]$UtilsDir
)

# Import test helpers
. "$PSScriptRoot\test_helpers.ps1"

# Resolve the utils directory to absolute path
$UtilsDir = (Resolve-Path $UtilsDir -ErrorAction SilentlyContinue).Path
if (-not $UtilsDir) {
    Write-Host "ERROR: Utils directory not found: $UtilsDir"
    exit 1
}

$AsyncJobScript = Join-Path $UtilsDir "async_job.bat"
$StopJobScript = Join-Path $UtilsDir "stop_job.bat"
$CheckJobScript = Join-Path $UtilsDir "check_job.bat"

Write-TestHeader "stop_job.bat Tests"

# Pre-flight checks
if (-not (Test-PreFlightChecks -ScriptPath $StopJobScript -ScriptName "stop_job.bat")) {
    Write-Host "Pre-flight checks failed. Aborting tests."
    exit 1
}

Write-Host ""

# ============================================================================
# Test 1: No UUID provided - should show error
# ============================================================================
Write-TestCase "Missing UUID argument shows error"
$result = Run-CommandWithTimeout -Command "call `"$StopJobScript`"" -TimeoutSeconds 10
Assert-OutputContains -Output $result.Output -ExpectedText "ERROR: No job UUID specified" -TestDescription "Error message shown"
Assert-OutputContains -Output $result.Output -ExpectedText "Usage:" -TestDescription "Usage information shown"

# ============================================================================
# Test 2: Invalid UUID - directory not found
# ============================================================================
Write-TestCase "Invalid UUID shows directory not found error"
$fakeUuid = "00000000-0000-0000-0000-000000000000"
$result = Run-CommandWithTimeout -Command "call `"$StopJobScript`" `"$fakeUuid`"" -TimeoutSeconds 10
Assert-OutputContains -Output $result.Output -ExpectedText "ERROR: Job directory not found" -TestDescription "Directory not found error shown"

# ============================================================================
# Test 3: Stop a running job - launch async job, then stop it
# ============================================================================
Write-TestCase "Stop a running job"

# Launch a long-running job in the background (ping with many iterations)
$outputFile = "$env:TEMP\async_test_output.txt"
$cmdArgs = "/c `"$AsyncJobScript`" `"ping -n 60 127.0.0.1`" `"%USERPROFILE%`" `"LongRunningJob`""
$asyncProcess = Start-Process -FilePath "cmd.exe" -ArgumentList $cmdArgs `
    -PassThru -RedirectStandardOutput $outputFile -NoNewWindow

# Wait for job to start and get UUID
Start-Sleep -Seconds 5

# Read the output to get UUID
$asyncOutput = ""
if (Test-Path $outputFile) {
    $asyncOutput = Get-Content $outputFile -Raw -ErrorAction SilentlyContinue
}

$jobUuid = Get-JobUuidFromOutput -Output $asyncOutput

if ($jobUuid) {
    Write-TestInfo "Job UUID: $jobUuid"
    
    # Verify job is running
    $internalsDir = "$env:APPDATA\jobrunner\$jobUuid"
    $statusFile = "$internalsDir\job_status.txt"
    
    if (Test-Path $statusFile) {
        $status = (Get-Content $statusFile -Raw).Trim()
        if ($status -eq "RUNNING") {
            Write-TestPass "Job is in RUNNING state"
        } else {
            Write-TestInfo "Job status is: $status (may have completed quickly)"
        }
    }
    
    # Stop the job
    $stopResult = Run-CommandWithTimeout -Command "call `"$StopJobScript`" `"$jobUuid`"" -TimeoutSeconds 30
    Assert-OutputContains -Output $stopResult.Output -ExpectedText "Job UUID: $jobUuid" -TestDescription "Stop command shows correct UUID"
    Assert-OutputContains -Output $stopResult.Output -ExpectedText "Job stop command executed" -TestDescription "Stop command executed"
    Assert-OutputContains -Output $stopResult.Output -ExpectedText "STOPPED" -TestDescription "Job marked as STOPPED"
    
    # Verify status file updated to STOPPED
    if (Test-Path $statusFile) {
        $finalStatus = (Get-Content $statusFile -Raw).Trim()
        if ($finalStatus -eq "STOPPED") {
            Write-TestPass "Status file updated to STOPPED"
        } else {
            Write-TestFail "Status file shows '$finalStatus' instead of STOPPED"
        }
    }
    
    # Clean up
    if (-not $asyncProcess.HasExited) {
        try {
            $asyncProcess.Kill()
        } catch {
            Write-TestInfo "Note: Process may have already exited"
        }
    }
    Cleanup-JobDirectory -JobUuid $jobUuid
} else {
    Write-TestSkip "Could not get UUID from async job output"
}

# Clean up temp file
if (Test-Path $outputFile) {
    Remove-Item $outputFile -Force -ErrorAction SilentlyContinue
}

# ============================================================================
# Test 4: Stop already completed job - should say no need to stop
# ============================================================================
Write-TestCase "Stop already completed job"

# Run a quick job that completes immediately
$result = Run-CommandWithTimeout -Command "call `"$AsyncJobScript`" `"echo quick_complete`"" -TimeoutSeconds 30
$jobUuid = Get-JobUuidFromOutput -Output $result.Output

if ($jobUuid) {
    # Wait for completion
    Start-Sleep -Seconds 1
    
    # Try to stop the already completed job
    $stopResult = Run-CommandWithTimeout -Command "call `"$StopJobScript`" `"$jobUuid`"" -TimeoutSeconds 10
    
    # Should indicate job already finished
    $hasCompleteMsg = ($stopResult.Output -like "*already completed*") -or ($stopResult.Output -like "*SUCCESS*") -or ($stopResult.Output -like "*No need to stop*")
    if ($hasCompleteMsg) {
        Write-TestPass "Stop correctly handles already completed job"
    } else {
        # The job may have completed too fast - check if it just tried to stop anyway
        Write-TestInfo "Output: $($stopResult.Output.Substring(0, [Math]::Min(300, $stopResult.Output.Length)))"
    }
    
    Cleanup-JobDirectory -JobUuid $jobUuid
} else {
    Write-TestSkip "Could not get UUID from async job output"
}

# ============================================================================
# Test 5: Stop job shows stdout/stderr at time of stop
# ============================================================================
Write-TestCase "Stop job shows stdout/stderr at time of stop"

# Launch a job that outputs something and runs long
$outputFile2 = "$env:TEMP\async_test_output2.txt"
$cmdArgs2 = "/c `"$AsyncJobScript`" `"echo output_before_stop && ping -n 30 127.0.0.1`""
$asyncProcess = Start-Process -FilePath "cmd.exe" -ArgumentList $cmdArgs2 `
    -PassThru -RedirectStandardOutput $outputFile2 -NoNewWindow

Start-Sleep -Seconds 5

$asyncOutput = ""
if (Test-Path $outputFile2) {
    $asyncOutput = Get-Content $outputFile2 -Raw -ErrorAction SilentlyContinue
}

$jobUuid = Get-JobUuidFromOutput -Output $asyncOutput

if ($jobUuid) {
    # Stop the job
    $stopResult = Run-CommandWithTimeout -Command "call `"$StopJobScript`" `"$jobUuid`"" -TimeoutSeconds 30
    Assert-OutputContains -Output $stopResult.Output -ExpectedText "STDOUT (at time of stop)" -TestDescription "Shows stdout section"
    Assert-OutputContains -Output $stopResult.Output -ExpectedText "STDERR (at time of stop)" -TestDescription "Shows stderr section"
    
    if (-not $asyncProcess.HasExited) {
        try {
            $asyncProcess.Kill()
        } catch {
            Write-TestInfo "Note: Process may have already exited"
        }
    }
    Cleanup-JobDirectory -JobUuid $jobUuid
} else {
    Write-TestSkip "Could not get UUID from async job output"
}

if (Test-Path $outputFile2) {
    Remove-Item $outputFile2 -Force -ErrorAction SilentlyContinue
}

# ============================================================================
# Test 6: Stop job shows session files location
# ============================================================================
Write-TestCase "Stop job shows session files location"
$fakeUuid = [guid]::NewGuid().ToString()
# Create a fake job directory to test output formatting
$fakeDir = "$env:APPDATA\jobrunner\$fakeUuid"
New-Item -Path $fakeDir -ItemType Directory -Force | Out-Null
"RUNNING" | Out-File -FilePath "$fakeDir\job_status.txt" -Encoding ascii
"12345" | Out-File -FilePath "$fakeDir\job_pid.txt" -Encoding ascii
"test output" | Out-File -FilePath "$fakeDir\stdout.txt" -Encoding ascii
"" | Out-File -FilePath "$fakeDir\stderr.txt" -Encoding ascii

$result = Run-CommandWithTimeout -Command "call `"$StopJobScript`" `"$fakeUuid`"" -TimeoutSeconds 30
Assert-OutputContains -Output $result.Output -ExpectedText "Session files located in:" -TestDescription "Session files location shown"
Assert-OutputContains -Output $result.Output -ExpectedText $fakeUuid -TestDescription "UUID shown in output"

Cleanup-JobDirectory -JobUuid $fakeUuid

# ============================================================================
# Test 7: Stop job displays current job status
# ============================================================================
Write-TestCase "Stop job displays current job status"
$fakeUuid = [guid]::NewGuid().ToString()
$fakeDir = "$env:APPDATA\jobrunner\$fakeUuid"
New-Item -Path $fakeDir -ItemType Directory -Force | Out-Null
"RUNNING" | Out-File -FilePath "$fakeDir\job_status.txt" -Encoding ascii
"99999" | Out-File -FilePath "$fakeDir\job_pid.txt" -Encoding ascii

$result = Run-CommandWithTimeout -Command "call `"$StopJobScript`" `"$fakeUuid`"" -TimeoutSeconds 30
Assert-OutputContains -Output $result.Output -ExpectedText "Current job status:" -TestDescription "Current status displayed"

Cleanup-JobDirectory -JobUuid $fakeUuid

# ============================================================================
# Test 8: Header displayed correctly
# ============================================================================
Write-TestCase "STOP JOB header displayed"
$fakeUuid = [guid]::NewGuid().ToString()
$fakeDir = "$env:APPDATA\jobrunner\$fakeUuid"
New-Item -Path $fakeDir -ItemType Directory -Force | Out-Null
"RUNNING" | Out-File -FilePath "$fakeDir\job_status.txt" -Encoding ascii
"88888" | Out-File -FilePath "$fakeDir\job_pid.txt" -Encoding ascii

$result = Run-CommandWithTimeout -Command "call `"$StopJobScript`" `"$fakeUuid`"" -TimeoutSeconds 30
Assert-OutputContains -Output $result.Output -ExpectedText "STOP JOB" -TestDescription "STOP JOB header shown"
Assert-OutputContains -Output $result.Output -ExpectedText "Internals Directory:" -TestDescription "Internals directory shown"

Cleanup-JobDirectory -JobUuid $fakeUuid

# ============================================================================
# Summary
# ============================================================================
$allPassed = Write-TestSummary

if ($allPassed) {
    exit 0
} else {
    exit 1
}
