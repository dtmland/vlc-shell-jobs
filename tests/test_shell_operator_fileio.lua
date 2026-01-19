-- test_shell_operator_fileio.lua
-- Tests for shell_operator_fileio.lua module

-- Set up package path to find modules
package.path = package.path .. ";../?.lua;./?.lua"

local test_lib = require("tests.test_lib")

-- Load the modules
package.loaded["extensions.shell_job_defs"] = dofile("shell_job_defs.lua")
local fileio_module = dofile("shell_operator_fileio.lua")

-- ============================================================================
-- Test Setup
-- ============================================================================

local test_dir = test_lib.create_test_dir("vlc_shell_jobs_fileio_test")
local sep = test_lib.get_path_separator()

local function write_test_file(filename, content)
    return test_lib.write_test_file(test_dir, filename, content)
end

-- ============================================================================
-- Tests
-- ============================================================================

test_lib.suite("shell_operator_fileio.lua")

-- ============================================================================
-- Test: Module creation
-- ============================================================================
test_lib.test_case("Module can be instantiated")
local fileio = fileio_module.new()
test_lib.assert_not_nil(fileio, "fileio instance created")
test_lib.assert_type(fileio, "table", "fileio is a table")

-- ============================================================================
-- Test: read_status function
-- ============================================================================
test_lib.test_case("read_status() reads status file correctly")

-- Create a status file with "RUNNING"
local status_file = write_test_file("job_status.txt", "RUNNING\n")
test_lib.assert_not_nil(status_file, "Created test status file")

local status = fileio.read_status(status_file)
test_lib.assert_equals("RUNNING", status, "read_status returns trimmed content")

-- Test with different statuses
write_test_file("job_status.txt", "SUCCESS ")
status = fileio.read_status(status_file)
test_lib.assert_equals("SUCCESS", status, "read_status trims whitespace")

write_test_file("job_status.txt", "  FAILURE  \n")
status = fileio.read_status(status_file)
test_lib.assert_equals("FAILURE", status, "read_status trims all whitespace")

-- ============================================================================
-- Test: read_uuid function
-- ============================================================================
test_lib.test_case("read_uuid() reads UUID file correctly")

local uuid_file = write_test_file("job_uuid.txt", "abc123-uuid-test")
local uuid = fileio.read_uuid(uuid_file)
test_lib.assert_equals("abc123-uuid-test", uuid, "read_uuid returns correct UUID")

-- ============================================================================
-- Test: read_pid function
-- ============================================================================
test_lib.test_case("read_pid() reads PID file correctly")

local pid_file = write_test_file("job_pid.txt", "12345\n")
local pid = fileio.read_pid(pid_file)
test_lib.assert_equals("12345", pid, "read_pid returns trimmed PID")

-- ============================================================================
-- Test: read_stdout function
-- ============================================================================
test_lib.test_case("read_stdout() reads stdout file correctly")

local stdout_file = write_test_file("stdout.txt", "Hello\nWorld\n")
local stdout = fileio.read_stdout(stdout_file)
test_lib.assert_contains(stdout, "Hello", "stdout contains Hello")
test_lib.assert_contains(stdout, "World", "stdout contains World")

-- ============================================================================
-- Test: read_stderr function
-- ============================================================================
test_lib.test_case("read_stderr() reads stderr file correctly")

local stderr_file = write_test_file("stderr.txt", "Error message")
local stderr = fileio.read_stderr(stderr_file)
test_lib.assert_contains(stderr, "Error message", "stderr contains error message")

-- ============================================================================
-- Test: write_uuid function
-- ============================================================================
test_lib.test_case("write_uuid() writes UUID file correctly")

local new_uuid_file = test_dir .. sep .. "new_uuid.txt"
local success = fileio.write_uuid(new_uuid_file, "new-uuid-value")
test_lib.assert_true(success, "write_uuid returns true on success")

local read_uuid = fileio.read_uuid(new_uuid_file)
test_lib.assert_equals("new-uuid-value", read_uuid, "Written UUID can be read back")

-- ============================================================================
-- Test: safe_read function
-- ============================================================================
test_lib.test_case("safe_read() returns default for missing files")

local nonexistent_file = test_dir .. sep .. "nonexistent.txt"
local content = fileio.safe_read(nonexistent_file, "default_value")
test_lib.assert_equals("default_value", content, "safe_read returns default for missing file")

-- Test with existing file
local existing_file = write_test_file("existing.txt", "actual content")
content = fileio.safe_read(existing_file, "default_value")
test_lib.assert_equals("actual content", content, "safe_read returns actual content for existing file")

-- ============================================================================
-- Test: get_pretty_status function
-- ============================================================================
test_lib.test_case("get_pretty_status() formats output correctly")

-- Create test files
write_test_file("job_status.txt", "RUNNING")
write_test_file("stdout.txt", "output text")
write_test_file("stderr.txt", "error text")

local file_paths = {
    status = test_dir .. sep .. "job_status.txt",
    stdout = test_dir .. sep .. "stdout.txt",
    stderr = test_dir .. sep .. "stderr.txt"
}

local pretty = fileio.get_pretty_status(file_paths)
test_lib.assert_type(pretty, "string", "get_pretty_status returns string")
test_lib.assert_contains(pretty, "Job Status:", "Contains Job Status label")
test_lib.assert_contains(pretty, "Standard Output:", "Contains Standard Output label")
test_lib.assert_contains(pretty, "Standard Error:", "Contains Standard Error label")
test_lib.assert_contains(pretty, "RUNNING", "Contains status value")
test_lib.assert_contains(pretty, "output text", "Contains stdout value")
test_lib.assert_contains(pretty, "error text", "Contains stderr value")

-- ============================================================================
-- Test: Empty/missing files return empty string for reads
-- ============================================================================
test_lib.test_case("Read functions return empty string for empty files")

write_test_file("empty.txt", "")
local empty_file = test_dir .. sep .. "empty.txt"
local empty_content = fileio.read_status(empty_file)
test_lib.assert_equals("", empty_content, "read_status returns empty string for empty file")

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
