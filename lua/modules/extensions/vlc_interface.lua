-- vlc_interface.lua
-- VLC API abstraction layer
--
-- Centralizes all VLC Lua API calls behind a single module so that
-- version-specific changes only need to happen in one place.
-- Currently targets VLC 3.x (Lua Extensions API).
--
-- When VLC 4.x arrives and changes the Lua API, update the wrapper
-- functions here instead of modifying every file in the codebase.
--
-- Version detection runs once at module load time via platform-specific
-- CLI commands. If the detected major version doesn't match
-- SUPPORTED_MAJOR_VERSION, callers can display a compatibility warning.

local vlc_interface = {}

-- Import dependencies
local os_detect = require("extensions.os_detect")
local vlc_compat = require("extensions.vlc_compat")

-- ============================================================================
-- Version Constants
-- ============================================================================

-- The major VLC version this codebase is designed for
vlc_interface.SUPPORTED_MAJOR_VERSION = 3

-- ============================================================================
-- Internal: get the VLC object (real or mock)
-- ============================================================================

local function get_vlc()
    return vlc_compat.get_vlc()
end

-- ============================================================================
-- Version Detection
-- ============================================================================

-- Cached version info (detected once)
local detected_version = nil  -- {major=N, minor=N, patch=N} or false if detection failed
local version_detected = false

-- Detect VLC version from the installed binary
-- Returns {major, minor, patch} or nil on failure
local function detect_vlc_version()
    local version_str = nil

    local ok, result = pcall(function()
        if os_detect.is_windows() then
            -- Try standard VLC install path
            local paths = {
                '"C:\\Program Files\\VideoLAN\\VLC\\vlc.exe"',
                '"C:\\Program Files (x86)\\VideoLAN\\VLC\\vlc.exe"',
            }
            for _, vlc_path in ipairs(paths) do
                local cmd = 'powershell -NoProfile -Command "(Get-Item ' .. vlc_path .. ').VersionInfo.FileVersion" 2>NUL'
                local pipe = io.popen(cmd)
                if pipe then
                    local output = pipe:read("*l")
                    pipe:close()
                    if output and output:match("^%d+%.%d+") then
                        return output
                    end
                end
            end
        else
            -- Linux / macOS: vlc --version
            local cmd = "vlc --version 2>/dev/null"
            local pipe = io.popen(cmd)
            if pipe then
                local output = pipe:read("*l")
                pipe:close()
                -- Parse: "VLC media player 3.0.20 Vetinari (...)"
                if output then
                    local ver = output:match("VLC media player (%d+%.%d+%.%d+)")
                    if ver then return ver end
                end
            end
        end
        return nil
    end)

    if ok and result then
        version_str = result
    end

    if not version_str then
        return nil
    end

    -- Parse "3.0.20" into components
    local major, minor, patch = version_str:match("^(%d+)%.(%d+)%.(%d+)")
    if major then
        return {
            major = tonumber(major),
            minor = tonumber(minor),
            patch = tonumber(patch),
        }
    end

    -- Try two-part version "3.0" (Windows sometimes returns this)
    major, minor = version_str:match("^(%d+)%.(%d+)")
    if major then
        return {
            major = tonumber(major),
            minor = tonumber(minor),
            patch = 0,
        }
    end

    return nil
end

-- Ensure version is detected (lazy, runs once)
local function ensure_version_detected()
    if not version_detected then
        version_detected = true
        detected_version = detect_vlc_version()
    end
end

-- Get the detected VLC version
-- Returns {major, minor, patch} or nil if detection failed
function vlc_interface.get_version()
    ensure_version_detected()
    return detected_version
end

-- Get version as a display string
-- Returns "3.0.20" or "unknown"
function vlc_interface.get_version_string()
    ensure_version_detected()
    if detected_version then
        return detected_version.major .. "." .. detected_version.minor .. "." .. detected_version.patch
    end
    return "unknown"
end

-- Check if the detected version is compatible with this codebase
-- Returns: compatible (boolean), message (string or nil)
-- compatible is true if major version matches or if detection failed (benefit of the doubt)
function vlc_interface.check_version_compatibility()
    ensure_version_detected()
    if not detected_version then
        return true, nil  -- Can't detect, don't warn
    end
    if detected_version.major ~= vlc_interface.SUPPORTED_MAJOR_VERSION then
        return false,
            "VLC " .. vlc_interface.get_version_string() .. " detected. " ..
            "This extension was built for VLC " .. vlc_interface.SUPPORTED_MAJOR_VERSION .. ".x. " ..
            "Some features may not work correctly. Check for an updated version of Detective."
    end
    return true, nil
end

-- ============================================================================
-- Logging
-- ============================================================================

function vlc_interface.msg_dbg(message)
    get_vlc().msg.dbg(message)
end

function vlc_interface.msg_info(message)
    get_vlc().msg.info(message)
end

function vlc_interface.msg_warn(message)
    get_vlc().msg.warn(message)
end

function vlc_interface.msg_err(message)
    get_vlc().msg.err(message)
end

-- Dynamic level logging: level is one of "dbg", "info", "warn", "err"
function vlc_interface.msg(level, message)
    get_vlc().msg[level](message)
end

-- ============================================================================
-- Dialog
-- ============================================================================

-- Create a new VLC dialog window
-- Returns the dialog object (with :add_button, :add_label, etc.)
function vlc_interface.create_dialog(title)
    return get_vlc().dialog(title)
end

-- ============================================================================
-- Input / Media
-- ============================================================================

-- Get the current input object (for checking if media is loaded)
-- Returns the input object or nil
function vlc_interface.get_input()
    return get_vlc().object.input()
end

-- Get the current input item (media metadata)
-- Returns the item object or nil
function vlc_interface.get_input_item()
    return get_vlc().input.item()
end

-- Decode a URI string (percent-decoding)
function vlc_interface.decode_uri(uri)
    return get_vlc().strings.decode_uri(uri)
end

-- ============================================================================
-- Playlist
-- ============================================================================

-- Enqueue an item into the playlist
-- item: table with {path=..., name=...} fields
function vlc_interface.playlist_enqueue(item)
    get_vlc().playlist.enqueue({item})
end

-- Get the current playlist item ID
function vlc_interface.playlist_current()
    return get_vlc().playlist.current()
end

-- Delete a playlist item by ID
function vlc_interface.playlist_delete(id)
    get_vlc().playlist.delete(id)
end

-- Start playback
function vlc_interface.playlist_play()
    get_vlc().playlist.play()
end

-- ============================================================================
-- I/O
-- ============================================================================

-- Open a file (uses vlc.io.open when available, falls back to io.open)
function vlc_interface.io_open(path, mode)
    local v = get_vlc()
    if v.io then
        return v.io.open(path, mode)
    else
        return io.open(path, mode)
    end
end

-- Create a directory (uses vlc.io.mkdir when available)
-- Returns success, err_code
function vlc_interface.io_mkdir(directory, mode)
    local v = get_vlc()
    if v.io and v.io.mkdir then
        return v.io.mkdir(directory, mode)
    else
        -- Fallback for non-VLC environments
        local cmd
        if os_detect.is_windows() then
            cmd = 'mkdir "' .. directory .. '" 2>nul'
        else
            cmd = 'mkdir -p "' .. directory .. '" 2>/dev/null'
        end
        local result = os.execute(cmd)
        if result == 0 or result == true then
            return 0, nil
        else
            return -1, 2
        end
    end
end

return vlc_interface
