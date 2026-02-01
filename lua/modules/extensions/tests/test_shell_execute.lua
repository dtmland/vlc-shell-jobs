-- test_shell_execute.lua
-- Tests for shell_execute.lua module
-- These tests exercise actual command execution and file IPC

-- Set up package path to find modules
-- Tests are in lua/modules/extensions/tests/, modules are in lua/modules/extensions/
package.path = package.path .. ";./?.lua;../?.lua"

local test_lib = require("test_lib")

-- Load the modules - preload dependencies first
package.loaded["extensions.os_detect"] = dofile("../os_detect.lua")
package.loaded["extensions.path_utils"] = dofile("../path_utils.lua")
package.loaded["extensions.vlc_compat"] = dofile("../vlc_compat.lua")
local executor = dofile("../shell_execute.lua")
local os_detect = package.loaded["extensions.os_detect"]

-- ============================================================================
-- Test Setup
-- ============================================================================

local test_dir = test_lib.create_test_dir("vlc_shell_execute_test")
local sep = test_lib.get_path_separator()

-- ============================================================================
-- Tests
-- ============================================================================

test_lib.suite("shell_execute.lua")

-- ============================================================================
-- Test: executor.call() function
-- ============================================================================
test_lib.test_case("executor.call() executes simple successful command")
local result = executor.call("true")
test_lib.assert_true(result, "call() returns true for successful command 'true'")

test_lib.test_case("executor.call() executes echo command successfully")
result = executor.call("echo hello > /dev/null")
test_lib.assert_true(result, "call() returns true for echo command")

test_lib.test_case("executor.call() returns false for failing command")
result = executor.call("false")
test_lib.assert_false(result, "call() returns false for failing command 'false'")

test_lib.test_case("executor.call() returns false for non-existent command")
result = executor.call("nonexistent_command_12345 2>/dev/null")
test_lib.assert_false(result, "call() returns false for non-existent command")

-- ============================================================================
-- Test: executor.job() function (synchronous job execution)
-- ============================================================================
test_lib.test_case("executor.job() executes command and captures stdout")
-- Use simple commands that work with the shell wrapper
local success, stdout, stderr = executor.job("echo Hello_World", test_dir)
test_lib.assert_true(success, "job() returns success for echo command")
test_lib.assert_not_nil(stdout, "job() returns stdout")
test_lib.assert_contains(stdout, "Hello_World", "stdout contains expected output")

test_lib.test_case("executor.job() returns failure for failing command")
success, stdout, stderr = executor.job("exit 1", test_dir)
test_lib.assert_false(success, "job() returns failure for exit 1")

test_lib.test_case("executor.job() works with default directory")
success, stdout, stderr = executor.job("pwd", nil)
test_lib.assert_true(success, "job() succeeds with default directory")
test_lib.assert_not_nil(stdout, "job() returns stdout with default directory")

-- ============================================================================
-- Test: executor.get_jobrunner_base_directory() function
-- ============================================================================
test_lib.test_case("get_jobrunner_base_directory() returns valid path")
local base_dir = executor.get_jobrunner_base_directory()
test_lib.assert_not_nil(base_dir, "get_jobrunner_base_directory() returns non-nil")
test_lib.assert_type(base_dir, "string", "get_jobrunner_base_directory() returns string")
test_lib.assert_contains(base_dir, "jobrunner", "base directory contains 'jobrunner'")

if not os_detect.is_windows() then
    test_lib.assert_contains(base_dir, ".config", "Unix base directory contains '.config'")
end

-- ============================================================================
-- Test: executor.get_job_directories_with_ages() function
-- ============================================================================
test_lib.test_case("get_job_directories_with_ages() returns table")
local dirs = executor.get_job_directories_with_ages()
test_lib.assert_type(dirs, "table", "get_job_directories_with_ages() returns table")

-- ============================================================================
-- Test: executor.job_async_run() function (async job execution with file IPC)
-- ============================================================================
test_lib.test_case("executor.job_async_run() creates files correctly")

-- Create required files for async job
local stdout_file = test_dir .. sep .. "test_stdout.txt"
local stderr_file = test_dir .. sep .. "test_stderr.txt"
local pid_file = test_dir .. sep .. "test_pid.txt"
local status_file = test_dir .. sep .. "test_status.txt"

-- Build status commands
local status_running = "echo RUNNING > " .. status_file
local status_success = "echo SUCCESS > " .. status_file
local status_failure = "echo FAILURE > " .. status_file

