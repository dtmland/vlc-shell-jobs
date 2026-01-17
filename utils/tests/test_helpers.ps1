# test_helpers.ps1
# PowerShell helper functions for testing batch scripts
# This module provides utility functions for running tests and validating output

# Colors for test output
$script:GREEN = "`e[32m"
$script:RED = "`e[31m"
$script:YELLOW = "`e[33m"
$script:CYAN = "`e[36m"
$script:RESET = "`e[0m"

# Test counters
$script:TestsPassed = 0
$script:TestsFailed = 0
$script:TestsSkipped = 0

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

function Assert-OutputContains {
    param(
        [string]$Output,
        [string]$ExpectedText,
        [string]$TestDescription
    )
    
    if ($Output -like "*$ExpectedText*") {
        Write-TestPass "$TestDescription - Found expected text: '$ExpectedText'"
        return $true
    } else {
        Write-TestFail "$TestDescription - Expected text not found: '$ExpectedText'"
        Write-TestInfo "Actual output (truncated): $($Output.Substring(0, [Math]::Min(500, $Output.Length)))"
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
    if ($content -like "*$ExpectedContent*") {
        Write-TestPass "$TestDescription - File contains expected content"
        return $true
    } else {
        Write-TestFail "$TestDescription - Expected content not found in file"
        Write-TestInfo "File content: $($content.Substring(0, [Math]::Min(200, $content.Length)))"
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
    
    # Extract UUID from output - format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
    $match = [regex]::Match($Output, 'Job UUID:\s*([a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12})')
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
        Remove-Item -Path $jobDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Run-CommandWithTimeout {
    param(
        [string]$Command,
        [int]$TimeoutSeconds = 60
    )
    
    $processInfo = New-Object System.Diagnostics.ProcessStartInfo
    $processInfo.FileName = "cmd.exe"
    $processInfo.Arguments = "/c $Command"
    $processInfo.RedirectStandardOutput = $true
    $processInfo.RedirectStandardError = $true
    $processInfo.UseShellExecute = $false
    $processInfo.CreateNoWindow = $true
    
    $process = [System.Diagnostics.Process]::Start($processInfo)
    
    $stdout = $process.StandardOutput.ReadToEndAsync()
    $stderr = $process.StandardError.ReadToEndAsync()
    
    $completed = $process.WaitForExit($TimeoutSeconds * 1000)
    
    if (-not $completed) {
        $process.Kill()
        return @{
            Output = ""
            Error = "Process timed out after $TimeoutSeconds seconds"
            ExitCode = -1
            TimedOut = $true
        }
    }
    
    return @{
        Output = $stdout.Result
        Error = $stderr.Result
        ExitCode = $process.ExitCode
        TimedOut = $false
    }
}

# Export functions
Export-ModuleMember -Function *
