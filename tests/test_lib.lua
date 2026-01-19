-- test_lib.lua
-- Simple test framework for Lua modules
-- This provides basic test assertion functions without external dependencies

local test_lib = {}

-- Test counters
local tests_passed = 0
local tests_failed = 0
local tests_skipped = 0
local current_suite = ""

-- ANSI colors (works on Unix/Linux terminals and Windows 10+)
local GREEN = "\27[32m"
local RED = "\27[31m"
local YELLOW = "\27[33m"
local CYAN = "\27[36m"
local RESET = "\27[0m"

-- ============================================================================
-- Test Framework Functions
-- ============================================================================

function test_lib.suite(name)
    current_suite = name
    print("")
    print("============================================================================")
    print(CYAN .. "TEST SUITE: " .. name .. RESET)
    print("============================================================================")
    print("")
end

function test_lib.test_case(name)
    print("--- TEST: " .. name .. " ---")
end

function test_lib.pass(message)
    tests_passed = tests_passed + 1
    print(GREEN .. "  PASS: " .. message .. RESET)
end

function test_lib.fail(message)
    tests_failed = tests_failed + 1
    print(RED .. "  FAIL: " .. message .. RESET)
end

function test_lib.skip(message)
    tests_skipped = tests_skipped + 1
    print(YELLOW .. "  SKIP: " .. message .. RESET)
end

function test_lib.info(message)
    print("  INFO: " .. message)
end

function test_lib.summary()
    print("")
    print("============================================================================")
    print("TEST SUMMARY")
    print("============================================================================")
    print("  Passed:  " .. GREEN .. tests_passed .. RESET)
    print("  Failed:  " .. RED .. tests_failed .. RESET)
    print("  Skipped: " .. YELLOW .. tests_skipped .. RESET)
    print("  Total:   " .. (tests_passed + tests_failed + tests_skipped))
    print("============================================================================")
    
    if tests_failed > 0 then
        print(RED .. "RESULT: SOME TESTS FAILED" .. RESET)
        return false
    else
        print(GREEN .. "RESULT: ALL TESTS PASSED" .. RESET)
        return true
    end
end

function test_lib.reset()
    tests_passed = 0
    tests_failed = 0
    tests_skipped = 0
    current_suite = ""
end

function test_lib.get_passed()
    return tests_passed
end

function test_lib.get_failed()
    return tests_failed
end

-- ============================================================================
-- Assertion Functions
-- ============================================================================

function test_lib.assert_equals(expected, actual, description)
    if expected == actual then
        test_lib.pass(description .. " - Got expected value: " .. tostring(expected))
        return true
    else
        test_lib.fail(description .. " - Expected: " .. tostring(expected) .. ", Got: " .. tostring(actual))
        return false
    end
end

function test_lib.assert_not_equals(not_expected, actual, description)
    if not_expected ~= actual then
        test_lib.pass(description .. " - Value is not: " .. tostring(not_expected))
        return true
    else
        test_lib.fail(description .. " - Should not equal: " .. tostring(not_expected))
        return false
    end
end

function test_lib.assert_true(condition, description)
    if condition then
        test_lib.pass(description)
        return true
    else
        test_lib.fail(description .. " - Expected true, got false")
        return false
    end
end

function test_lib.assert_false(condition, description)
    if not condition then
        test_lib.pass(description)
        return true
    else
        test_lib.fail(description .. " - Expected false, got true")
        return false
    end
end

function test_lib.assert_nil(value, description)
    if value == nil then
        test_lib.pass(description .. " - Value is nil")
        return true
    else
        test_lib.fail(description .. " - Expected nil, got: " .. tostring(value))
        return false
    end
end

function test_lib.assert_not_nil(value, description)
    if value ~= nil then
        test_lib.pass(description .. " - Value is not nil: " .. tostring(value))
        return true
    else
        test_lib.fail(description .. " - Expected non-nil value, got nil")
        return false
    end
end

function test_lib.assert_contains(str, substring, description)
    if type(str) == "string" and string.find(str, substring, 1, true) then
        test_lib.pass(description .. " - Found: '" .. substring .. "'")
        return true
    else
        test_lib.fail(description .. " - '" .. tostring(substring) .. "' not found in: " .. tostring(str))
        return false
    end
end

function test_lib.assert_not_contains(str, substring, description)
    if type(str) ~= "string" or not string.find(str, substring, 1, true) then
        test_lib.pass(description .. " - '" .. tostring(substring) .. "' correctly not found")
        return true
    else
        test_lib.fail(description .. " - '" .. substring .. "' was unexpectedly found")
        return false
    end
end

function test_lib.assert_type(value, expected_type, description)
    local actual_type = type(value)
    if actual_type == expected_type then
        test_lib.pass(description .. " - Type is " .. expected_type)
        return true
    else
        test_lib.fail(description .. " - Expected type " .. expected_type .. ", got " .. actual_type)
        return false
    end
end

function test_lib.assert_table_has_key(t, key, description)
    if type(t) == "table" and t[key] ~= nil then
        test_lib.pass(description .. " - Table has key: " .. tostring(key))
        return true
    else
        test_lib.fail(description .. " - Table missing key: " .. tostring(key))
        return false
    end
end

return test_lib
