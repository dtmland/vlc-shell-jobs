# Tests for Windows Batch File Utilities

This directory contains test suites for the batch file utilities in the parent `utils` directory.

## Overview

The tests are written in PowerShell for comprehensive testing capabilities, with wrapper BAT files for easy execution from the Windows command prompt.

## Running Tests

### Run All Tests

To run all test suites at once:

```batch
run_all_tests.bat
```

This will execute all test suites and provide a summary of passed/failed suites.

### Run Individual Test Suites

Each script has its own test file that can be run independently:

```batch
REM Test block_command.bat (synchronous command execution)
test_block_command.bat

REM Test async_job.bat (asynchronous job execution)
test_async_job.bat

REM Test check_job.bat (job status checking)
test_check_job.bat

REM Test stop_job.bat (stopping running jobs)
test_stop_job.bat
```

## Test Structure

Each test suite consists of:

1. **BAT wrapper** (`test_<name>.bat`) - Entry point for running tests from command prompt
2. **PowerShell test script** (`test_<name>.ps1`) - Contains the actual test cases
3. **Shared helpers** (`TestLib.ps1`) - Common utility functions for all tests

## Test Cases

### test_block_command.bat

Tests for `block_command.bat` - synchronous command execution:

- Missing command argument error handling
- Simple successful command execution
- Custom working directory support
- Stderr output capture
- Chained commands (`&&`)
- Failed command status (exit code handling)
- Special characters in output
- Output section formatting
- Default working directory behavior

### test_async_job.bat

Tests for `async_job.bat` - asynchronous job execution:

- Missing command argument error handling
- Job launch with UUID generation
- Internals directory and status file creation
- Successful job completion (SUCCESS status)
- Failed job completion (FAILURE status)
- Custom job name display
- Custom working directory support
- Default job name (AsyncJob)
- Stdout capture verification
- Polling status updates
- Final status section display
- Stop job instructions display

### test_check_job.bat

Tests for `check_job.bat` - job status checking:

- Missing UUID argument error handling
- Invalid UUID error handling
- Running job status display
- Completed job status display
- PID display
- Stdout content display
- Stderr content display
- Custom tail lines parameter
- Default tail lines (50)
- Parallel operation with running jobs
- Session files location display

### test_stop_job.bat

Tests for `stop_job.bat` - stopping running jobs:

- Missing UUID argument error handling
- Invalid UUID error handling
- Stopping a running job
- Handling already completed jobs
- Stdout/stderr at time of stop
- Session files location display
- Current job status display
- STOP JOB header formatting

## Test Helpers

The `TestLib.ps1` module provides:

- **Output Formatting**: Colored test output with PASS/FAIL indicators
- **Assertions**: 
  - `Assert-OutputContains` - Verify text in command output
  - `Assert-OutputNotContains` - Verify text is absent
  - `Assert-FileExists` - Verify file existence
  - `Assert-FileContains` - Verify file content
  - `Assert-DirectoryExists` - Verify directory existence
  - `Assert-ExitCodeZero` - Verify successful exit
  - `Assert-ExitCodeNonZero` - Verify failed exit
- **Utilities**:
  - `Get-JobUuidFromOutput` - Extract UUID from async_job output
  - `Wait-ForJobStatus` - Wait for job to reach expected status
  - `Cleanup-JobDirectory` - Remove job directory after test
  - `Run-CommandWithTimeout` - Execute command with timeout

## Requirements

- Windows 7 or later
- PowerShell (Windows PowerShell or PowerShell Core)
- The batch files being tested (`async_job.bat`, `block_command.bat`, etc.)

## Notes

- Tests create temporary job directories in `%APPDATA%\jobrunner\` and clean them up after completion
- Some tests launch background processes that are stopped and cleaned up automatically
- Test output includes color coding (green=pass, red=fail, yellow=skip)
- Exit code 0 indicates all tests passed; non-zero indicates failures
