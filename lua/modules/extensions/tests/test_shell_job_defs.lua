-- test_shell_job_defs.lua
-- Tests for shell_job_defs.lua module

-- Set up package path to find modules
-- Tests are in lua/modules/extensions/tests/, modules are in lua/modules/extensions/
package.path = package.path .. ";./?.lua;../?.lua"

local test_lib = require("test_lib")

-- For testing, we need to set up the module path for extensions
-- In the actual VLC environment, require("extensions.shell_job_defs") works
-- For standalone testing, we load the module directly
package.loaded["extensions.shell_job_defs"] = nil
local defs = dofile("../shell_job_defs.lua")

-- ============================================================================
-- Tests
-- ============================================================================

test_lib.suite("shell_job_defs.lua")

-- ============================================================================
-- Test: STATUS constants
-- ============================================================================
test_lib.test_case("STATUS constants are defined correctly")
test_lib.assert_equals("RUNNING", defs.STATUS.RUNNING, "STATUS.RUNNING constant")
test_lib.assert_equals("SUCCESS", defs.STATUS.SUCCESS, "STATUS.SUCCESS constant")
test_lib.assert_equals("FAILURE", defs.STATUS.FAILURE, "STATUS.FAILURE constant")

-- ============================================================================
-- Test: FILES constants
-- ============================================================================
test_lib.test_case("FILES constants are defined correctly")
test_lib.assert_equals("job_status.txt", defs.FILES.STATUS, "FILES.STATUS constant")
test_lib.assert_equals("job_uuid.txt", defs.FILES.UUID, "FILES.UUID constant")
test_lib.assert_equals("job_pid.txt", defs.FILES.PID, "FILES.PID constant")
test_lib.assert_equals("stdout.txt", defs.FILES.STDOUT, "FILES.STDOUT constant")
test_lib.assert_equals("stderr.txt", defs.FILES.STDERR, "FILES.STDERR constant")

-- ============================================================================
-- Test: DEFAULTS constants
-- ============================================================================
test_lib.test_case("DEFAULTS constants are defined correctly")
test_lib.assert_equals(86400, defs.DEFAULTS.CLEANUP_AGE_SECONDS, "DEFAULTS.CLEANUP_AGE_SECONDS is 1 day")

-- ============================================================================
-- Test: is_windows function
-- ============================================================================
test_lib.test_case("is_windows() returns boolean")
local is_win = defs.is_windows()
test_lib.assert_type(is_win, "boolean", "is_windows() returns boolean")

-- ============================================================================
-- Test: get_path_separator function
-- ============================================================================
test_lib.test_case("get_path_separator() returns valid separator")
local sep = defs.get_path_separator()
test_lib.assert_type(sep, "string", "get_path_separator() returns string")
if defs.is_windows() then
    test_lib.assert_equals("\\", sep, "Windows path separator is backslash")
else
    test_lib.assert_equals("/", sep, "Unix path separator is forward slash")
end

-- ============================================================================
-- Test: join_path function
-- ============================================================================
test_lib.test_case("join_path() joins paths correctly")
local joined = defs.join_path("a", "b", "c")
test_lib.assert_type(joined, "string", "join_path() returns string")
if defs.is_windows() then
    test_lib.assert_equals("a\\b\\c", joined, "Windows path joining")
else
    test_lib.assert_equals("a/b/c", joined, "Unix path joining")
end

-- ============================================================================
-- Test: get_default_command_directory function
-- ============================================================================
test_lib.test_case("get_default_command_directory() returns a directory")
local default_dir = defs.get_default_command_directory()
test_lib.assert_not_nil(default_dir, "Default command directory is set")
test_lib.assert_type(default_dir, "string", "Default command directory is string")

-- ============================================================================
-- Test: get_jobrunner_base_directory function
-- ============================================================================
test_lib.test_case("get_jobrunner_base_directory() returns correct path")
local base_dir = defs.get_jobrunner_base_directory()
test_lib.assert_not_nil(base_dir, "Base directory is set")
test_lib.assert_type(base_dir, "string", "Base directory is string")
test_lib.assert_contains(base_dir, "jobrunner", "Base directory contains 'jobrunner'")

-- ============================================================================
-- Test: build_internals_directory function
-- ============================================================================
test_lib.test_case("build_internals_directory() builds correct path")
local instance_id = "12345"
local internals = defs.build_internals_directory(instance_id)
test_lib.assert_not_nil(internals, "Internals directory is set")
test_lib.assert_contains(internals, instance_id, "Internals directory contains instance_id")
test_lib.assert_contains(internals, "jobrunner", "Internals directory contains 'jobrunner'")

-- ============================================================================
-- Test: build_file_paths function
-- ============================================================================
test_lib.test_case("build_file_paths() returns all required paths")
local internals_dir = "/tmp/test/internals"
local paths = defs.build_file_paths(internals_dir)

test_lib.assert_type(paths, "table", "build_file_paths() returns table")
test_lib.assert_table_has_key(paths, "status", "paths has 'status' key")
test_lib.assert_table_has_key(paths, "uuid", "paths has 'uuid' key")
test_lib.assert_table_has_key(paths, "pid", "paths has 'pid' key")
test_lib.assert_table_has_key(paths, "stdout", "paths has 'stdout' key")
test_lib.assert_table_has_key(paths, "stderr", "paths has 'stderr' key")

test_lib.assert_contains(paths.status, internals_dir, "status path contains internals dir")
test_lib.assert_contains(paths.status, "job_status.txt", "status path contains filename")
test_lib.assert_contains(paths.uuid, "job_uuid.txt", "uuid path contains filename")
test_lib.assert_contains(paths.pid, "job_pid.txt", "pid path contains filename")
test_lib.assert_contains(paths.stdout, "stdout.txt", "stdout path contains filename")
test_lib.assert_contains(paths.stderr, "stderr.txt", "stderr path contains filename")

-- ============================================================================
-- Summary
-- ============================================================================
local success = test_lib.summary()

if success then
    os.exit(0)
else
    os.exit(1)
end
