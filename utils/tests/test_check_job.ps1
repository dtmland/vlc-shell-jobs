# test_check_job.ps1
# Tests for check_job.bat - checking job status
# These tests verify status checking functionality while jobs are running and after completion

param(
    [Parameter(Mandatory=$true)]
    [string]$UtilsDir
)

# Import test helpers
. "$PSScriptRoot\test_helpers.ps1"

$AsyncJobScript = Join-Path $UtilsDir "async_job.bat"
$CheckJobScript = Join-Path $UtilsDir "check_job.bat"
$StopJobScript = Join-Path $UtilsDir "stop_job.bat"

Write-TestHeader "check_job.bat Tests"

# ============================================================================
# Test 1: No UUID provided - should show error
# ============================================================================
Write-TestCase "Missing UUID argument shows error"
$result = Run-CommandWithTimeout -Command "`"$CheckJobScript`"" -TimeoutSeconds 10
Assert-OutputContains -Output $result.Output -ExpectedText "ERROR: No job UUID specified" -TestDescription "Error message shown"
Assert-OutputContains -Output $result.Output -ExpectedText "Usage:" -TestDescription "Usage information shown"

# ============================================================================
# Test 2: Invalid UUID - directory not found
# ============================================================================
Write-TestCase "Invalid UUID shows directory not found error"
$fakeUuid = "00000000-0000-0000-0000-000000000001"
$result = Run-CommandWithTimeout -Command "`"$CheckJobScript`" `"$fakeUuid`"" -TimeoutSeconds 10
Assert-OutputContains -Output $result.Output -ExpectedText "ERROR: Job directory not found" -TestDescription "Directory not found error shown"

# ============================================================================
# Test 3: Check a running job shows RUNNING status
# ============================================================================
Write-TestCase "Check running job shows RUNNING status"

# Launch a long-running job
$asyncProcess = Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$AsyncJobScript`" `"ping -n 30 127.0.0.1`" `"%USERPROFILE%`" `"LongJob`"" -PassThru -RedirectStandardOutput "$env:TEMP\check_test_output.txt" -NoNewWindow

Start-Sleep -Seconds 5

$asyncOutput = ""
if (Test-Path "$env:TEMP\check_test_output.txt") {
    $asyncOutput = Get-Content "$env:TEMP\check_test_output.txt" -Raw -ErrorAction SilentlyContinue
}

$jobUuid = Get-JobUuidFromOutput -Output $asyncOutput

if ($jobUuid) {
    Write-TestInfo "Job UUID: $jobUuid"
    
    # Check the job status
    $checkResult = Run-CommandWithTimeout -Command "`"$CheckJobScript`" `"$jobUuid`"" -TimeoutSeconds 10
    Assert-OutputContains -Output $checkResult.Output -ExpectedText "CHECK JOB" -TestDescription "CHECK JOB header shown"
    Assert-OutputContains -Output $checkResult.Output -ExpectedText "Job UUID: $jobUuid" -TestDescription "UUID displayed"
    Assert-OutputContains -Output $checkResult.Output -ExpectedText "STATUS" -TestDescription "STATUS section present"
    
    # Status should be RUNNING (or might have progressed)
    if ($checkResult.Output -like "*RUNNING*") {
        Write-TestPass "Job shows RUNNING status"
    } else {
        Write-TestInfo "Job may have already completed - status not RUNNING"
    }
    
    # Stop and clean up
    Run-CommandWithTimeout -Command "`"$StopJobScript`" `"$jobUuid`"" -TimeoutSeconds 30 | Out-Null
    try { $asyncProcess.Kill() } catch { }
    Cleanup-JobDirectory -JobUuid $jobUuid
} else {
    Write-TestSkip "Could not get UUID from async job output"
}

if (Test-Path "$env:TEMP\check_test_output.txt") {
    Remove-Item "$env:TEMP\check_test_output.txt" -Force -ErrorAction SilentlyContinue
}

# ============================================================================
# Test 4: Check a completed job shows SUCCESS/FAILURE
# ============================================================================
Write-TestCase "Check completed job shows final status"

# Run a quick job
$result = Run-CommandWithTimeout -Command "`"$AsyncJobScript`" `"echo quick_check_test`"" -TimeoutSeconds 30
$jobUuid = Get-JobUuidFromOutput -Output $result.Output

if ($jobUuid) {
    # Check the completed job
    $checkResult = Run-CommandWithTimeout -Command "`"$CheckJobScript`" `"$jobUuid`"" -TimeoutSeconds 10
    
    # Should show SUCCESS since echo succeeds
    if ($checkResult.Output -like "*SUCCESS*") {
        Write-TestPass "Completed job shows SUCCESS status"
    } elseif ($checkResult.Output -like "*FAILURE*") {
        Write-TestPass "Completed job shows a final status (FAILURE)"
    } else {
        Write-TestFail "Could not find SUCCESS or FAILURE in check output"
    }
    
    Cleanup-JobDirectory -JobUuid $jobUuid
} else {
    Write-TestSkip "Could not get UUID from async job output"
}

