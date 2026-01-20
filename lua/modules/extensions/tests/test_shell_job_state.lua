-- test_shell_job_state.lua
-- Tests for shell_job_state.lua module

-- Set up package path to find modules
-- Tests are in lua/modules/extensions/tests/, modules are in lua/modules/extensions/
package.path = package.path .. ";./?.lua;../?.lua"

local test_lib = require("test_lib")

-- Load the modules - simulate the VLC extensions path
package.loaded["extensions.shell_job_defs"] = dofile("../shell_job_defs.lua")
package.loaded["extensions.shell_operator_fileio"] = dofile("../shell_operator_fileio.lua")
local state_module = dofile("../shell_job_state.lua")

-- ============================================================================
-- Test Setup
-- ============================================================================

local test_dir = test_lib.create_test_dir("vlc_shell_jobs_state_test")
local sep = test_lib.get_path_separator()

local function write_test_file(filename, content)
    return test_lib.write_test_file(test_dir, filename, content)
end

local function build_file_paths()
    return {
        status = test_dir .. sep .. "job_status.txt",
        uuid = test_dir .. sep .. "job_uuid.txt",
        pid = test_dir .. sep .. "job_pid.txt",
        stdout = test_dir .. sep .. "stdout.txt",
        stderr = test_dir .. sep .. "stderr.txt"
    }
end

-- ============================================================================
-- Tests
-- ============================================================================

test_lib.suite("shell_job_state.lua")

-- ============================================================================
-- Test: STATES constants are defined
-- ============================================================================
test_lib.test_case("STATES constants are defined")
test_lib.assert_equals("NO_JOB", state_module.STATES.NO_JOB, "STATES.NO_JOB defined")
test_lib.assert_equals("PENDING", state_module.STATES.PENDING, "STATES.PENDING defined")
test_lib.assert_equals("RUNNING", state_module.STATES.RUNNING, "STATES.RUNNING defined")
test_lib.assert_equals("SUCCESS", state_module.STATES.SUCCESS, "STATES.SUCCESS defined")
test_lib.assert_equals("FAILURE", state_module.STATES.FAILURE, "STATES.FAILURE defined")

-- ============================================================================
-- Test: State machine creation
-- ============================================================================
test_lib.test_case("State machine can be instantiated")
local file_paths = build_file_paths()
local job_state = state_module.new(file_paths, "test-uuid-123")
test_lib.assert_not_nil(job_state, "State machine instance created")
test_lib.assert_type(job_state, "table", "State machine is a table")

-- ============================================================================
-- Test: NO_JOB state when UUID doesn't match
-- ============================================================================
test_lib.test_case("get_state() returns NO_JOB when UUID doesn't match")

-- Write a different UUID than expected
write_test_file("job_uuid.txt", "different-uuid")
write_test_file("job_status.txt", "RUNNING")

local state = job_state.get_state()
test_lib.assert_equals(state_module.STATES.NO_JOB, state, "State is NO_JOB when UUID doesn't match")
test_lib.assert_true(job_state.is_no_job(), "is_no_job() returns true")
test_lib.assert_false(job_state.is_running(), "is_running() returns false")

-- ============================================================================
-- Test: PENDING state when UUID matches but status is empty
-- ============================================================================
test_lib.test_case("get_state() returns PENDING when status is empty")

write_test_file("job_uuid.txt", "test-uuid-123")
write_test_file("job_status.txt", "")

state = job_state.get_state()
test_lib.assert_equals(state_module.STATES.PENDING, state, "State is PENDING when status empty")
test_lib.assert_true(job_state.is_pending(), "is_pending() returns true")
test_lib.assert_false(job_state.is_running(), "is_running() returns false")
test_lib.assert_true(job_state.is_active(), "is_active() returns true for pending")

-- ============================================================================
-- Test: RUNNING state
-- ============================================================================
test_lib.test_case("get_state() returns RUNNING when status is RUNNING")

write_test_file("job_uuid.txt", "test-uuid-123")
write_test_file("job_status.txt", "RUNNING")

state = job_state.get_state()
test_lib.assert_equals(state_module.STATES.RUNNING, state, "State is RUNNING")
test_lib.assert_true(job_state.is_running(), "is_running() returns true")
test_lib.assert_false(job_state.is_finished(), "is_finished() returns false")
test_lib.assert_true(job_state.is_active(), "is_active() returns true for running")

-- ============================================================================
-- Test: SUCCESS state
-- ============================================================================
test_lib.test_case("get_state() returns SUCCESS when status is SUCCESS")

write_test_file("job_uuid.txt", "test-uuid-123")
write_test_file("job_status.txt", "SUCCESS")

state = job_state.get_state()
test_lib.assert_equals(state_module.STATES.SUCCESS, state, "State is SUCCESS")
test_lib.assert_true(job_state.is_success(), "is_success() returns true")
test_lib.assert_true(job_state.is_finished(), "is_finished() returns true")
test_lib.assert_false(job_state.is_active(), "is_active() returns false for finished")

-- ============================================================================
-- Test: FAILURE state
-- ============================================================================
test_lib.test_case("get_state() returns FAILURE when status is FAILURE")

