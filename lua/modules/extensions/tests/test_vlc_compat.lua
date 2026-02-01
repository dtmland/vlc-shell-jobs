-- test_vlc_compat.lua
-- Tests for vlc_compat.lua module

-- Set up package path to find modules
-- Tests are in lua/modules/extensions/tests/, modules are in lua/modules/extensions/
package.path = package.path .. ";./?.lua;../?.lua"

local test_lib = require("test_lib")

-- Load the vlc_compat module
local vlc_compat = dofile("../vlc_compat.lua")

-- ============================================================================
-- Tests
-- ============================================================================

test_lib.suite("vlc_compat.lua")

-- ============================================================================
-- Test: Module structure
-- ============================================================================
test_lib.test_case("Module exports expected functions")
test_lib.assert_not_nil(vlc_compat.is_vlc_available, "is_vlc_available() exists")
test_lib.assert_not_nil(vlc_compat.get_vlc, "get_vlc() exists")
test_lib.assert_not_nil(vlc_compat.get_mock_vlc, "get_mock_vlc() exists")
test_lib.assert_not_nil(vlc_compat.enable_debug_logging, "enable_debug_logging() exists")
test_lib.assert_not_nil(vlc_compat.disable_debug_logging, "disable_debug_logging() exists")

-- ============================================================================
-- Test: is_vlc_available() returns false in standalone Lua
-- ============================================================================
test_lib.test_case("is_vlc_available() returns false in standalone Lua")
local is_available = vlc_compat.is_vlc_available()
test_lib.assert_type(is_available, "boolean", "is_vlc_available() returns boolean")
test_lib.assert_false(is_available, "is_vlc_available() returns false (running standalone)")

-- ============================================================================
-- Test: get_vlc() returns mock when VLC not available
-- ============================================================================
test_lib.test_case("get_vlc() returns mock VLC object")
local vlc_obj = vlc_compat.get_vlc()
test_lib.assert_not_nil(vlc_obj, "get_vlc() returns object")
test_lib.assert_type(vlc_obj, "table", "get_vlc() returns table")

-- ============================================================================
-- Test: Mock VLC has expected structure
-- ============================================================================
test_lib.test_case("Mock VLC has msg namespace")
test_lib.assert_not_nil(vlc_obj.msg, "Mock VLC has msg")
test_lib.assert_type(vlc_obj.msg, "table", "msg is a table")

test_lib.test_case("Mock VLC msg has logging functions")
test_lib.assert_not_nil(vlc_obj.msg.dbg, "msg.dbg exists")
test_lib.assert_not_nil(vlc_obj.msg.info, "msg.info exists")
test_lib.assert_not_nil(vlc_obj.msg.warn, "msg.warn exists")
test_lib.assert_not_nil(vlc_obj.msg.err, "msg.err exists")

test_lib.assert_type(vlc_obj.msg.dbg, "function", "msg.dbg is function")
test_lib.assert_type(vlc_obj.msg.info, "function", "msg.info is function")
test_lib.assert_type(vlc_obj.msg.warn, "function", "msg.warn is function")
test_lib.assert_type(vlc_obj.msg.err, "function", "msg.err is function")

-- ============================================================================
-- Test: Mock VLC has io namespace
-- ============================================================================
test_lib.test_case("Mock VLC has io namespace")
test_lib.assert_not_nil(vlc_obj.io, "Mock VLC has io")
test_lib.assert_type(vlc_obj.io, "table", "io is a table")

test_lib.test_case("Mock VLC io has required functions")
test_lib.assert_not_nil(vlc_obj.io.open, "io.open exists")
test_lib.assert_not_nil(vlc_obj.io.mkdir, "io.mkdir exists")

test_lib.assert_type(vlc_obj.io.open, "function", "io.open is function")
test_lib.assert_type(vlc_obj.io.mkdir, "function", "io.mkdir is function")

-- ============================================================================
-- Test: Mock VLC logging functions can be called
-- ============================================================================
test_lib.test_case("Mock VLC logging functions can be called without error")
-- These should not throw errors
local success_dbg = pcall(function() vlc_obj.msg.dbg("test debug message") end)
local success_info = pcall(function() vlc_obj.msg.info("test info message") end)
local success_warn = pcall(function() vlc_obj.msg.warn("test warn message") end)
local success_err = pcall(function() vlc_obj.msg.err("test error message") end)

test_lib.assert_true(success_dbg, "msg.dbg() callable without error")
test_lib.assert_true(success_info, "msg.info() callable without error")
test_lib.assert_true(success_warn, "msg.warn() callable without error")
test_lib.assert_true(success_err, "msg.err() callable without error")

-- ============================================================================
-- Test: Mock VLC io.open works
-- ============================================================================
test_lib.test_case("Mock VLC io.open works for file operations")
local test_dir = test_lib.create_test_dir("vlc_compat_test")
local sep = test_lib.get_path_separator()
local test_file = test_dir .. sep .. "test.txt"

-- Write using mock io.open
local file = vlc_obj.io.open(test_file, "w")
test_lib.assert_not_nil(file, "io.open() opens file for writing")
if file then
    file:write("test content")
    file:close()
end

-- Read back
file = vlc_obj.io.open(test_file, "r")
test_lib.assert_not_nil(file, "io.open() opens file for reading")
if file then
    local content = file:read("*all")
    file:close()
    test_lib.assert_equals("test content", content, "File content matches what was written")
end

-- ============================================================================
-- Test: Mock VLC io.mkdir works
-- ============================================================================
test_lib.test_case("Mock VLC io.mkdir creates directories")
local new_dir = test_dir .. sep .. "new_subdir"

local result, err = vlc_obj.io.mkdir(new_dir, "0755")
test_lib.assert_equals(0, result, "io.mkdir() returns 0 on success")

-- Verify directory was created by writing a file in it
local file_in_new_dir = new_dir .. sep .. "test.txt"
file = io.open(file_in_new_dir, "w")
test_lib.assert_not_nil(file, "Can write to newly created directory")
if file then
    file:close()
end

-- ============================================================================
-- Test: Mock VLC io.mkdir handles existing directory
-- ============================================================================
test_lib.test_case("Mock VLC io.mkdir handles existing directory")
local result2, err2 = vlc_obj.io.mkdir(new_dir, "0755")
-- Should return EEXIST (17) for existing directory
test_lib.assert_not_nil(result2, "io.mkdir() returns result for existing dir")

-- ============================================================================
-- Test: get_mock_vlc() returns the mock object
-- ============================================================================
test_lib.test_case("get_mock_vlc() returns the mock object")
local mock = vlc_compat.get_mock_vlc()
test_lib.assert_not_nil(mock, "get_mock_vlc() returns object")
test_lib.assert_type(mock, "table", "get_mock_vlc() returns table")
test_lib.assert_not_nil(mock.msg, "mock has msg")
test_lib.assert_not_nil(mock.io, "mock has io")

-- ============================================================================
-- Test: Debug logging toggle
-- ============================================================================
test_lib.test_case("Debug logging can be enabled and disabled")
-- Should not throw errors
local success_enable = pcall(function() vlc_compat.enable_debug_logging() end)
local success_disable = pcall(function() vlc_compat.disable_debug_logging() end)

test_lib.assert_true(success_enable, "enable_debug_logging() callable without error")
test_lib.assert_true(success_disable, "disable_debug_logging() callable without error")

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