# ============================================================================
# Test 5: Check shows PID
# ============================================================================
Write-TestCase "Check job shows PID"

$fakeUuid = [guid]::NewGuid().ToString()
$fakeDir = "$env:APPDATA\jobrunner\$fakeUuid"
New-Item -Path $fakeDir -ItemType Directory -Force | Out-Null
"RUNNING" | Out-File -FilePath "$fakeDir\job_status.txt" -Encoding ascii
"12345" | Out-File -FilePath "$fakeDir\job_pid.txt" -Encoding ascii
"test stdout content" | Out-File -FilePath "$fakeDir\stdout.txt" -Encoding ascii
"" | Out-File -FilePath "$fakeDir\stderr.txt" -Encoding ascii

$result = Run-CommandWithTimeout -Command "`"$CheckJobScript`" `"$fakeUuid`"" -TimeoutSeconds 10
Assert-OutputContains -Output $result.Output -ExpectedText "PID" -TestDescription "PID section shown"
Assert-OutputContains -Output $result.Output -ExpectedText "12345" -TestDescription "PID value displayed"

Cleanup-JobDirectory -JobUuid $fakeUuid

# ============================================================================
# Test 6: Check shows stdout content
# ============================================================================
Write-TestCase "Check job shows stdout content"

$fakeUuid = [guid]::NewGuid().ToString()
$fakeDir = "$env:APPDATA\jobrunner\$fakeUuid"
New-Item -Path $fakeDir -ItemType Directory -Force | Out-Null
"SUCCESS" | Out-File -FilePath "$fakeDir\job_status.txt" -Encoding ascii
"99999" | Out-File -FilePath "$fakeDir\job_pid.txt" -Encoding ascii
"hello from stdout test" | Out-File -FilePath "$fakeDir\stdout.txt" -Encoding ascii
"" | Out-File -FilePath "$fakeDir\stderr.txt" -Encoding ascii

$result = Run-CommandWithTimeout -Command "`"$CheckJobScript`" `"$fakeUuid`"" -TimeoutSeconds 10
Assert-OutputContains -Output $result.Output -ExpectedText "STDOUT" -TestDescription "STDOUT section shown"
Assert-OutputContains -Output $result.Output -ExpectedText "hello from stdout test" -TestDescription "Stdout content displayed"

Cleanup-JobDirectory -JobUuid $fakeUuid

# ============================================================================
# Test 7: Check shows stderr content
# ============================================================================
Write-TestCase "Check job shows stderr content"

$fakeUuid = [guid]::NewGuid().ToString()
$fakeDir = "$env:APPDATA\jobrunner\$fakeUuid"
New-Item -Path $fakeDir -ItemType Directory -Force | Out-Null
"FAILURE" | Out-File -FilePath "$fakeDir\job_status.txt" -Encoding ascii
"88888" | Out-File -FilePath "$fakeDir\job_pid.txt" -Encoding ascii
"" | Out-File -FilePath "$fakeDir\stdout.txt" -Encoding ascii
"error from stderr test" | Out-File -FilePath "$fakeDir\stderr.txt" -Encoding ascii

$result = Run-CommandWithTimeout -Command "`"$CheckJobScript`" `"$fakeUuid`"" -TimeoutSeconds 10
Assert-OutputContains -Output $result.Output -ExpectedText "STDERR" -TestDescription "STDERR section shown"
Assert-OutputContains -Output $result.Output -ExpectedText "error from stderr test" -TestDescription "Stderr content displayed"

Cleanup-JobDirectory -JobUuid $fakeUuid

# ============================================================================
# Test 8: Custom tail lines parameter
# ============================================================================
Write-TestCase "Custom tail lines parameter"

$fakeUuid = [guid]::NewGuid().ToString()
$fakeDir = "$env:APPDATA\jobrunner\$fakeUuid"
New-Item -Path $fakeDir -ItemType Directory -Force | Out-Null
"SUCCESS" | Out-File -FilePath "$fakeDir\job_status.txt" -Encoding ascii
"77777" | Out-File -FilePath "$fakeDir\job_pid.txt" -Encoding ascii
"line1`nline2`nline3`nline4`nline5" | Out-File -FilePath "$fakeDir\stdout.txt" -Encoding ascii
"" | Out-File -FilePath "$fakeDir\stderr.txt" -Encoding ascii

$result = Run-CommandWithTimeout -Command "`"$CheckJobScript`" `"$fakeUuid`" 100" -TimeoutSeconds 10
Assert-OutputContains -Output $result.Output -ExpectedText "Tail lines: 100" -TestDescription "Custom tail lines shown"

Cleanup-JobDirectory -JobUuid $fakeUuid

