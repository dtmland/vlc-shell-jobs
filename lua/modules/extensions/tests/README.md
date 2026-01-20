# Lua Module Tests

This directory contains unit tests for the Lua modules in the VLC Shell Jobs extension.

## Test Suites

- **test_shell_job_defs.lua** - Tests for `shell_job_defs.lua` (constants and path utilities)
- **test_shell_operator_fileio.lua** - Tests for `shell_operator_fileio.lua` (file I/O operations)
- **test_shell_job_state.lua** - Tests for `shell_job_state.lua` (state machine logic)

## Running Tests

### Prerequisites

- Lua 5.3 or later installed

### Run All Tests

```bash
./run_lua_tests.sh
```

### Run Individual Tests

```bash
cd /path/to/vlc-shell-jobs
lua tests/test_shell_job_defs.lua
lua tests/test_shell_operator_fileio.lua
lua tests/test_shell_job_state.lua
```

## Test Library

The `test_lib.lua` module provides a simple test framework with:

- Test suite organization (`suite()`, `test_case()`)
- Assertion functions (`assert_equals()`, `assert_true()`, `assert_contains()`, etc.)
- Summary reporting with pass/fail counts
- ANSI color output for readability

## Test Structure

Each test file:

1. Sets up the package path for module loading
2. Loads the module under test
3. Creates test fixtures (temporary files/directories)
4. Runs test cases with assertions
5. Cleans up test fixtures
6. Reports results and exits with appropriate code

## Notes

- Tests use temporary directories that are cleaned up after running
- Tests are designed to run standalone (outside of VLC) for easier development
- The test framework doesn't require external dependencies
