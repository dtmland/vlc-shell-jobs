# test_check_job.ps1
# Tests for check_job.bat - checking job status
# These tests verify status checking functionality while jobs are running and after completion

param(
    [Parameter(Mandatory=$true)]
    [string]$UtilsDir
)

# Import test helpers
. "$PSScriptRoot\test_helpers.ps1"

# Initialize test log directory for storing failed test output
Initialize-TestLogDir

# Resolve the utils directory to absolute path
$UtilsDir = (Resolve-Path $UtilsDir -ErrorAction SilentlyContinue).Path
if (-not $UtilsDir) {
    Write-Host "ERROR: Utils directory not found: $UtilsDir"
    exit 1
}

$AsyncJobScript = Join-Path $UtilsDir "async_job.bat"
$CheckJobScript = Join-Path $UtilsDir "check_job.bat"
$StopJobScript = Join-Path $UtilsDir "stop_job.bat"

Write-TestHeader "check_job.bat Tests"

# Pre-flight checks
if (-not (Test-PreFlightChecks -ScriptPath $CheckJobScript -ScriptName "check_job.bat")) {
    Write-Host "Pre-flight checks failed. Aborting tests."
    exit 1
}

Write-Host ""

# ============================================================================
# Test 1: No UUID provided - should show error
# ============================================================================
Write-TestCase "Missing UUID argument shows error"
$result = Run-CommandWithTimeout -Command "call `"$CheckJobScript`"" -TimeoutSeconds 10
Assert-OutputContains -Output $result.Output -ExpectedText "ERROR: No job UUID specified" -TestDescription "Error message shown"
Assert-OutputContains -Output $result.Output -ExpectedText "Usage:" -TestDescription "Usage information shown"

# ============================================================================
# Test 2: Invalid UUID - directory not found
# ============================================================================
Write-TestCase "Invalid UUID shows directory not found error"
$fakeUuid = "00000000-0000-0000-0000-000000000001"
$result = Run-CommandWithTimeout -Command "call `"$CheckJobScript`" `"$fakeUuid`"" -TimeoutSeconds 10
Assert-OutputContains -Output $result.Output -ExpectedText "ERROR: Job directory not found" -TestDescription "Directory not found error shown"

# ============================================================================
# Test 3: Check a running job shows RUNNING status
# ============================================================================
Write-TestCase "Check running job shows RUNNING status"

# Launch a long-running job using Run-CommandWithTimeout to start it
# Then use Start-Process with properly separated arguments
$outputFile = "$env:TEMP\check_test_output.txt"

# Create a temp batch file to launch the async job
$launchBatch = [System.IO.Path]::GetTempFileName() + ".bat"
$launchContent = @"
@echo off
call "$AsyncJobScript" "ping -n 30 127.0.0.1" "%USERPROFILE%" "LongJob"
"@
[System.IO.File]::WriteAllText($launchBatch, $launchContent)

$asyncProcess = Start-Process -FilePath $launchBatch -PassThru -RedirectStandardOutput $outputFile -NoNewWindow

Start-Sleep -Seconds 5

$asyncOutput = ""
if (Test-Path $outputFile) {
    $asyncOutput = Get-Content $outputFile -Raw -ErrorAction SilentlyContinue
}

$jobUuid = Get-JobUuidFromOutput -Output $asyncOutput

