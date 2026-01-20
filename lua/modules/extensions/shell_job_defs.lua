-- shell_job_defs.lua
-- Shared definitions for job runner modules
-- This acts as a "header file" containing constants and path patterns
-- that are shared between shell_job.lua, shell_execute.lua, and shell_operator_fileio.lua

local defs = {}

-- ============================================================================
-- Job Status Constants
-- ============================================================================
-- These are the possible values written to the job status file
defs.STATUS = {
    RUNNING = "RUNNING",
    SUCCESS = "SUCCESS",
    FAILURE = "FAILURE"
}

-- ============================================================================
-- File Name Constants
-- ============================================================================
-- Standard file names used within a job's internals directory
defs.FILES = {
    STATUS = "job_status.txt",
    UUID = "job_uuid.txt",
    PID = "job_pid.txt",
    STDOUT = "stdout.txt",
    STDERR = "stderr.txt"
}

-- ============================================================================
-- Default Configuration
-- ============================================================================
defs.DEFAULTS = {
    -- Cleanup age in seconds (1 day = 86400 seconds)
    CLEANUP_AGE_SECONDS = 86400
}

-- ============================================================================
-- Path Utilities
-- ============================================================================

-- Detect if running on Windows
function defs.is_windows()
    return package.config:sub(1,1) == '\\'
end

-- Get the path separator for the current platform
function defs.get_path_separator()
    if defs.is_windows() then
        return '\\'
    else
        return '/'
    end
end

-- Join path components with the appropriate separator
function defs.join_path(...)
    local sep = defs.get_path_separator()
    local parts = {...}
    return table.concat(parts, sep)
end

-- Get the default command directory for the current platform
function defs.get_default_command_directory()
    if defs.is_windows() then
        return os.getenv("USERPROFILE")
    else
        return os.getenv("HOME")
    end
end

-- Get the base jobrunner directory for the current platform
-- This is where all job internals directories are created
function defs.get_jobrunner_base_directory()
    if defs.is_windows() then
        return os.getenv("APPDATA") .. "\\jobrunner"
    else
        return os.getenv("HOME") .. "/.config/jobrunner"
    end
end

-- Build the internals directory path for a specific instance
function defs.build_internals_directory(instance_id)
    local base = defs.get_jobrunner_base_directory()
    return defs.join_path(base, instance_id)
end

-- Build full file paths for all job files within an internals directory
-- Returns a table with paths for status, uuid, pid, stdout, stderr files
function defs.build_file_paths(internals_directory)
    local sep = defs.get_path_separator()
    return {
        status = internals_directory .. sep .. defs.FILES.STATUS,
        uuid = internals_directory .. sep .. defs.FILES.UUID,
        pid = internals_directory .. sep .. defs.FILES.PID,
        stdout = internals_directory .. sep .. defs.FILES.STDOUT,
        stderr = internals_directory .. sep .. defs.FILES.STDERR
    }
end

return defs