write_test_file("job_uuid.txt", "test-uuid-123")
write_test_file("job_status.txt", "FAILURE")

state = job_state.get_state()
test_lib.assert_equals(state_module.STATES.FAILURE, state, "State is FAILURE")
test_lib.assert_true(job_state.is_failure(), "is_failure() returns true")
test_lib.assert_true(job_state.is_finished(), "is_finished() returns true")

-- ============================================================================
-- Test: can_run() action availability
-- ============================================================================
test_lib.test_case("can_run() returns correct values for each state")

-- NO_JOB state - can run
write_test_file("job_uuid.txt", "different-uuid")
test_lib.assert_true(job_state.can_run(), "can_run() is true for NO_JOB")

-- PENDING state - cannot run
write_test_file("job_uuid.txt", "test-uuid-123")
write_test_file("job_status.txt", "")
test_lib.assert_false(job_state.can_run(), "can_run() is false for PENDING")

-- RUNNING state - cannot run
write_test_file("job_status.txt", "RUNNING")
test_lib.assert_false(job_state.can_run(), "can_run() is false for RUNNING")

-- SUCCESS state - can run
write_test_file("job_status.txt", "SUCCESS")
test_lib.assert_true(job_state.can_run(), "can_run() is true for SUCCESS")

-- FAILURE state - can run
write_test_file("job_status.txt", "FAILURE")
test_lib.assert_true(job_state.can_run(), "can_run() is true for FAILURE")

-- ============================================================================
-- Test: can_abort() action availability
-- ============================================================================
test_lib.test_case("can_abort() returns correct values for each state")

-- RUNNING state - can abort
write_test_file("job_uuid.txt", "test-uuid-123")
write_test_file("job_status.txt", "RUNNING")
test_lib.assert_true(job_state.can_abort(), "can_abort() is true for RUNNING")

-- PENDING state - cannot abort
write_test_file("job_status.txt", "")
test_lib.assert_false(job_state.can_abort(), "can_abort() is false for PENDING")

-- SUCCESS state - cannot abort
write_test_file("job_status.txt", "SUCCESS")
test_lib.assert_false(job_state.can_abort(), "can_abort() is false for SUCCESS")

-- ============================================================================
-- Test: get_run_blocked_reason() returns correct messages
-- ============================================================================
test_lib.test_case("get_run_blocked_reason() returns correct messages")

-- PENDING state
write_test_file("job_uuid.txt", "test-uuid-123")
write_test_file("job_status.txt", "")
local reason = job_state.get_run_blocked_reason()
test_lib.assert_not_nil(reason, "Blocked reason exists for PENDING")
test_lib.assert_contains(reason, "pending", "Blocked reason mentions pending")

-- RUNNING state
write_test_file("job_status.txt", "RUNNING")
reason = job_state.get_run_blocked_reason()
test_lib.assert_not_nil(reason, "Blocked reason exists for RUNNING")
test_lib.assert_contains(reason, "running", "Blocked reason mentions running")

-- SUCCESS state - no block
write_test_file("job_status.txt", "SUCCESS")
reason = job_state.get_run_blocked_reason()
test_lib.assert_nil(reason, "No blocked reason for SUCCESS")

-- ============================================================================
-- Test: get_abort_blocked_reason() returns correct messages
-- ============================================================================
test_lib.test_case("get_abort_blocked_reason() returns correct messages")

-- NO_JOB state
write_test_file("job_uuid.txt", "different-uuid")
local reason = job_state.get_abort_blocked_reason()
test_lib.assert_not_nil(reason, "Blocked reason exists for NO_JOB")
test_lib.assert_contains(reason, "No job", "Blocked reason mentions no job")

-- SUCCESS state
write_test_file("job_uuid.txt", "test-uuid-123")
write_test_file("job_status.txt", "SUCCESS")
reason = job_state.get_abort_blocked_reason()
test_lib.assert_not_nil(reason, "Blocked reason exists for finished job")
test_lib.assert_contains(reason, "finished", "Blocked reason mentions finished")

-- RUNNING state - no block
write_test_file("job_status.txt", "RUNNING")
reason = job_state.get_abort_blocked_reason()
test_lib.assert_nil(reason, "No blocked reason for RUNNING")

-- ============================================================================
-- Test: set_uuid() updates the expected UUID
-- ============================================================================
test_lib.test_case("set_uuid() updates the expected UUID")

write_test_file("job_uuid.txt", "new-uuid-456")
write_test_file("job_status.txt", "RUNNING")

-- Before update - should be NO_JOB because UUID doesn't match
state = job_state.get_state()
test_lib.assert_equals(state_module.STATES.NO_JOB, state, "State is NO_JOB before UUID update")

-- Update UUID
job_state.set_uuid("new-uuid-456")

-- After update - should be RUNNING
state = job_state.get_state()
test_lib.assert_equals(state_module.STATES.RUNNING, state, "State is RUNNING after UUID update")

-- ============================================================================
-- Test: get_uuid() returns current expected UUID
-- ============================================================================
test_lib.test_case("get_uuid() returns current expected UUID")
test_lib.assert_equals("new-uuid-456", job_state.get_uuid(), "get_uuid() returns expected UUID")

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
