-- shell_operator_fileio.lua
-- File-based IPC operations for job runner
-- This module encapsulates all file I/O operations used for inter-process
-- communication with shell jobs. It provides a clean abstraction over
-- reading and writing status, uuid, pid, stdout, and stderr files.

local defs = require("extensions.shell_job_defs")
local vlc_interface = require("extensions.vlc_interface")

local fileio = {}

-- ============================================================================
-- Constructor
-- ============================================================================

function fileio.new(open_fn, msg_fn)
    local self = {}

    -- File operations wrapper (defaults to vlc_interface.io_open)
    local open_wrapper = open_fn or function(path, mode)
        return vlc_interface.io_open(path, mode)
    end

    -- Message logging wrapper (defaults to vlc_interface.msg)
    local msg_wrapper = msg_fn or function(level, message)
        vlc_interface.msg(level, message)
    end

    -- ========================================================================
    -- Generic File Operations
    -- ========================================================================
    
    -- Read entire file contents, return nil if file doesn't exist or can't be read
    local function read_file(path)
        local file = open_wrapper(path, "r")
        if file then
            local content = file:read("*all")
            file:close()
            return content
        end
        return nil
    end
    
    -- Read file and strip whitespace
    local function read_file_trimmed(path)
        local content = read_file(path)
        if content then
            return content:gsub("%s+", "")
        end
        return ""
    end
    
    -- Write content to file
    local function write_file(path, content)
        local file = open_wrapper(path, "w")
        if file then
            file:write(content)
            file:close()
            return true
        end
        return false
    end

    -- ========================================================================
    -- Public Interface: Read Operations
    -- ========================================================================
    
    -- Read the job status (RUNNING, SUCCESS, FAILURE, or empty)
    function self.read_status(status_file)
        local result = read_file_trimmed(status_file)
        if result == "" then
            msg_wrapper("dbg", "Status file empty or missing: " .. status_file)
        end
        return result
    end
    
    -- Read the job UUID
    function self.read_uuid(uuid_file)
        local result = read_file_trimmed(uuid_file)
        if result == "" then
            msg_wrapper("dbg", "UUID file empty or missing: " .. uuid_file)
        end
        return result
    end
    
    -- Read the job PID
    function self.read_pid(pid_file)
        local result = read_file_trimmed(pid_file)
        if result == "" then
            msg_wrapper("dbg", "PID file empty or missing: " .. pid_file)
        end
        return result
    end
    
    -- Read stdout content (raw, with whitespace preserved)
    function self.read_stdout(stdout_file)
        local content = read_file(stdout_file)
        if content == nil then
            msg_wrapper("dbg", "Failed to open stdout file: " .. stdout_file)
        end
        return content
    end
    
    -- Read stderr content (raw, with whitespace preserved)
    function self.read_stderr(stderr_file)
        local content = read_file(stderr_file)
        if content == nil then
            msg_wrapper("dbg", "Failed to open stderr file: " .. stderr_file)
        end
        return content
    end

    -- ========================================================================
    -- Public Interface: Write Operations
    -- ========================================================================
    
    -- Write the job UUID
    function self.write_uuid(uuid_file, uuid)
        local success = write_file(uuid_file, uuid)
        if not success then
            msg_wrapper("dbg", "Failed to write UUID file: " .. uuid_file)
        end
        return success
    end
    
    -- Write the job status
    function self.write_status(status_file, status)
        local success = write_file(status_file, status)
        if not success then
            msg_wrapper("dbg", "Failed to write status file: " .. status_file)
        end
        return success
    end

    -- ========================================================================
    -- Public Interface: Safe Read (with default value)
    -- ========================================================================
    
    -- Safe read that returns a default string if file can't be read
    function self.safe_read(path, default_value)
        default_value = default_value or "<waiting for status...>"
        local content = read_file(path)
        return content or default_value
    end

    -- ========================================================================
    -- Public Interface: Pretty Status Formatting
    -- ========================================================================
    
    -- Build a pretty status string from all output files
    function self.get_pretty_status(file_paths)
        local default_msg = "<waiting for status...>"
        local status = self.safe_read(file_paths.status, default_msg)
        local stdout = self.safe_read(file_paths.stdout, default_msg)
        local stderr = self.safe_read(file_paths.stderr, default_msg)
        
        local result = ""
        result = result .. "Job Status: " .. status .. "\n"
        result = result .. "Standard Output: " .. stdout .. "\n"
        result = result .. "Standard Error: " .. stderr .. "\n"
        return result
    end

    return self
end

return fileio
