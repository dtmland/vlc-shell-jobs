# verify_test_helpers.ps1
# Diagnostic script to verify test_helpers.ps1 functions are working correctly
# Run this to debug issues with the test infrastructure

Write-Host "============================================================================"
Write-Host "TEST HELPERS VERIFICATION SCRIPT"
Write-Host "============================================================================"
Write-Host ""

# Import test helpers
Write-Host "Step 1: Import test_helpers.ps1"
Write-Host "  Importing from: $PSScriptRoot\test_helpers.ps1"
. "$PSScriptRoot\test_helpers.ps1"
Write-Host "  [OK] Import successful"
Write-Host ""

# Test 1: Verify Run-CommandWithTimeout with simple echo
Write-Host "============================================================================"
Write-Host "Test 1: Run-CommandWithTimeout with 'echo hello'"
Write-Host "============================================================================"

$result = Run-CommandWithTimeout -Command "echo hello" -TimeoutSeconds 10

Write-Host "  Command: echo hello"
Write-Host "  Exit Code: $($result.ExitCode)"
Write-Host "  Timed Out: $($result.TimedOut)"
Write-Host "  Output Length: $($result.Output.Length)"
Write-Host "  Error Length: $($result.Error.Length)"
Write-Host "  Output Content: [$($result.Output)]"
Write-Host "  Error Content: [$($result.Error)]"

if ($result.Output -like "*hello*") {
    Write-Host "  [PASS] Output contains 'hello'"
} else {
    Write-Host "  [FAIL] Output does NOT contain 'hello'"
}
Write-Host ""

# Test 2: Run a batch file directly (no args)
Write-Host "============================================================================"
Write-Host "Test 2: Run-CommandWithTimeout with batch file (no args)"
Write-Host "============================================================================"

$utilsDir = (Resolve-Path "$PSScriptRoot\.." -ErrorAction SilentlyContinue).Path
$blockCommandScript = Join-Path $utilsDir "block_command.bat"

Write-Host "  Utils Dir: $utilsDir"
Write-Host "  Block Command Script: $blockCommandScript"
Write-Host "  Script Exists: $(Test-Path $blockCommandScript)"

