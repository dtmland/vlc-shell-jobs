-- path_utils.lua
-- Path utilities for cross-platform path handling
-- Includes fix for Linux paths missing leading slash
-- Includes fix for Windows paths with forward slashes

local path_utils = {}

-- Import OS detection module
local os_detect = require("extensions.os_detect")

-- Fix paths that are missing the leading slash on Linux/Unix
-- This can happen when VLC/Lua provides paths without the leading /
-- For example: "users/..." should become "/users/..."
--
--
-- This function detects and fixes such paths on non-Windows platforms
function path_utils.fix_unix_path(path)
    if not path or path == "" then
        return path
    end
    
    -- Only apply fix on Unix-like systems (Linux, macOS)
    if os_detect.is_windows() then
        return path
    end
    
    -- Check if path looks like it should be absolute but is missing leading /
    -- Unix absolute paths start with /
    -- If path starts with a known root directory pattern but no leading /,
    -- it's likely missing the /
    
    -- Patterns that indicate a path should be absolute on Unix:
    -- - mnt/ (WSL paths)
    -- - home/
    -- - usr/
    -- - var/
    -- - opt/
    -- - etc/
    -- - tmp/
    -- - root/
    -- - media/
    -- - run/
    local unix_root_patterns = {
        "^mnt/",
        "^home/",
        "^usr/",
        "^var/",
        "^opt/",
        "^etc/",
        "^tmp/",
        "^root/",
        "^media/",
        "^run/",
        "^dev/",
        "^proc/",
        "^sys/",
        "^boot/",
        "^lib/",
        "^lib64/",
        "^bin/",
        "^sbin/",
        "^users/",
        "^Applications/",
        "^Library/",
        "^System/",
        "^Volumes/",
        "^Network/",
        "^Users/",
    }
    
    -- Check if path already starts with /
    if path:sub(1, 1) == "/" then
        return path
    end
    
    -- Check if path matches any of the root patterns
    for _, pattern in ipairs(unix_root_patterns) do
        if path:match(pattern) then
            -- Path should have leading / but doesn't - fix it
            return "/" .. path
        end
    end
    
    -- Path doesn't match known patterns, return as-is
    return path
end

-- Fix paths that have forward slashes on Windows
-- VLC/Lua may provide URI-decoded paths with forward slashes,
-- which need to be converted to backslashes for Windows filesystem operations
function path_utils.fix_windows_path(path)
    if not path or path == "" then
        return path
    end

    -- Only apply fix on Windows systems
    if not os_detect.is_windows() then
        return path
    end

    -- Replace all forward slashes with backslashes
    local fixed_path = path:gsub("/", "\\")

    return fixed_path
end

-- Get the platform-specific PATH prefix export command
-- On macOS, VLC runs with a minimal PATH, so we need to extend it
-- to include common binary locations like /usr/local/bin and /opt/homebrew/bin
-- Returns an export command that should be prepended to shell commands
-- Returns empty string on platforms that don't need PATH adjustment
function path_utils.get_path_prefix()
    if os_detect.is_macos() then
        return "export PATH=$PATH:/usr/local/bin:/opt/homebrew/bin; "
    end
    -- Add additional platform cases here as needed
    return ""
end

-- Extract directory, basename, and basename without extension from a path
-- Cross-platform: handles both / and \ separators
function path_utils.parse_path(path)
    if not path or path == "" then
        return "", "", ""
    end
    
    local dir, basename, basename_without_ext
    
    if os_detect.is_windows() then
        -- Windows paths may use backslashes
        dir = path:match("(.*[/\\])") or ""
        basename = path:match("([^/\\]+)$") or ""
        basename_without_ext = path:match("([^/\\]+)%.%w+$") or basename
    else
        -- Unix paths use forward slashes
        dir = path:match("(.*/)") or ""
        basename = path:match("([^/]+)$") or ""
        basename_without_ext = path:match("([^/]+)%.%w+$") or basename
    end
    
    return dir, basename, basename_without_ext
end

return path_utils
