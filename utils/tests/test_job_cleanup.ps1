# test_job_cleanup.ps1
# Tests for job_cleanup.bat - cleaning up old job directories

param(
    [Parameter(Mandatory=$true)]
    [string]$UtilsDir
)

# Import test helpers
. "$PSScriptRoot\TestLib.ps1"

# Initialize test log directory for storing failed test output
Initialize-TestLogDir

# Resolve the utils directory to absolute path
$UtilsDir = (Resolve-Path $UtilsDir -ErrorAction SilentlyContinue).Path
if (-not $UtilsDir) {
    Write-Host "ERROR: Utils directory not found: $UtilsDir"
    exit 1
}

$CleanupScript = Join-Path $UtilsDir "job_cleanup.bat"

Write-TestHeader "job_cleanup.bat Tests"

# Pre-flight checks
if (-not (Test-PreFlightChecks -ScriptPath $CleanupScript -ScriptName "job_cleanup.bat")) {
    Write-Host "Pre-flight checks failed. Aborting tests."
    exit 1
}

Write-Host ""

# Helper function to create a test job directory with a specific age
function New-TestJobDirectory {
    param(
        [string]$JobUuid,
        [int]$AgeSeconds
    )
    
    $jobDir = "$env:APPDATA\jobrunner\$JobUuid"
    New-Item -Path $jobDir -ItemType Directory -Force | Out-Null
    
    # Create standard job files
    [System.IO.File]::WriteAllText("$jobDir\job_status.txt", "SUCCESS" + [Environment]::NewLine)
    [System.IO.File]::WriteAllText("$jobDir\job_pid.txt", "12345" + [Environment]::NewLine)
    [System.IO.File]::WriteAllText("$jobDir\stdout.txt", "test output" + [Environment]::NewLine)
    [System.IO.File]::WriteAllText("$jobDir\stderr.txt", "")
    
    # Set the last write time to simulate age
    $targetTime = (Get-Date).AddSeconds(-$AgeSeconds)
    Get-ChildItem -Path $jobDir | ForEach-Object {
        $_.LastWriteTime = $targetTime
    }
    
    return $jobDir
}

# ============================================================================
# Test 1: No arguments - uses default max age (86400 seconds = 1 day)
# ============================================================================
Write-TestCase "Default max age is 86400 seconds (1 day)"
$result = Run-CommandWithTimeout -Command "call `"$CleanupScript`"" -TimeoutSeconds 30
Assert-OutputContains -Output $result.Output -ExpectedText "CLEANUP OLD JOBS" -TestDescription "Cleanup header shown"
Assert-OutputContains -Output $result.Output -ExpectedText "Max Age (seconds): 86400" -TestDescription "Default max age is 86400"

# ============================================================================
# Test 2: Custom max age parameter
# ============================================================================
Write-TestCase "Custom max age parameter"
$result = Run-CommandWithTimeout -Command "call `"$CleanupScript`" 3600" -TimeoutSeconds 30
Assert-OutputContains -Output $result.Output -ExpectedText "Max Age (seconds): 3600" -TestDescription "Custom max age is 3600"

# ============================================================================
# Test 3: Cleanup removes old job directory
# ============================================================================
Write-TestCase "Cleanup removes old job directory"

# Create an old test job (2 days old = 172800 seconds)
$oldJobUuid = [guid]::NewGuid().ToString()
$oldJobDir = New-TestJobDirectory -JobUuid $oldJobUuid -AgeSeconds 172800

# Verify the directory was created
Assert-DirectoryExists -DirectoryPath $oldJobDir -TestDescription "Old job directory created"

# Run cleanup with default 1 day max age
$result = Run-CommandWithTimeout -Command "call `"$CleanupScript`"" -TimeoutSeconds 30
Assert-OutputContains -Output $result.Output -ExpectedText "Removing old job directory" -TestDescription "Removing message shown"
Assert-OutputContains -Output $result.Output -ExpectedText $oldJobUuid -TestDescription "Old job UUID mentioned"

# Verify the directory was removed
if (Test-Path $oldJobDir) {
    Write-TestFail "Old job directory should have been removed but still exists"
} else {
    Write-TestPass "Old job directory was successfully removed"
}

# ============================================================================
# Test 4: Cleanup keeps recent job directory
# ============================================================================
Write-TestCase "Cleanup keeps recent job directory"

# Create a recent test job (1 hour old = 3600 seconds)
$recentJobUuid = [guid]::NewGuid().ToString()
$recentJobDir = New-TestJobDirectory -JobUuid $recentJobUuid -AgeSeconds 3600

# Verify the directory was created
Assert-DirectoryExists -DirectoryPath $recentJobDir -TestDescription "Recent job directory created"

# Run cleanup with default 1 day max age
$result = Run-CommandWithTimeout -Command "call `"$CleanupScript`"" -TimeoutSeconds 30
Assert-OutputContains -Output $result.Output -ExpectedText "Keeping recent job directory" -TestDescription "Keeping message shown"
Assert-OutputContains -Output $result.Output -ExpectedText $recentJobUuid -TestDescription "Recent job UUID mentioned"

