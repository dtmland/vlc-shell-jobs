-- test_os_detect.lua
-- Tests for os_detect.lua module

-- Set up package path to find modules
-- Tests are in lua/modules/extensions/tests/, modules are in lua/modules/extensions/
package.path = package.path .. ";./?.lua;../?.lua"

local test_lib = require("test_lib")

-- For testing, we load the module directly
local os_detect = dofile("../os_detect.lua")

-- ============================================================================
-- Tests
-- ============================================================================

test_lib.suite("os_detect.lua")

-- ============================================================================
-- Test: is_windows function
-- ============================================================================
test_lib.test_case("is_windows() returns boolean")
local is_win = os_detect.is_windows()
test_lib.assert_type(is_win, "boolean", "is_windows() returns boolean")

-- ============================================================================
-- Test: is_macos function
-- ============================================================================
test_lib.test_case("is_macos() returns boolean")
local is_mac = os_detect.is_macos()
test_lib.assert_type(is_mac, "boolean", "is_macos() returns boolean")

-- ============================================================================
-- Test: is_unix function
-- ============================================================================
test_lib.test_case("is_unix() returns boolean")
local is_nix = os_detect.is_unix()
test_lib.assert_type(is_nix, "boolean", "is_unix() returns boolean")

-- ============================================================================
-- Test: is_linux function
-- ============================================================================
test_lib.test_case("is_linux() returns boolean")
local is_lin = os_detect.is_linux()
test_lib.assert_type(is_lin, "boolean", "is_linux() returns boolean")

-- ============================================================================
-- Test: Platform consistency checks
-- ============================================================================
test_lib.test_case("Platform detection is consistent")

-- Windows and Unix should be mutually exclusive
if os_detect.is_windows() then
    test_lib.assert_equals(false, os_detect.is_unix(), "Windows means not Unix")
    test_lib.assert_equals(false, os_detect.is_macos(), "Windows means not macOS")
    test_lib.assert_equals(false, os_detect.is_linux(), "Windows means not Linux")
else
    test_lib.assert_equals(true, os_detect.is_unix(), "Not Windows means Unix")
end

-- If macOS, then Unix but not Linux
if os_detect.is_macos() then
    test_lib.assert_equals(true, os_detect.is_unix(), "macOS is Unix")
    test_lib.assert_equals(false, os_detect.is_linux(), "macOS is not Linux")
end

-- If Linux, then Unix but not macOS
if os_detect.is_linux() then
    test_lib.assert_equals(true, os_detect.is_unix(), "Linux is Unix")
    test_lib.assert_equals(false, os_detect.is_macos(), "Linux is not macOS")
end

-- ============================================================================
-- Test: get_path_separator function
-- ============================================================================
test_lib.test_case("get_path_separator() returns valid separator")
local sep = os_detect.get_path_separator()
test_lib.assert_type(sep, "string", "get_path_separator() returns string")
if os_detect.is_windows() then
    test_lib.assert_equals("\\", sep, "Windows path separator is backslash")
else
    test_lib.assert_equals("/", sep, "Unix path separator is forward slash")
end

-- ============================================================================
-- Test: Caching works (call functions multiple times)
-- ============================================================================
test_lib.test_case("Detection caching works")
local win1 = os_detect.is_windows()
local win2 = os_detect.is_windows()
test_lib.assert_equals(win1, win2, "is_windows() returns consistent results")

local mac1 = os_detect.is_macos()
local mac2 = os_detect.is_macos()
test_lib.assert_equals(mac1, mac2, "is_macos() returns consistent results")

-- ============================================================================
-- Summary
-- ============================================================================
local success = test_lib.summary()

if success then
    os.exit(0)
else
    os.exit(1)
end
