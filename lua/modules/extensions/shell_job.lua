-- shell_job.lua
-- Job runner module for managing async shell jobs
-- 
-- This module provides a clean interface for:
-- - Starting async shell jobs
-- - Checking job status
-- - Aborting running jobs
--
-- Architecture:
-- - shell_job_defs.lua: Shared constants and path utilities
-- - shell_operator_fileio.lua: File-based IPC operations
-- - shell_job_state.lua: State machine for job lifecycle
-- - shell_execute.lua: Low-level command execution

local job_runner = {}
local executor = require("extensions.shell_execute")
local defs = require("extensions.shell_job_defs")
local fileio_module = require("extensions.shell_operator_fileio")
local state_module = require("extensions.shell_job_state")

math.randomseed(os.time())

-- ============================================================================
-- Helper Functions
-- ============================================================================

local function generate_random_number()
    return tostring(math.random(10000, 99999))
end

local function generate_uuid()
    local template = "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"
    return string.gsub(template, "[xy]", function(c)
        local v = (c == "x") and math.random(0, 15) or math.random(8, 11)
        return string.format("%x", v)
    end)
end

-- ============================================================================
-- Module-Level Functions
-- ============================================================================

-- Clean up old job directories
function job_runner.cleanup_old_jobs(max_age_seconds)
    max_age_seconds = max_age_seconds or defs.DEFAULTS.CLEANUP_AGE_SECONDS
    
    local cleaned_count = 0
    local directories = executor.get_job_directories_with_ages()
    
    if not directories or #directories == 0 then
        vlc.msg.dbg("Cleanup: No job directories found")
        return 0
    end
    
    vlc.msg.dbg("Cleanup: Found " .. #directories .. " job directories")
    
    for _, dir_info in ipairs(directories) do
        if dir_info.age_seconds > max_age_seconds then
            vlc.msg.dbg("Cleanup: Removing old job directory (age: " .. dir_info.age_seconds .. "s): " .. dir_info.name)
            if executor.remove_job_directory(dir_info.name) then
                cleaned_count = cleaned_count + 1
            end
        else
            vlc.msg.dbg("Cleanup: Job directory still recent (age: " .. dir_info.age_seconds .. "s): " .. dir_info.name)
        end
    end
    
    if cleaned_count > 0 then
        vlc.msg.info("Cleanup: Removed " .. cleaned_count .. " old job directories")
    end
    
    return cleaned_count
end

-- Run a synchronous job (blocking)
function job_runner.job(command, command_directory)
    return executor.job(command, command_directory)
end

-- ============================================================================
-- Job Instance Constructor
-- ============================================================================

function job_runner.new()
    -- Instance state
    local self = {
        instance_id = nil,
        name = nil,
        command = nil,
        command_directory = nil,
        internals_directory = nil,
        abort_counter = 0,
        cleanup_age_seconds = defs.DEFAULTS.CLEANUP_AGE_SECONDS
    }
    
    -- File paths (populated by configure_paths)
    local file_paths = nil
    
    -- Module instances (created after paths are configured)
    local fileio = nil
    local job_state = nil
    local job_uuid = nil

    -- ========================================================================
    -- Internal Helpers
    -- ========================================================================

    local function msg_wrapper(level, message)
        vlc.msg[level](self.instance_id .. ": " .. message)
    end

    local function open_wrapper(path, mode)
        return vlc.io.open(path, mode)
    end

    local function mkdir_wrapper(directory)
        local mode = "0755"
        local errno = { ENOENT = 2, EEXIST = 17, EACCES = 13, EINVAL = 22 }
        msg_wrapper("dbg", "Attempt to create: " .. directory .. " with mode: " .. mode)
        local success, err_code = vlc.io.mkdir(directory, mode)
        if success == 0 then
            msg_wrapper("dbg", "Directory created successfully: " .. directory)
        else
            if err_code == errno.EEXIST then
                msg_wrapper("dbg", "Found directory:" .. directory)
            elseif err_code == errno.EACCES then
                msg_wrapper("err", "Permission denied when trying create directory: " .. directory)
                return false
            elseif err_code == errno.ENOENT then
                msg_wrapper("err", "No such file or directory when trying create directory: " .. directory)
                return false
            elseif err_code == errno.EINVAL then
                msg_wrapper("err", "Invalid argument when trying create directory: " .. directory)
                return false
            else
                msg_wrapper("err", "Failed with error: " .. err_code .. " when trying to create dir: " .. directory)
                return false
            end
        end
        return true
    end    

    local function create_directories_recursively(directory)
        local result = mkdir_wrapper(directory)
        if result then
            return true
        end

        local parent_directory = directory:match("^(.*)[/\\]")
        if parent_directory then
            msg_wrapper("dbg", "Creating parent directory: " .. parent_directory)
            local parent_result = create_directories_recursively(parent_directory)
            if not parent_result then
                return parent_result
            end
        end

        return mkdir_wrapper(directory)
    end

    local function ensure_directory(path)
        return create_directories_recursively(path)
    end

    local function configure_paths()
        -- Set command directory default
        if not self.command_directory then
            self.command_directory = defs.get_default_command_directory()
        end
        
        -- Set internals directory
        if not self.internals_directory then
            self.internals_directory = defs.build_internals_directory(self.instance_id)
        end
        
        -- Build all file paths using the defs module
        file_paths = defs.build_file_paths(self.internals_directory)
        
        -- Create fileio instance with VLC wrappers
        fileio = fileio_module.new(open_wrapper, msg_wrapper)
        
        -- Create state machine (initially with nil uuid - will be set when job runs)
        job_state = state_module.new(file_paths, job_uuid, fileio)
        
        msg_wrapper("dbg", "Will use internals directory: " .. self.internals_directory)
    end

    local function run_job_via_executor()
        local status_running = "echo " .. defs.STATUS.RUNNING .. " > " .. file_paths.status
        local status_success = "echo " .. defs.STATUS.SUCCESS .. " > " .. file_paths.status
        local status_failure = "echo " .. defs.STATUS.FAILURE .. " > " .. file_paths.status

        executor.job_async_run(
            self.name, 
            self.command, 
            self.command_directory, 
            file_paths.pid, 
            job_uuid, 
            file_paths.stdout, 
            file_paths.stderr,
            status_running, 
            status_success, 
            status_failure
        )
    end

    -- ========================================================================
    -- Public Interface: Initialization
    -- ========================================================================

    function self.initialize(description, command, command_directory)
        self.instance_id = generate_random_number()
        self.name = description
        self.command = command
        self.command_directory = command_directory
        configure_paths()
    end

    -- ========================================================================
    -- Public Interface: Getters/Setters
    -- ========================================================================

    function self.get_internals_directory()
        return self.internals_directory
    end
    
    function self.set_internals_directory(path)
        self.internals_directory = path
        configure_paths()
    end

    function self.get_cleanup_age_seconds()
        return self.cleanup_age_seconds
    end

    function self.set_cleanup_age_seconds(age_seconds)
        self.cleanup_age_seconds = age_seconds or defs.DEFAULTS.CLEANUP_AGE_SECONDS
    end

    function self.get_stdout_file_path()
        return file_paths and file_paths.stdout or nil
    end

    function self.get_stderr_file_path()
        return file_paths and file_paths.stderr or nil
    end

    function self.get_stdout()
        if not file_paths then return nil end
        return fileio.read_stdout(file_paths.stdout)
    end

    function self.get_stderr()
        if not file_paths then return nil end
        return fileio.read_stderr(file_paths.stderr)
    end

    function self.get_raw_status()
        if not file_paths then return nil end
        return fileio.read_status(file_paths.status)
    end

    -- ========================================================================
    -- Public Interface: Job Actions
    -- ========================================================================

    function self.run()
        -- Ensure internals directory exists
        if not ensure_directory(self.internals_directory) then
            local msg = "Failed to create internals directory. Please see logs"
            msg_wrapper("err", msg)
            return msg
        end

        -- Check if we can run (using state machine)
        local blocked_reason = job_state.get_run_blocked_reason()
        if blocked_reason then
            msg_wrapper("info", blocked_reason)
            return blocked_reason
        end

        -- Generate new UUID and update state machine
        job_uuid = generate_uuid()
        job_state.set_uuid(job_uuid)
        
        -- Write UUID to file and launch job
        fileio.write_uuid(file_paths.uuid, job_uuid)
        run_job_via_executor()

        local result = "Job \"" .. self.name .. "\" now launching..."
        return result
    end    

    function self.status()
        -- Check if status is blocked
        local blocked_reason = job_state.get_status_blocked_reason()
        if blocked_reason then
            msg_wrapper("info", blocked_reason)
            return blocked_reason
        end

        -- Return formatted status
        return fileio.get_pretty_status(file_paths)
    end

    function self.abort()
        -- Increment abort counter and run cleanup every 3rd abort
        self.abort_counter = self.abort_counter + 1
        if self.abort_counter % 3 == 0 then
            msg_wrapper("dbg", "Abort pumped (count: " .. self.abort_counter .. "), running cleanup...")
            job_runner.cleanup_old_jobs(self.cleanup_age_seconds)
        end

        -- Check if abort is blocked
        local blocked_reason = job_state.get_abort_blocked_reason()
        if blocked_reason then
            msg_wrapper("info", blocked_reason)
            return blocked_reason
        end

        -- Get PID and stop the job
        local pid = fileio.read_pid(file_paths.pid)
        if pid == "" then
            local msg = "No PID found. Cannot stop job."
            msg_wrapper("info", msg)
            return msg
        end

        msg_wrapper("dbg", "PID found: " .. pid)
        executor.job_async_stop(pid, job_uuid)

        -- Update status to STOPPED so the state machine knows the job was aborted
        -- This is necessary because the background process is killed before it can
        -- update the status file to SUCCESS or FAILURE
        fileio.write_status(file_paths.status, defs.STATUS.STOPPED)

        return "Job stopped..."
    end

    return self
end

return job_runner