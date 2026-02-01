-- vlc_compat.lua
-- VLC compatibility layer for testing Lua modules outside of VLC
--
-- This module provides mock/fallback implementations for VLC-specific
-- functionality so that modules can be tested in standalone Lua.
--
-- Usage:
--   local vlc_compat = require("extensions.vlc_compat")
--   local vlc = vlc_compat.get_vlc()
--
-- When running inside VLC, this returns the real vlc global.
-- When running outside VLC, this returns a mock implementation.

local vlc_compat = {}

-- ============================================================================
-- Mock VLC Implementation
-- ============================================================================

local mock_vlc = {
    -- Message logging (mock implementation - prints to stdout)
    msg = {
        dbg = function(message)
            -- Debug messages are silenced by default in tests
            -- Uncomment the line below to see debug output
            -- print("[VLC DBG] " .. tostring(message))
        end,
        info = function(message)
            print("[VLC INFO] " .. tostring(message))
        end,
        warn = function(message)
            print("[VLC WARN] " .. tostring(message))
        end,
        err = function(message)
            print("[VLC ERR] " .. tostring(message))
        end
    },
    
    -- I/O operations (mock implementation - uses standard Lua io)
    io = {
        open = function(path, mode)
            return io.open(path, mode)
        end,
        mkdir = function(directory, mode)
            -- Use os.execute to create directory
            -- Returns 0 on success, error code on failure
            local cmd
            if package.config:sub(1,1) == '\\' then
                -- Windows
                cmd = 'mkdir "' .. directory .. '" 2>nul'
            else
                -- Unix
                cmd = 'mkdir -p "' .. directory .. '" 2>/dev/null'
            end
            local result = os.execute(cmd)
            if result == 0 or result == true then
                return 0, nil
            else
                -- Check if directory already exists
                local test_file = directory .. "/._test_exists"
                local f = io.open(test_file, "w")
                if f then
                    f:close()
                    os.remove(test_file)
                    -- Directory exists, return EEXIST (17)
                    return -1, 17
                end
                -- Directory doesn't exist and couldn't be created
                return -1, 2  -- ENOENT
            end
        end
    }
}

-- ============================================================================
-- Public Interface
-- ============================================================================

-- Check if we're running inside VLC
function vlc_compat.is_vlc_available()
    return type(vlc) == "table" and vlc.msg ~= nil
end

-- Get the VLC object (real or mock)
function vlc_compat.get_vlc()
    if vlc_compat.is_vlc_available() then
        return vlc
    else
        return mock_vlc
    end
end

-- Get the mock VLC object (for testing)
function vlc_compat.get_mock_vlc()
    return mock_vlc
end

-- Configure mock debug logging (for tests that want to see debug output)
function vlc_compat.enable_debug_logging()
    mock_vlc.msg.dbg = function(message)
        print("[VLC DBG] " .. tostring(message))
    end
end

function vlc_compat.disable_debug_logging()
    mock_vlc.msg.dbg = function(message) end
end

return vlc_compat
