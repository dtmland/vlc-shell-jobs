-- test_path_utils.lua
-- Tests for path_utils.lua module

-- Set up package path to find modules
-- Tests are in lua/modules/extensions/tests/, modules are in lua/modules/extensions/
package.path = package.path .. ";./?.lua;../?.lua"

local test_lib = require("test_lib")

-- For testing, we need to set up the module path for extensions
-- In the actual VLC environment, require("extensions.path_utils") works
-- For standalone testing, we load the module directly

-- First preload os_detect which is a dependency of path_utils
package.loaded["extensions.os_detect"] = dofile("../os_detect.lua")

package.loaded["extensions.path_utils"] = nil
local path_utils = dofile("../path_utils.lua")
local os_detect = package.loaded["extensions.os_detect"]

-- ============================================================================
-- Tests
-- ============================================================================

test_lib.suite("path_utils.lua")

-- ============================================================================
-- Test: fix_unix_path function
-- ============================================================================
test_lib.test_case("fix_unix_path() handles various paths")

-- On Unix, it should fix paths missing leading slash
if not os_detect.is_windows() then
    test_lib.assert_equals("/home/user/file.txt", path_utils.fix_unix_path("home/user/file.txt"), 
        "fix_unix_path adds leading slash to home/ path")
    test_lib.assert_equals("/usr/bin/test", path_utils.fix_unix_path("usr/bin/test"), 
        "fix_unix_path adds leading slash to usr/ path")
    test_lib.assert_equals("/tmp/file", path_utils.fix_unix_path("tmp/file"), 
        "fix_unix_path adds leading slash to tmp/ path")
    test_lib.assert_equals("/home/user", path_utils.fix_unix_path("/home/user"), 
        "fix_unix_path preserves already correct path")
    test_lib.assert_equals("relative/path", path_utils.fix_unix_path("relative/path"), 
        "fix_unix_path preserves relative path without known root")
else
    -- On Windows, it should return paths unchanged
    test_lib.assert_equals("home/user/file.txt", path_utils.fix_unix_path("home/user/file.txt"), 
        "fix_unix_path returns unchanged on Windows")
end

-- Test edge cases
test_lib.assert_equals(nil, path_utils.fix_unix_path(nil), "fix_unix_path handles nil")
test_lib.assert_equals("", path_utils.fix_unix_path(""), "fix_unix_path handles empty string")

-- ============================================================================
-- Test: get_macos_path_prefix function
-- ============================================================================
test_lib.test_case("get_macos_path_prefix() returns correct value")

local prefix = path_utils.get_macos_path_prefix()
test_lib.assert_type(prefix, "string", "get_macos_path_prefix() returns string")

if os_detect.is_macos() then
    test_lib.assert_contains(prefix, "export PATH=", "macOS prefix contains export PATH")
    test_lib.assert_contains(prefix, "/usr/local/bin", "macOS prefix contains /usr/local/bin")
    test_lib.assert_contains(prefix, "/opt/homebrew/bin", "macOS prefix contains /opt/homebrew/bin")
else
    test_lib.assert_equals("", prefix, "get_macos_path_prefix() returns empty string on non-macOS")
end

-- ============================================================================
-- Test: parse_path function
-- ============================================================================
test_lib.test_case("parse_path() extracts path components")

local dir, basename, basename_without_ext

-- Test with a typical file path
if os_detect.is_windows() then
    dir, basename, basename_without_ext = path_utils.parse_path("C:\\Users\\test\\file.txt")
    test_lib.assert_equals("C:\\Users\\test\\", dir, "parse_path extracts Windows directory")
    test_lib.assert_equals("file.txt", basename, "parse_path extracts Windows basename")
    test_lib.assert_equals("file", basename_without_ext, "parse_path extracts Windows basename without ext")
else
    dir, basename, basename_without_ext = path_utils.parse_path("/home/user/file.txt")
    test_lib.assert_equals("/home/user/", dir, "parse_path extracts Unix directory")
    test_lib.assert_equals("file.txt", basename, "parse_path extracts Unix basename")
    test_lib.assert_equals("file", basename_without_ext, "parse_path extracts Unix basename without ext")
end

-- Test edge cases
dir, basename, basename_without_ext = path_utils.parse_path("")
test_lib.assert_equals("", dir, "parse_path handles empty path - dir")
test_lib.assert_equals("", basename, "parse_path handles empty path - basename")
test_lib.assert_equals("", basename_without_ext, "parse_path handles empty path - basename_without_ext")

dir, basename, basename_without_ext = path_utils.parse_path(nil)
test_lib.assert_equals("", dir, "parse_path handles nil - dir")
test_lib.assert_equals("", basename, "parse_path handles nil - basename")
test_lib.assert_equals("", basename_without_ext, "parse_path handles nil - basename_without_ext")

-- ============================================================================
-- Summary
-- ============================================================================
local success = test_lib.summary()

if success then
    os.exit(0)
else
    os.exit(1)
end