# Verify the directory was NOT removed
Assert-DirectoryExists -DirectoryPath $recentJobDir -TestDescription "Recent job directory still exists"

# Clean up the test directory
Cleanup-JobDirectory -JobUuid $recentJobUuid

# ============================================================================
# Test 5: Cleanup with custom age threshold
# ============================================================================
Write-TestCase "Cleanup with custom age threshold removes older jobs"

# Create a test job that is 2 hours old
$testJobUuid = [guid]::NewGuid().ToString()
$testJobDir = New-TestJobDirectory -JobUuid $testJobUuid -AgeSeconds 7200

# Run cleanup with 1 hour max age (3600 seconds)
$result = Run-CommandWithTimeout -Command "call `"$CleanupScript`" 3600" -TimeoutSeconds 30
Assert-OutputContains -Output $result.Output -ExpectedText "Removing old job directory" -TestDescription "Removing message with custom threshold"

# Verify the directory was removed
if (Test-Path $testJobDir) {
    Write-TestFail "Job directory should have been removed with custom threshold"
    Cleanup-JobDirectory -JobUuid $testJobUuid
} else {
    Write-TestPass "Job directory was removed with custom threshold"
}

# ============================================================================
# Test 6: Cleanup reports count of removed directories
# ============================================================================
Write-TestCase "Cleanup reports count of removed directories"

# Create two old test jobs
$oldJob1 = [guid]::NewGuid().ToString()
$oldJob2 = [guid]::NewGuid().ToString()
New-TestJobDirectory -JobUuid $oldJob1 -AgeSeconds 172800 | Out-Null
New-TestJobDirectory -JobUuid $oldJob2 -AgeSeconds 172800 | Out-Null

# Run cleanup
$result = Run-CommandWithTimeout -Command "call `"$CleanupScript`"" -TimeoutSeconds 30
Assert-OutputContains -Output $result.Output -ExpectedText "Cleanup complete" -TestDescription "Cleanup complete message shown"

# Verify both directories were removed
if (-not (Test-Path "$env:APPDATA\jobrunner\$oldJob1") -and -not (Test-Path "$env:APPDATA\jobrunner\$oldJob2")) {
    Write-TestPass "Both old job directories were removed"
} else {
    Write-TestFail "Some old job directories were not removed"
    Cleanup-JobDirectory -JobUuid $oldJob1
    Cleanup-JobDirectory -JobUuid $oldJob2
}

# ============================================================================
# Test 7: Cleanup handles non-existent jobrunner directory
# ============================================================================
Write-TestCase "Cleanup handles non-existent jobrunner directory gracefully"

# Temporarily rename the jobrunner directory if it exists
$jobrunnerDir = "$env:APPDATA\jobrunner"
$backupDir = "$env:APPDATA\jobrunner_backup_test"

$hadExistingDir = Test-Path $jobrunnerDir
if ($hadExistingDir) {
    Rename-Item -Path $jobrunnerDir -NewName "jobrunner_backup_test" -ErrorAction SilentlyContinue
}

$result = Run-CommandWithTimeout -Command "call `"$CleanupScript`"" -TimeoutSeconds 30
Assert-OutputContains -Output $result.Output -ExpectedText "does not exist" -TestDescription "Non-existent directory message shown"

# Restore the jobrunner directory
if ($hadExistingDir) {
    Rename-Item -Path $backupDir -NewName "jobrunner" -ErrorAction SilentlyContinue
}

# ============================================================================
# Test 8: Jobrunner directory path shown
# ============================================================================
Write-TestCase "Jobrunner directory path shown"
$result = Run-CommandWithTimeout -Command "call `"$CleanupScript`"" -TimeoutSeconds 30
Assert-OutputContains -Output $result.Output -ExpectedText "Jobrunner Directory:" -TestDescription "Jobrunner directory label shown"
Assert-OutputContains -Output $result.Output -ExpectedText "jobrunner" -TestDescription "Path contains jobrunner"

# ============================================================================
# Summary
# ============================================================================
$allPassed = Write-TestSummary

if ($allPassed) {
    exit 0
} else {
    exit 1
}
