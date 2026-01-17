# test_async_job.ps1
# Tests for async_job.bat - asynchronous job execution
# These tests launch background jobs and verify status files, output, and completion

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

Write-TestHeader "async_job.bat Tests"

# Pre-flight checks
if (-not (Test-PreFlightChecks -ScriptPath $AsyncJobScript -ScriptName "async_job.bat")) {
    Write-Host "Pre-flight checks failed. Aborting tests."
    exit 1
}

Write-Host ""

# ============================================================================
# Test 1: No arguments provided - should show error
# ============================================================================
Write-TestCase "Missing command argument shows error"
$result = Run-CommandWithTimeout -Command "call `"$AsyncJobScript`"" -TimeoutSeconds 10
Assert-OutputContains -Output $result.Output -ExpectedText "ERROR: No command specified" -TestDescription "Error message shown"
Assert-OutputContains -Output $result.Output -ExpectedText "Usage:" -TestDescription "Usage information shown"

# ============================================================================
# Test 2: Job launches and shows UUID
# ============================================================================
Write-TestCase "Job launches and shows UUID"
# Use a quick command that completes fast
$result = Run-CommandWithTimeout -Command "call `"$AsyncJobScript`" `"echo test_launch`"" -TimeoutSeconds 30
Assert-OutputContains -Output $result.Output -ExpectedText "ASYNC JOB LAUNCHER" -TestDescription "Header shown"
Assert-OutputContains -Output $result.Output -ExpectedText "Job UUID:" -TestDescription "UUID displayed"
Assert-OutputContains -Output $result.Output -ExpectedText "Job Name:" -TestDescription "Job name displayed"
Assert-OutputContains -Output $result.Output -ExpectedText "Internals Directory:" -TestDescription "Internals directory shown"

$jobUuid = Get-JobUuidFromOutput -Output $result.Output
if ($jobUuid) {
    Write-TestPass "UUID extracted: $jobUuid"
    Cleanup-JobDirectory -JobUuid $jobUuid
} else {
    Write-TestFail "Could not extract UUID from output"
}

# ============================================================================
# Test 3: Job creates internals directory and status files
# ============================================================================
Write-TestCase "Job creates internals directory and status files"
$result = Run-CommandWithTimeout -Command "call `"$AsyncJobScript`" `"echo file_test`"" -TimeoutSeconds 30

$jobUuid = Get-JobUuidFromOutput -Output $result.Output
if ($jobUuid) {
    $internalsDir = "$env:APPDATA\jobrunner\$jobUuid"
    
    # Wait a moment for files to be created
    Start-Sleep -Seconds 1
    
    Assert-DirectoryExists -DirectoryPath $internalsDir -TestDescription "Internals directory created"
    Assert-FileExists -FilePath "$internalsDir\job_uuid.txt" -TestDescription "UUID file created"
    Assert-FileExists -FilePath "$internalsDir\job_status.txt" -TestDescription "Status file created"
    Assert-FileExists -FilePath "$internalsDir\stdout.txt" -TestDescription "Stdout file created"
    
    Cleanup-JobDirectory -JobUuid $jobUuid
} else {
    Write-TestFail "Could not extract UUID - skipping file tests"
}

# ============================================================================
# Test 4: Successful job has SUCCESS status
# ============================================================================
Write-TestCase "Successful job shows SUCCESS status"
$result = Run-CommandWithTimeout -Command "call `"$AsyncJobScript`" `"echo success_test`"" -TimeoutSeconds 30
Assert-OutputContains -Output $result.Output -ExpectedText "SUCCESS" -TestDescription "Job shows SUCCESS status"
Assert-OutputContains -Output $result.Output -ExpectedText "JOB COMPLETED" -TestDescription "Job completed message shown"
Assert-OutputContains -Output $result.Output -ExpectedText "success_test" -TestDescription "Command output captured"

$jobUuid = Get-JobUuidFromOutput -Output $result.Output
if ($jobUuid) {
    Cleanup-JobDirectory -JobUuid $jobUuid
}

# ============================================================================
# Test 5: Failed job has FAILURE status
# ============================================================================
Write-TestCase "Failed job shows FAILURE status"
$result = Run-CommandWithTimeout -Command "call `"$AsyncJobScript`" `"exit 1`"" -TimeoutSeconds 30
Assert-OutputContains -Output $result.Output -ExpectedText "FAILURE" -TestDescription "Job shows FAILURE status"
Assert-OutputContains -Output $result.Output -ExpectedText "JOB COMPLETED" -TestDescription "Job completed message shown"

$jobUuid = Get-JobUuidFromOutput -Output $result.Output
if ($jobUuid) {
    Cleanup-JobDirectory -JobUuid $jobUuid
}