if (Test-Path $blockCommandScript) {
    # Call without arguments - should show usage error
    $result2 = Run-CommandWithTimeout -Command "call `"$blockCommandScript`"" -TimeoutSeconds 30
    
    Write-Host "  Exit Code: $($result2.ExitCode)"
    Write-Host "  Timed Out: $($result2.TimedOut)"
    Write-Host "  Output Length: $($result2.Output.Length)"
    Write-Host "  Error Length: $($result2.Error.Length)"
    Write-Host "  Output (first 500 chars):"
    if ($result2.Output.Length -gt 0) {
        $truncated = $result2.Output.Substring(0, [Math]::Min(500, $result2.Output.Length))
        Write-Host "  $truncated"
    } else {
        Write-Host "  <empty>"
    }
    
    if ($result2.Output -like "*ERROR*" -or $result2.Output -like "*Usage*") {
        Write-Host "  [PASS] Got expected error/usage output from block_command.bat (no args)"
    } else {
        Write-Host "  [FAIL] Did not get expected output from block_command.bat"
    }
} else {
    Write-Host "  [SKIP] block_command.bat not found at expected path"
}
Write-Host ""

# Test 3: Check temp file creation directly
Write-Host "============================================================================"
Write-Host "Test 3: Verify temp file approach is working"
Write-Host "============================================================================"

$tempBatch = [System.IO.Path]::GetTempFileName() + ".bat"
$tempStdout = [System.IO.Path]::GetTempFileName()

Write-Host "  Temp Batch: $tempBatch"
Write-Host "  Temp Stdout: $tempStdout"

# Write test content with redirection inside the batch
$batchContent = @"
@echo off
echo TEST_OUTPUT_12345 > "$tempStdout"
"@
[System.IO.File]::WriteAllText($tempBatch, $batchContent)

Write-Host "  Batch file created: $(Test-Path $tempBatch)"
Write-Host "  Batch content:"
Get-Content $tempBatch | ForEach-Object { Write-Host "    $_" }

# Execute the batch file directly
$processInfo = New-Object System.Diagnostics.ProcessStartInfo
$processInfo.FileName = $tempBatch
$processInfo.UseShellExecute = $false
$processInfo.CreateNoWindow = $true

$process = New-Object System.Diagnostics.Process
$process.StartInfo = $processInfo
$process.Start() | Out-Null
$process.WaitForExit(10000) | Out-Null

Write-Host "  Process exit code: $($process.ExitCode)"
Write-Host "  Stdout file exists: $(Test-Path $tempStdout)"

if (Test-Path $tempStdout) {
    $content = Get-Content $tempStdout -Raw
    Write-Host "  Stdout file content: [$content]"
    
    if ($content -like "*TEST_OUTPUT_12345*") {
        Write-Host "  [PASS] Temp file approach is working correctly"
    } else {
        Write-Host "  [FAIL] Temp file does not contain expected output"
    }
} else {
    Write-Host "  [FAIL] Stdout temp file was not created"
}

# Cleanup
Remove-Item $tempBatch -Force -ErrorAction SilentlyContinue
Remove-Item $tempStdout -Force -ErrorAction SilentlyContinue
$process.Dispose()
Write-Host ""

# Test 4: Run block_command.bat with an argument
Write-Host "============================================================================"
Write-Host "Test 4: Run block_command.bat with 'echo hello' argument"
Write-Host "============================================================================"

if (Test-Path $blockCommandScript) {
    # Use call to run the batch file with arguments
    $testCommand = "call `"$blockCommandScript`" `"echo hello`""
    Write-Host "  Full command: $testCommand"
    
    $result4 = Run-CommandWithTimeout -Command $testCommand -TimeoutSeconds 30
    
    Write-Host "  Exit Code: $($result4.ExitCode)"
    Write-Host "  Output Length: $($result4.Output.Length)"
    Write-Host "  Output (first 1000 chars):"
    if ($result4.Output.Length -gt 0) {
        $truncated = $result4.Output.Substring(0, [Math]::Min(1000, $result4.Output.Length))
        Write-Host "$truncated"
    } else {
        Write-Host "  <empty>"
    }
    
    if ($result4.Output -like "*BLOCK COMMAND*" -or $result4.Output -like "*hello*" -or $result4.Output -like "*Status*") {
        Write-Host "  [PASS] Got expected output from block_command.bat with args"
    } else {
        Write-Host "  [FAIL] Did not get expected output"
    }
} else {
    Write-Host "  [SKIP] block_command.bat not found"
}
Write-Host ""

# Test 5: Check what the wrapper batch file looks like
Write-Host "============================================================================"
Write-Host "Test 5: Examine generated wrapper batch file contents"
Write-Host "============================================================================"

$tempBatch2 = [System.IO.Path]::GetTempFileName() + ".bat"
$tempOut = [System.IO.Path]::GetTempFileName()
$tempErr = [System.IO.Path]::GetTempFileName()

$testCmd = "call `"$blockCommandScript`" `"echo hello`""
$batchContent2 = @"
@echo off
$testCmd > "$tempOut" 2> "$tempErr"
"@
[System.IO.File]::WriteAllText($tempBatch2, $batchContent2)

Write-Host "  Wrapper batch file: $tempBatch2"
Write-Host "  Contents:"
Get-Content $tempBatch2 | ForEach-Object { Write-Host "    $_" }

Remove-Item $tempBatch2 -Force -ErrorAction SilentlyContinue
Remove-Item $tempOut -Force -ErrorAction SilentlyContinue
Remove-Item $tempErr -Force -ErrorAction SilentlyContinue
Write-Host ""

Write-Host "============================================================================"
Write-Host "VERIFICATION COMPLETE"
Write-Host "============================================================================"
Write-Host ""
Write-Host "If tests above show [FAIL], the issue is in Run-CommandWithTimeout."
Write-Host "If tests above show [PASS] but actual tests fail, the issue may be"
Write-Host "in how commands are being constructed in the test files."