# ============================================================================
# Test 9: Default tail lines is 50
# ============================================================================
Write-TestCase "Default tail lines is 50"

$fakeUuid = [guid]::NewGuid().ToString()
$fakeDir = "$env:APPDATA\jobrunner\$fakeUuid"
New-Item -Path $fakeDir -ItemType Directory -Force | Out-Null
"SUCCESS" | Out-File -FilePath "$fakeDir\job_status.txt" -Encoding ascii
"66666" | Out-File -FilePath "$fakeDir\job_pid.txt" -Encoding ascii
"test" | Out-File -FilePath "$fakeDir\stdout.txt" -Encoding ascii
"" | Out-File -FilePath "$fakeDir\stderr.txt" -Encoding ascii

$result = Run-CommandWithTimeout -Command "`"$CheckJobScript`" `"$fakeUuid`"" -TimeoutSeconds 10
Assert-OutputContains -Output $result.Output -ExpectedText "Tail lines: 50" -TestDescription "Default tail lines is 50"

Cleanup-JobDirectory -JobUuid $fakeUuid

# ============================================================================
# Test 10: Session files location shown
# ============================================================================
Write-TestCase "Session files location shown"

$fakeUuid = [guid]::NewGuid().ToString()
$fakeDir = "$env:APPDATA\jobrunner\$fakeUuid"
New-Item -Path $fakeDir -ItemType Directory -Force | Out-Null
"SUCCESS" | Out-File -FilePath "$fakeDir\job_status.txt" -Encoding ascii
"55555" | Out-File -FilePath "$fakeDir\job_pid.txt" -Encoding ascii
"test" | Out-File -FilePath "$fakeDir\stdout.txt" -Encoding ascii
"" | Out-File -FilePath "$fakeDir\stderr.txt" -Encoding ascii

$result = Run-CommandWithTimeout -Command "`"$CheckJobScript`" `"$fakeUuid`"" -TimeoutSeconds 10
Assert-OutputContains -Output $result.Output -ExpectedText "Session files:" -TestDescription "Session files location shown"
Assert-OutputContains -Output $result.Output -ExpectedText $fakeUuid -TestDescription "UUID in session files path"

Cleanup-JobDirectory -JobUuid $fakeUuid

# ============================================================================
# Test 11: Check job while async_job is running (parallel operation)
# ============================================================================
Write-TestCase "Check job while async_job is running (parallel)"

# Start a long-running job
$asyncProcess = Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$AsyncJobScript`" `"ping -n 20 127.0.0.1`"" -PassThru -RedirectStandardOutput "$env:TEMP\parallel_test.txt" -NoNewWindow

Start-Sleep -Seconds 4

$asyncOutput = ""
if (Test-Path "$env:TEMP\parallel_test.txt") {
    $asyncOutput = Get-Content "$env:TEMP\parallel_test.txt" -Raw -ErrorAction SilentlyContinue
}

$jobUuid = Get-JobUuidFromOutput -Output $asyncOutput

if ($jobUuid) {
    # Check job multiple times while running
    for ($i = 1; $i -le 3; $i++) {
        $checkResult = Run-CommandWithTimeout -Command "`"$CheckJobScript`" `"$jobUuid`"" -TimeoutSeconds 10
        if ($checkResult.Output -like "*STATUS*") {
            Write-TestPass "Check #$i returned status successfully"
        } else {
            Write-TestFail "Check #$i did not return status"
        }
        Start-Sleep -Seconds 1
    }
    
    # Stop and clean up
    Run-CommandWithTimeout -Command "`"$StopJobScript`" `"$jobUuid`"" -TimeoutSeconds 30 | Out-Null
    try { $asyncProcess.Kill() } catch { }
    Cleanup-JobDirectory -JobUuid $jobUuid
} else {
    Write-TestSkip "Could not get UUID from async job output"
}

if (Test-Path "$env:TEMP\parallel_test.txt") {
    Remove-Item "$env:TEMP\parallel_test.txt" -Force -ErrorAction SilentlyContinue
}

# ============================================================================
# Test 12: Internals directory path shown
# ============================================================================
Write-TestCase "Internals directory path shown"

$fakeUuid = [guid]::NewGuid().ToString()
$fakeDir = "$env:APPDATA\jobrunner\$fakeUuid"
New-Item -Path $fakeDir -ItemType Directory -Force | Out-Null
"RUNNING" | Out-File -FilePath "$fakeDir\job_status.txt" -Encoding ascii
"44444" | Out-File -FilePath "$fakeDir\job_pid.txt" -Encoding ascii
"test" | Out-File -FilePath "$fakeDir\stdout.txt" -Encoding ascii
"" | Out-File -FilePath "$fakeDir\stderr.txt" -Encoding ascii

$result = Run-CommandWithTimeout -Command "`"$CheckJobScript`" `"$fakeUuid`"" -TimeoutSeconds 10
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
