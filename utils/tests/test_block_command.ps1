# test_block_command.ps1
# Tests for block_command.bat - synchronous command execution

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

$BlockCommandScript = Join-Path $UtilsDir "block_command.bat"

Write-TestHeader "block_command.bat Tests"

# Pre-flight checks
if (-not (Test-PreFlightChecks -ScriptPath $BlockCommandScript -ScriptName "block_command.bat")) {
    Write-Host "Pre-flight checks failed. Aborting tests."
    exit 1
}

Write-Host ""

# ============================================================================
# Test 1: No arguments provided - should show error
# ============================================================================
Write-TestCase "Missing command argument shows error"
$result = Run-CommandWithTimeout -Command "`"$BlockCommandScript`"" -TimeoutSeconds 30
Assert-OutputContains -Output $result.Output -ExpectedText "ERROR: No command specified" -TestDescription "Error message shown"
Assert-OutputContains -Output $result.Output -ExpectedText "Usage:" -TestDescription "Usage information shown"

# ============================================================================
# Test 2: Simple successful command (echo)
# ============================================================================
Write-TestCase "Simple successful command (echo hello)"
$result = Run-CommandWithTimeout -Command "`"$BlockCommandScript`" `"echo hello`"" -TimeoutSeconds 30
Assert-OutputContains -Output $result.Output -ExpectedText "Status: SUCCESS" -TestDescription "Command shows SUCCESS status"
Assert-OutputContains -Output $result.Output -ExpectedText "hello" -TestDescription "Output contains echoed text"
Assert-OutputContains -Output $result.Output -ExpectedText "BLOCK COMMAND EXECUTOR" -TestDescription "Header is shown"

# ============================================================================
# Test 3: Command with working directory
# ============================================================================
Write-TestCase "Command with custom working directory"
$testDir = $env:TEMP
$result = Run-CommandWithTimeout -Command "`"$BlockCommandScript`" `"cd`" `"$testDir`"" -TimeoutSeconds 30
Assert-OutputContains -Output $result.Output -ExpectedText "Status: SUCCESS" -TestDescription "Command shows SUCCESS"
Assert-OutputContains -Output $result.Output -ExpectedText "Working Directory: $testDir" -TestDescription "Working directory shown in output"

# ============================================================================
# Test 4: Command that writes to stderr
# ============================================================================
Write-TestCase "Command that generates stderr output"
$result = Run-CommandWithTimeout -Command "`"$BlockCommandScript`" `"echo stderr_test 1>&2`"" -TimeoutSeconds 30
Assert-OutputContains -Output $result.Output -ExpectedText "STDERR" -TestDescription "STDERR section shown"

# ============================================================================
# Test 5: Chained commands with && (success path)
# ============================================================================
Write-TestCase "Chained commands with && (both succeed)"
$result = Run-CommandWithTimeout -Command "`"$BlockCommandScript`" `"echo first && echo second`"" -TimeoutSeconds 30
Assert-OutputContains -Output $result.Output -ExpectedText "Status: SUCCESS" -TestDescription "Chained commands succeed"
Assert-OutputContains -Output $result.Output -ExpectedText "first" -TestDescription "First command output present"
Assert-OutputContains -Output $result.Output -ExpectedText "second" -TestDescription "Second command output present"

# ============================================================================
# Test 6: Command that fails
# ============================================================================
Write-TestCase "Command that fails (exit 1)"
$result = Run-CommandWithTimeout -Command "`"$BlockCommandScript`" `"exit 1`"" -TimeoutSeconds 30
Assert-OutputContains -Output $result.Output -ExpectedText "Status: FAILURE" -TestDescription "Failed command shows FAILURE"

# ============================================================================
# Test 7: Command with special characters in output
# ============================================================================
Write-TestCase "Command with special characters"
$result = Run-CommandWithTimeout -Command "`"$BlockCommandScript`" `"echo Hello World!`"" -TimeoutSeconds 30
Assert-OutputContains -Output $result.Output -ExpectedText "Status: SUCCESS" -TestDescription "Command with special chars succeeds"
Assert-OutputContains -Output $result.Output -ExpectedText "Hello" -TestDescription "Output contains expected text"

# ============================================================================
# Test 8: Output sections are properly formatted
# ============================================================================
Write-TestCase "Output sections are properly formatted"
$result = Run-CommandWithTimeout -Command "`"$BlockCommandScript`" `"echo test`"" -TimeoutSeconds 30
Assert-OutputContains -Output $result.Output -ExpectedText "RESULT" -TestDescription "RESULT section present"
Assert-OutputContains -Output $result.Output -ExpectedText "STDOUT" -TestDescription "STDOUT section present"
Assert-OutputContains -Output $result.Output -ExpectedText "STDERR" -TestDescription "STDERR section present"
Assert-OutputContains -Output $result.Output -ExpectedText "EXECUTION COMPLETE" -TestDescription "EXECUTION COMPLETE footer present"

# ============================================================================
# Test 9: Default working directory (USERPROFILE)
# ============================================================================
Write-TestCase "Default working directory is USERPROFILE"
$result = Run-CommandWithTimeout -Command "`"$BlockCommandScript`" `"echo test`"" -TimeoutSeconds 30
$expectedDir = $env:USERPROFILE
Assert-OutputContains -Output $result.Output -ExpectedText "Working Directory: $expectedDir" -TestDescription "Default directory is USERPROFILE"

# ============================================================================
# Summary
# ============================================================================
$allPassed = Write-TestSummary

if ($allPassed) {
    exit 0
} else {
    exit 1
}