# ============================================================================
# Test 6: Custom job name is displayed
# ============================================================================
Write-TestCase "Custom job name is displayed"
$result = Run-CommandWithTimeout -Command "call `"$AsyncJobScript`" `"echo test`" `"%USERPROFILE%`" `"MyCustomJob`"" -TimeoutSeconds 30
Assert-OutputContains -Output $result.Output -ExpectedText "Job Name: MyCustomJob" -TestDescription "Custom job name shown"

$jobUuid = Get-JobUuidFromOutput -Output $result.Output
if ($jobUuid) {
    Cleanup-JobDirectory -JobUuid $jobUuid
}

# ============================================================================
# Test 7: Custom working directory
# ============================================================================
Write-TestCase "Custom working directory"
$testDir = $env:TEMP
$result = Run-CommandWithTimeout -Command "call `"$AsyncJobScript`" `"cd`" `"$testDir`"" -TimeoutSeconds 30
Assert-OutputContains -Output $result.Output -ExpectedText "Working Directory: $testDir" -TestDescription "Custom working directory shown"
Assert-OutputContains -Output $result.Output -ExpectedText "SUCCESS" -TestDescription "Job succeeded"

$jobUuid = Get-JobUuidFromOutput -Output $result.Output
if ($jobUuid) {
    Cleanup-JobDirectory -JobUuid $jobUuid
}

# ============================================================================
# Test 8: Default job name is AsyncJob
# ============================================================================
Write-TestCase "Default job name is AsyncJob"
$result = Run-CommandWithTimeout -Command "call `"$AsyncJobScript`" `"echo test`"" -TimeoutSeconds 30
Assert-OutputContains -Output $result.Output -ExpectedText "Job Name: AsyncJob" -TestDescription "Default job name is AsyncJob"

$jobUuid = Get-JobUuidFromOutput -Output $result.Output
if ($jobUuid) {
    Cleanup-JobDirectory -JobUuid $jobUuid
}

# ============================================================================
# Test 9: Job captures stdout properly
# ============================================================================
Write-TestCase "Job captures stdout properly"
$testString = "stdout_capture_test_$(Get-Random)"
$result = Run-CommandWithTimeout -Command "call `"$AsyncJobScript`" `"echo $testString`"" -TimeoutSeconds 30
Assert-OutputContains -Output $result.Output -ExpectedText $testString -TestDescription "Stdout captured in output"

$jobUuid = Get-JobUuidFromOutput -Output $result.Output
if ($jobUuid) {
    $stdoutFile = "$env:APPDATA\jobrunner\$jobUuid\stdout.txt"
    if (Test-Path $stdoutFile) {
        Assert-FileContains -FilePath $stdoutFile -ExpectedContent $testString -TestDescription "Stdout file contains expected text"
    }
    Cleanup-JobDirectory -JobUuid $jobUuid
}

# ============================================================================
# Test 10: Polling shows status updates
# ============================================================================
Write-TestCase "Polling shows status updates"
$result = Run-CommandWithTimeout -Command "call `"$AsyncJobScript`" `"ping -n 2 127.0.0.1`"" -TimeoutSeconds 60
Assert-OutputContains -Output $result.Output -ExpectedText "Poll #" -TestDescription "Polling counter shown"
Assert-OutputContains -Output $result.Output -ExpectedText "Status:" -TestDescription "Status displayed during polling"

$jobUuid = Get-JobUuidFromOutput -Output $result.Output
if ($jobUuid) {
    Cleanup-JobDirectory -JobUuid $jobUuid
}

# ============================================================================
# Test 11: Final status section displayed
# ============================================================================
Write-TestCase "Final status section displayed"
$result = Run-CommandWithTimeout -Command "call `"$AsyncJobScript`" `"echo final_test`"" -TimeoutSeconds 30
Assert-OutputContains -Output $result.Output -ExpectedText "FINAL STATUS" -TestDescription "Final status section shown"
Assert-OutputContains -Output $result.Output -ExpectedText "FINAL STDOUT" -TestDescription "Final stdout section shown"
Assert-OutputContains -Output $result.Output -ExpectedText "FINAL STDERR" -TestDescription "Final stderr section shown"

$jobUuid = Get-JobUuidFromOutput -Output $result.Output
if ($jobUuid) {
    Cleanup-JobDirectory -JobUuid $jobUuid
}

# ============================================================================
# Test 12: Stop job instructions are shown
# ============================================================================
Write-TestCase "Stop job instructions are shown"
$result = Run-CommandWithTimeout -Command "call `"$AsyncJobScript`" `"echo quick`"" -TimeoutSeconds 30
Assert-OutputContains -Output $result.Output -ExpectedText "stop_job.bat" -TestDescription "Stop job instructions shown"

$jobUuid = Get-JobUuidFromOutput -Output $result.Output
if ($jobUuid) {
    Cleanup-JobDirectory -JobUuid $jobUuid
}

# ============================================================================
# Test 13: Default working directory is USERPROFILE
# ============================================================================
Write-TestCase "Default working directory is USERPROFILE"
$result = Run-CommandWithTimeout -Command "call `"$AsyncJobScript`" `"echo test`"" -TimeoutSeconds 30
$expectedDir = $env:USERPROFILE
Assert-OutputContains -Output $result.Output -ExpectedText "Working Directory: $expectedDir" -TestDescription "Default directory is USERPROFILE"

$jobUuid = Get-JobUuidFromOutput -Output $result.Output
if ($jobUuid) {
    Cleanup-JobDirectory -JobUuid $jobUuid
}

# ============================================================================
# Summary
# ============================================================================
$allPassed = Write-TestSummary

if ($allPassed) {
    exit 0
} else {
    exit 1
}