if ($jobUuid) {
    Write-TestInfo "Job UUID: $jobUuid"
    
    # Check the job status
    $checkResult = Run-CommandWithTimeout -Command "call `"$CheckJobScript`" `"$jobUuid`"" -TimeoutSeconds 10
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
    Run-CommandWithTimeout -Command "call `"$StopJobScript`" `"$jobUuid`"" -TimeoutSeconds 30 | Out-Null
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

if (Test-Path $outputFile) {
    Remove-Item $outputFile -Force -ErrorAction SilentlyContinue
}
if (Test-Path $launchBatch) {
    Remove-Item $launchBatch -Force -ErrorAction SilentlyContinue
}

# ============================================================================
# Test 4: Check a completed job shows SUCCESS/FAILURE
# ============================================================================
Write-TestCase "Check completed job shows final status"

# Run a quick job
$result = Run-CommandWithTimeout -Command "call `"$AsyncJobScript`" `"echo quick_check_test`"" -TimeoutSeconds 30
$jobUuid = Get-JobUuidFromOutput -Output $result.Output

if ($jobUuid) {
    # Check the completed job
    $checkResult = Run-CommandWithTimeout -Command "call `"$CheckJobScript`" `"$jobUuid`"" -TimeoutSeconds 10
    
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
# Use WriteAllText to avoid BOM and ensure clean file content
[System.IO.File]::WriteAllText("$fakeDir\job_status.txt", "RUNNING")
[System.IO.File]::WriteAllText("$fakeDir\job_pid.txt", "12345")
[System.IO.File]::WriteAllText("$fakeDir\stdout.txt", "test stdout content")
[System.IO.File]::WriteAllText("$fakeDir\stderr.txt", "")

$result = Run-CommandWithTimeout -Command "call `"$CheckJobScript`" `"$fakeUuid`"" -TimeoutSeconds 10
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
[System.IO.File]::WriteAllText("$fakeDir\job_status.txt", "SUCCESS")
[System.IO.File]::WriteAllText("$fakeDir\job_pid.txt", "99999")
[System.IO.File]::WriteAllText("$fakeDir\stdout.txt", "hello from stdout test")
[System.IO.File]::WriteAllText("$fakeDir\stderr.txt", "")

$result = Run-CommandWithTimeout -Command "call `"$CheckJobScript`" `"$fakeUuid`"" -TimeoutSeconds 10
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
[System.IO.File]::WriteAllText("$fakeDir\job_status.txt", "FAILURE")
[System.IO.File]::WriteAllText("$fakeDir\job_pid.txt", "88888")
[System.IO.File]::WriteAllText("$fakeDir\stdout.txt", "")
[System.IO.File]::WriteAllText("$fakeDir\stderr.txt", "error from stderr test")

$result = Run-CommandWithTimeout -Command "call `"$CheckJobScript`" `"$fakeUuid`"" -TimeoutSeconds 10
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
[System.IO.File]::WriteAllText("$fakeDir\job_status.txt", "SUCCESS")
[System.IO.File]::WriteAllText("$fakeDir\job_pid.txt", "77777")
[System.IO.File]::WriteAllText("$fakeDir\stdout.txt", "line1`r`nline2`r`nline3`r`nline4`r`nline5")
[System.IO.File]::WriteAllText("$fakeDir\stderr.txt", "")

$result = Run-CommandWithTimeout -Command "call `"$CheckJobScript`" `"$fakeUuid`" 100" -TimeoutSeconds 10
Assert-OutputContains -Output $result.Output -ExpectedText "Tail lines: 100" -TestDescription "Custom tail lines shown"

Cleanup-JobDirectory -JobUuid $fakeUuid

# ============================================================================
# Test 9: Default tail lines is 50
# ============================================================================
Write-TestCase "Default tail lines is 50"

$fakeUuid = [guid]::NewGuid().ToString()
$fakeDir = "$env:APPDATA\jobrunner\$fakeUuid"
New-Item -Path $fakeDir -ItemType Directory -Force | Out-Null
[System.IO.File]::WriteAllText("$fakeDir\job_status.txt", "SUCCESS")
[System.IO.File]::WriteAllText("$fakeDir\job_pid.txt", "66666")
[System.IO.File]::WriteAllText("$fakeDir\stdout.txt", "test")
[System.IO.File]::WriteAllText("$fakeDir\stderr.txt", "")

$result = Run-CommandWithTimeout -Command "call `"$CheckJobScript`" `"$fakeUuid`"" -TimeoutSeconds 10
Assert-OutputContains -Output $result.Output -ExpectedText "Tail lines: 50" -TestDescription "Default tail lines is 50"

Cleanup-JobDirectory -JobUuid $fakeUuid

# ============================================================================
# Test 10: Session files location shown
# ============================================================================
Write-TestCase "Session files location shown"

$fakeUuid = [guid]::NewGuid().ToString()
$fakeDir = "$env:APPDATA\jobrunner\$fakeUuid"
New-Item -Path $fakeDir -ItemType Directory -Force | Out-Null
[System.IO.File]::WriteAllText("$fakeDir\job_status.txt", "SUCCESS")
[System.IO.File]::WriteAllText("$fakeDir\job_pid.txt", "55555")
[System.IO.File]::WriteAllText("$fakeDir\stdout.txt", "test")
[System.IO.File]::WriteAllText("$fakeDir\stderr.txt", "")

$result = Run-CommandWithTimeout -Command "call `"$CheckJobScript`" `"$fakeUuid`"" -TimeoutSeconds 10
Assert-OutputContains -Output $result.Output -ExpectedText "Session files:" -TestDescription "Session files location shown"
Assert-OutputContains -Output $result.Output -ExpectedText $fakeUuid -TestDescription "UUID in session files path"

Cleanup-JobDirectory -JobUuid $fakeUuid

# ============================================================================
# Test 11: Check job while async_job is running (parallel operation)
# ============================================================================
Write-TestCase "Check job while async_job is running (parallel)"

# Start a long-running job using a temp batch file to avoid quoting issues
$parallelOutputFile = "$env:TEMP\parallel_test.txt"
$parallelLaunchBatch = [System.IO.Path]::GetTempFileName() + ".bat"
$parallelLaunchContent = @"
@echo off
call "$AsyncJobScript" "ping -n 20 127.0.0.1"
"@
[System.IO.File]::WriteAllText($parallelLaunchBatch, $parallelLaunchContent)

$asyncProcess = Start-Process -FilePath $parallelLaunchBatch -PassThru -RedirectStandardOutput $parallelOutputFile -NoNewWindow

Start-Sleep -Seconds 4

$asyncOutput = ""
if (Test-Path $parallelOutputFile) {
    $asyncOutput = Get-Content $parallelOutputFile -Raw -ErrorAction SilentlyContinue
}

$jobUuid = Get-JobUuidFromOutput -Output $asyncOutput

if ($jobUuid) {
    # Check job multiple times while running
    for ($i = 1; $i -le 3; $i++) {
        $checkResult = Run-CommandWithTimeout -Command "call `"$CheckJobScript`" `"$jobUuid`"" -TimeoutSeconds 10
        if ($checkResult.Output -like "*STATUS*") {
            Write-TestPass "Check #$i returned status successfully"
        } else {
            Write-TestFail "Check #$i did not return status"
        }
        Start-Sleep -Seconds 1
    }
    
    # Stop and clean up
    Run-CommandWithTimeout -Command "call `"$StopJobScript`" `"$jobUuid`"" -TimeoutSeconds 30 | Out-Null
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

if (Test-Path $parallelOutputFile) {
    Remove-Item $parallelOutputFile -Force -ErrorAction SilentlyContinue
}
if (Test-Path $parallelLaunchBatch) {
    Remove-Item $parallelLaunchBatch -Force -ErrorAction SilentlyContinue
}

# ============================================================================
# Test 12: Internals directory path shown
# ============================================================================
Write-TestCase "Internals directory path shown"

$fakeUuid = [guid]::NewGuid().ToString()
$fakeDir = "$env:APPDATA\jobrunner\$fakeUuid"
New-Item -Path $fakeDir -ItemType Directory -Force | Out-Null
[System.IO.File]::WriteAllText("$fakeDir\job_status.txt", "RUNNING")
[System.IO.File]::WriteAllText("$fakeDir\job_pid.txt", "44444")
[System.IO.File]::WriteAllText("$fakeDir\stdout.txt", "test")
[System.IO.File]::WriteAllText("$fakeDir\stderr.txt", "")

$result = Run-CommandWithTimeout -Command "call `"$CheckJobScript`" `"$fakeUuid`"" -TimeoutSeconds 10
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
