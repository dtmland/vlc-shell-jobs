# Lua Module Tests

This directory contains unit tests for the Lua modules in the VLC Shell Jobs extension.

## Test Suites

- **test_os_detect.lua** - Tests for `os_detect.lua` (OS detection utilities)
- **test_path_utils.lua** - Tests for `path_utils.lua` (path manipulation utilities)
- **test_shell_job_defs.lua** - Tests for `shell_job_defs.lua` (constants and path utilities)
- **test_shell_operator_fileio.lua** - Tests for `shell_operator_fileio.lua` (file I/O operations)
- **test_shell_job_state.lua** - Tests for `shell_job_state.lua` (state machine logic)
- **test_vlc_compat.lua** - Tests for `vlc_compat.lua` (VLC compatibility layer)
- **test_shell_execute.lua** - Tests for `shell_execute.lua` (shell command execution with file IPC)

## Running Tests

### Prerequisites

- Lua 5.3 or later installed

### Run All Tests

From this directory (`lua/modules/extensions/tests/`):

```bash
./run_lua_tests.sh
```

### Run Individual Tests

From this directory:

```bash
lua test_os_detect.lua
lua test_path_utils.lua
lua test_shell_job_defs.lua
lua test_shell_operator_fileio.lua
lua test_shell_job_state.lua
lua test_vlc_compat.lua
lua test_shell_execute.lua
```

## VLC Compatibility Layer

The `vlc_compat.lua` module provides a compatibility layer that allows Lua modules to be tested
outside of VLC. When running inside VLC, it returns the real `vlc` global object. When running
standalone (e.g., during tests), it provides mock implementations of:

- `vlc.msg.dbg()`, `vlc.msg.info()`, `vlc.msg.warn()`, `vlc.msg.err()` - logging functions
- `vlc.io.open()`, `vlc.io.mkdir()` - file I/O operations

This allows modules like `shell_execute.lua` to be tested with actual command execution and
file IPC without requiring VLC to be running.

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
- The `test_shell_execute.lua` test exercises actual shell command execution and file-based IPC
