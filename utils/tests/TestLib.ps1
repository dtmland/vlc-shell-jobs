# TestLib.ps1
# PowerShell helper functions for testing batch scripts
# This module provides utility functions for running tests and validating output

# Colors for test output - use [char]27 for compatibility with PowerShell 5.1
$script:ESC = [char]27
$script:GREEN = "$($script:ESC)[32m"
$script:RED = "$($script:ESC)[31m"
$script:YELLOW = "$($script:ESC)[33m"
$script:CYAN = "$($script:ESC)[36m"
$script:RESET = "$($script:ESC)[0m"

# Test counters
$script:TestsPassed = 0
$script:TestsFailed = 0
$script:TestsSkipped = 0

# Test log directory for storing full output of failed tests
$script:TestLogDir = Join-Path $env:TEMP "vlc-shell-jobs-test-logs"

# UUID pattern for job output parsing (format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx)
$script:UUID_PATTERN = '[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}'

function Initialize-TestLogDir {
    if (-not (Test-Path $script:TestLogDir)) {
        New-Item -ItemType Directory -Path $script:TestLogDir -Force | Out-Null
    }
    # Clean up old log files at start
    Get-ChildItem -Path $script:TestLogDir -Filter "*.log" -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
}

function Write-TestHeader {
    param([string]$TestSuiteName)
    Write-Host ""
    Write-Host "============================================================================"
    Write-Host "$($script:CYAN)TEST SUITE: $TestSuiteName$($script:RESET)"
    Write-Host "============================================================================"
    Write-Host ""
}

function Write-TestCase {
    param([string]$TestName)
    Write-Host "--- TEST: $TestName ---"
}

function Write-TestPass {
    param([string]$Message)
    $script:TestsPassed++
    Write-Host "$($script:GREEN)  PASS: $Message$($script:RESET)"
}

function Write-TestFail {
    param([string]$Message)
    $script:TestsFailed++
    Write-Host "$($script:RED)  FAIL: $Message$($script:RESET)"
}

function Write-TestSkip {
    param([string]$Message)
    $script:TestsSkipped++
    Write-Host "$($script:YELLOW)  SKIP: $Message$($script:RESET)"
}

function Write-TestInfo {
    param([string]$Message)
    Write-Host "  INFO: $Message"
}

function Save-FailedTestOutput {
    param(
        [string]$TestDescription,
        [string]$Output,
        [string]$ExpectedText
    )
    
    # Ensure log directory exists
    if (-not (Test-Path $script:TestLogDir)) {
        New-Item -ItemType Directory -Path $script:TestLogDir -Force | Out-Null
    }
    
    # Create a safe filename from the test description
    $safeFileName = $TestDescription -replace '[^a-zA-Z0-9]', '_'
    $safeFileName = $safeFileName.Substring(0, [Math]::Min(50, $safeFileName.Length))
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $logFile = Join-Path $script:TestLogDir "${safeFileName}_${timestamp}.log"
    
    # Write the full output to the log file
    $logContent = @"
============================================================================
FAILED TEST: $TestDescription
============================================================================
Expected text not found: '$ExpectedText'
============================================================================
FULL OUTPUT:
============================================================================
$Output
============================================================================
"@
    [System.IO.File]::WriteAllText($logFile, $logContent)
    
    return $logFile
}

function Write-TestSummary {
    Write-Host ""
    Write-Host "============================================================================"
    Write-Host "TEST SUMMARY"
    Write-Host "============================================================================"
    Write-Host "  Passed:  $($script:GREEN)$($script:TestsPassed)$($script:RESET)"
    Write-Host "  Failed:  $($script:RED)$($script:TestsFailed)$($script:RESET)"
    Write-Host "  Skipped: $($script:YELLOW)$($script:TestsSkipped)$($script:RESET)"
    Write-Host "  Total:   $($script:TestsPassed + $script:TestsFailed + $script:TestsSkipped)"
    Write-Host "============================================================================"
    
    if ($script:TestsFailed -gt 0) {
        Write-Host "$($script:RED)RESULT: SOME TESTS FAILED$($script:RESET)"
        return $false
    } else {
        Write-Host "$($script:GREEN)RESULT: ALL TESTS PASSED$($script:RESET)"
        return $true
    }
}

function Reset-TestCounters {
    $script:TestsPassed = 0
    $script:TestsFailed = 0
    $script:TestsSkipped = 0
}

function Get-TestsPassed { return $script:TestsPassed }
function Get-TestsFailed { return $script:TestsFailed }
function Get-TestsSkipped { return $script:TestsSkipped }

