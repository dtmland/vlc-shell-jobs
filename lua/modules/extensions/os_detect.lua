-- os_detect.lua
-- OS detection utilities
-- Provides platform detection functions for cross-platform compatibility

local os_detect = {}

-- Cached detection results (computed once on first call)
local cached_is_windows = nil
local cached_is_macos = nil

-- Detect if running on Windows
-- Uses package.config path separator as indicator
function os_detect.is_windows()
    if cached_is_windows == nil then
        cached_is_windows = package.config:sub(1,1) == '\\'
    end
    return cached_is_windows
end

-- Detect if running on macOS (Darwin)
-- Uses uname -s command on Unix systems
function os_detect.is_macos()
    if cached_is_macos == nil then
        cached_is_macos = false
        if not os_detect.is_windows() then
            local ok, uname = pcall(function()
                local f = io.popen("uname -s")
                if f then
                    local s = f:read("*l")
                    f:close()
                    return s
                end
                return nil
            end)
            if ok and uname and uname:match("Darwin") then
                cached_is_macos = true
            end
        end
    end
    return cached_is_macos
end

-- Detect if running on any Unix-like system (including macOS and Linux)
function os_detect.is_unix()
    return not os_detect.is_windows()
end

-- Detect if running on Linux (Unix but not macOS)
function os_detect.is_linux()
    return os_detect.is_unix() and not os_detect.is_macos()
end

-- Get the path separator for the current platform
function os_detect.get_path_separator()
    if os_detect.is_windows() then
        return '\\'
    else
        return '/'
    end
end

return os_detect