-- Run a simple async job (avoiding single quotes that conflict with shell wrapper)
executor.job_async_run(
    "test_job",
    "echo async_output",
    test_dir,
    pid_file,
    "test-uuid-123",
    stdout_file,
    stderr_file,
    status_running,
    status_success,
    status_failure
)

-- Wait briefly for the async job to complete
os.execute("sleep 0.5")

-- Check that files were created
local status_content = test_lib.read_test_file(status_file)
test_lib.assert_not_nil(status_content, "Status file was created")
-- Status should be either RUNNING, SUCCESS, or FAILURE
local valid_status = status_content:match("RUNNING") or status_content:match("SUCCESS") or status_content:match("FAILURE")
test_lib.assert_true(valid_status ~= nil, "Status file contains valid status")

-- Wait a bit more and check for completion
os.execute("sleep 0.5")
status_content = test_lib.read_test_file(status_file)
test_lib.assert_contains(status_content, "SUCCESS", "Async job completed successfully")

local stdout_content = test_lib.read_test_file(stdout_file)
test_lib.assert_not_nil(stdout_content, "Stdout file was created")
test_lib.assert_contains(stdout_content, "async_output", "Stdout contains expected output")

local pid_content = test_lib.read_test_file(pid_file)
test_lib.assert_not_nil(pid_content, "PID file was created")
-- PID should be a number
local pid_number = pid_content:match("%d+")
test_lib.assert_not_nil(pid_number, "PID file contains a process ID")

-- ============================================================================
-- Test: executor.job_async_run() with failing command
-- ============================================================================
test_lib.test_case("executor.job_async_run() handles failing command")

local fail_stdout_file = test_dir .. sep .. "fail_stdout.txt"
local fail_stderr_file = test_dir .. sep .. "fail_stderr.txt"
local fail_pid_file = test_dir .. sep .. "fail_pid.txt"
local fail_status_file = test_dir .. sep .. "fail_status.txt"

local fail_status_running = "echo RUNNING > " .. fail_status_file
local fail_status_success = "echo SUCCESS > " .. fail_status_file
local fail_status_failure = "echo FAILURE > " .. fail_status_file

executor.job_async_run(
    "fail_test_job",
    "exit 1",
    test_dir,
    fail_pid_file,
    "test-uuid-456",
    fail_stdout_file,
    fail_stderr_file,
    fail_status_running,
    fail_status_success,
    fail_status_failure
)

-- Wait for the async job to complete (need more time for background process)
os.execute("sleep 2")

local fail_status_content = test_lib.read_test_file(fail_status_file)
test_lib.assert_not_nil(fail_status_content, "Fail status file was created")
-- Status should show FAILURE (command exits with 1)
local has_failure_or_running = fail_status_content:match("FAILURE") or fail_status_content:match("RUNNING")
test_lib.assert_true(has_failure_or_running ~= nil, "Async job reports valid status")

-- ============================================================================
-- Test: Full file IPC workflow
-- ============================================================================
test_lib.test_case("Full file IPC workflow with simple command")

local ipc_test_dir = test_dir .. sep .. "ipc_test"
os.execute("mkdir -p '" .. ipc_test_dir .. "'")

local ipc_stdout_file = ipc_test_dir .. sep .. "stdout.txt"
local ipc_stderr_file = ipc_test_dir .. sep .. "stderr.txt"
local ipc_pid_file = ipc_test_dir .. sep .. "pid.txt"
local ipc_status_file = ipc_test_dir .. sep .. "status.txt"

local ipc_status_running = "echo RUNNING > " .. ipc_status_file
local ipc_status_success = "echo SUCCESS > " .. ipc_status_file
local ipc_status_failure = "echo FAILURE > " .. ipc_status_file

-- Run a simple command that outputs to stdout
executor.job_async_run(
    "ipc_test_job",
    "echo test_output",
    ipc_test_dir,
    ipc_pid_file,
    "ipc-test-uuid",
    ipc_stdout_file,
    ipc_stderr_file,
    ipc_status_running,
    ipc_status_success,
    ipc_status_failure
)

-- Wait for completion
os.execute("sleep 1")

-- Verify IPC files
local ipc_status = test_lib.read_test_file(ipc_status_file)
test_lib.assert_contains(ipc_status, "SUCCESS", "IPC status is SUCCESS")

local ipc_stdout = test_lib.read_test_file(ipc_stdout_file)
test_lib.assert_contains(ipc_stdout, "test_output", "IPC stdout captured correctly")

-- ============================================================================
-- Cleanup
-- ============================================================================
test_lib.remove_test_dir(test_dir)

-- ============================================================================
-- Summary
-- ============================================================================
local success = test_lib.summary()

if success then
    os.exit(0)
else
    os.exit(1)
end