function Test-PreFlightChecks {
    param(
        [string]$ScriptPath,
        [string]$ScriptName
    )
    
    Write-Host ""
    Write-Host "--- PRE-FLIGHT CHECKS ---"
    
    # Check if the script exists
    if (Test-Path $ScriptPath) {
        Write-Host "  [OK] Script found: $ScriptPath"
        return $true
    } else {
        Write-Host "  [ERROR] Script NOT found: $ScriptPath"
        Write-Host "  Tests cannot proceed without the target script."
        Write-Host ""
        return $false
    }
}

function Assert-OutputContains {
    param(
        [string]$Output,
        [string]$ExpectedText,
        [string]$TestDescription
    )
    
    # Handle null or empty output
    if ([string]::IsNullOrEmpty($Output)) {
        Write-TestFail "$TestDescription - Expected text not found: '$ExpectedText'"
        Write-TestInfo "Actual output (truncated): <empty>"
        $logFile = Save-FailedTestOutput -TestDescription $TestDescription -Output "<empty>" -ExpectedText $ExpectedText
        Write-TestInfo "Full output saved to: $logFile"
        return $false
    }
    
    if ($Output -like "*$ExpectedText*") {
        Write-TestPass "$TestDescription - Found expected text: '$ExpectedText'"
        return $true
    } else {
        Write-TestFail "$TestDescription - Expected text not found: '$ExpectedText'"
        $truncatedLength = [Math]::Min(500, $Output.Length)
        Write-TestInfo "Actual output (truncated): $($Output.Substring(0, $truncatedLength))"
        $logFile = Save-FailedTestOutput -TestDescription $TestDescription -Output $Output -ExpectedText $ExpectedText
        Write-TestInfo "Full output saved to: $logFile"
        return $false
    }
}

function Assert-OutputNotContains {
    param(
        [string]$Output,
        [string]$UnexpectedText,
        [string]$TestDescription
    )
    
    if ($Output -notlike "*$UnexpectedText*") {
        Write-TestPass "$TestDescription - Text correctly not found: '$UnexpectedText'"
        return $true
    } else {
        Write-TestFail "$TestDescription - Unexpected text found: '$UnexpectedText'"
        return $false
    }
}

function Assert-FileExists {
    param(
        [string]$FilePath,
        [string]$TestDescription
    )
    
    if (Test-Path $FilePath) {
        Write-TestPass "$TestDescription - File exists: $FilePath"
        return $true
    } else {
        Write-TestFail "$TestDescription - File not found: $FilePath"
        return $false
    }
}

function Assert-FileContains {
    param(
        [string]$FilePath,
        [string]$ExpectedContent,
        [string]$TestDescription
    )
    
    if (-not (Test-Path $FilePath)) {
        Write-TestFail "$TestDescription - File not found: $FilePath"
        return $false
    }
    
    $content = Get-Content -Path $FilePath -Raw
    if ([string]::IsNullOrEmpty($content)) {
        Write-TestFail "$TestDescription - Expected content not found in file"
        Write-TestInfo "File content: <empty>"
        return $false
    }
    
    if ($content -like "*$ExpectedContent*") {
        Write-TestPass "$TestDescription - File contains expected content"
        return $true
    } else {
        Write-TestFail "$TestDescription - Expected content not found in file"
        $truncatedLength = [Math]::Min(200, $content.Length)
        Write-TestInfo "File content: $($content.Substring(0, $truncatedLength))"
        return $false
    }
}

function Assert-DirectoryExists {
    param(
        [string]$DirectoryPath,
        [string]$TestDescription
    )
    
    if (Test-Path $DirectoryPath -PathType Container) {
        Write-TestPass "$TestDescription - Directory exists: $DirectoryPath"
        return $true
    } else {
        Write-TestFail "$TestDescription - Directory not found: $DirectoryPath"
        return $false
    }
}

function Assert-ExitCodeZero {
    param(
        [int]$ExitCode,
        [string]$TestDescription
    )
    
    if ($ExitCode -eq 0) {
        Write-TestPass "$TestDescription - Exit code is 0"
        return $true
    } else {
        Write-TestFail "$TestDescription - Exit code is $ExitCode (expected 0)"
        return $false
    }
}

function Assert-ExitCodeNonZero {
    param(
        [int]$ExitCode,
        [string]$TestDescription
    )
    
    if ($ExitCode -ne 0) {
        Write-TestPass "$TestDescription - Exit code is non-zero ($ExitCode)"
        return $true
    } else {
        Write-TestFail "$TestDescription - Exit code is 0 (expected non-zero)"
        return $false
    }
}

function Get-JobUuidFromOutput {
    param([string]$Output)
    
    # Extract UUID from output using the shared pattern constant
    $match = [regex]::Match($Output, "Job UUID:\s*($script:UUID_PATTERN)")
    if ($match.Success) {
        return $match.Groups[1].Value
    }
    return $null
}

function Get-InternalsDirectoryFromOutput {
    param([string]$Output)
    
    # Extract internals directory from output
    $match = [regex]::Match($Output, 'Internals Directory:\s*(.+)')
    if ($match.Success) {
        return $match.Groups[1].Value.Trim()
    }
    return $null
}

function Wait-ForJobStatus {
    param(
        [string]$StatusFile,
        [string]$ExpectedStatus,
        [int]$TimeoutSeconds = 30
    )
    
    $startTime = Get-Date
    while ((Get-Date) - $startTime -lt [TimeSpan]::FromSeconds($TimeoutSeconds)) {
        if (Test-Path $StatusFile) {
            $status = (Get-Content $StatusFile -Raw).Trim()
            if ($status -eq $ExpectedStatus) {
                return $true
            }
        }
        Start-Sleep -Milliseconds 500
    }
    return $false
}

function Cleanup-JobDirectory {
    param([string]$JobUuid)
    
    $jobDir = "$env:APPDATA\jobrunner\$JobUuid"
    if (Test-Path $jobDir) {
        try {
            Remove-Item -Path $jobDir -Recurse -Force
        } catch {
            Write-TestInfo "Warning: Failed to cleanup job directory: $jobDir - $($_.Exception.Message)"
        }
    }
}

function Run-CommandWithTimeout {
    param(
        [string]$Command,
        [int]$TimeoutSeconds = 60
    )
    
    # Create temp files for the wrapper and output
    $tempBatch = [System.IO.Path]::GetTempFileName()
    # Rename to .bat extension
    $tempBatchBat = $tempBatch + ".bat"
    $tempStdout = [System.IO.Path]::GetTempFileName()
    $tempStderr = [System.IO.Path]::GetTempFileName()
    
    try {
        # Remove the original temp file (we'll use the .bat one)
        if (Test-Path $tempBatch) { Remove-Item $tempBatch -Force }
        
        # Write a wrapper batch file that includes the redirection
        # This avoids complex quoting issues with cmd.exe /c
        $batchContent = @"
@echo off
$Command > "$tempStdout" 2> "$tempStderr"
"@
        [System.IO.File]::WriteAllText($tempBatchBat, $batchContent)
        
        $processInfo = New-Object System.Diagnostics.ProcessStartInfo
        $processInfo.FileName = $tempBatchBat
        $processInfo.UseShellExecute = $false
        $processInfo.CreateNoWindow = $true
        $processInfo.WorkingDirectory = $env:USERPROFILE
        
        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $processInfo
        
        $process.Start() | Out-Null
        
        $completed = $process.WaitForExit($TimeoutSeconds * 1000)
        
        if (-not $completed) {
            $process.Kill()
            $stdout = if (Test-Path $tempStdout) { Get-Content $tempStdout -Raw -ErrorAction SilentlyContinue } else { "" }
            return @{
                Output = $stdout
                Error = "Process timed out after $TimeoutSeconds seconds"
                ExitCode = -1
                TimedOut = $true
            }
        }
        
        # Read captured output from temp files
        $stdout = if (Test-Path $tempStdout) { Get-Content $tempStdout -Raw -ErrorAction SilentlyContinue } else { "" }
        $stderr = if (Test-Path $tempStderr) { Get-Content $tempStderr -Raw -ErrorAction SilentlyContinue } else { "" }
        
        # Handle null from Get-Content
        if ($null -eq $stdout) { $stdout = "" }
        if ($null -eq $stderr) { $stderr = "" }
        
        return @{
            Output = $stdout
            Error = $stderr
            ExitCode = $process.ExitCode
            TimedOut = $false
        }
    }
    finally {
        if (Test-Path $tempBatch) { Remove-Item $tempBatch -Force -ErrorAction SilentlyContinue }
        if (Test-Path $tempBatchBat) { Remove-Item $tempBatchBat -Force -ErrorAction SilentlyContinue }
        if (Test-Path $tempStdout) { Remove-Item $tempStdout -Force -ErrorAction SilentlyContinue }
        if (Test-Path $tempStderr) { Remove-Item $tempStderr -Force -ErrorAction SilentlyContinue }
        if ($null -ne $process) { $process.Dispose() }
    }
}
