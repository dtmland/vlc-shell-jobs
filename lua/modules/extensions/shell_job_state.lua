-- shell_job_state.lua
-- State machine for job runner
-- This module provides a clear, centralized view of job states and transitions.
-- It makes the state logic explicit and easy to understand.

local defs = require("extensions.shell_job_defs")
local fileio_module = require("extensions.shell_operator_fileio")

local state = {}

-- ============================================================================
-- Job States
-- ============================================================================
-- These represent the logical states a job can be in from the perspective
-- of the shell_job module. This is derived from the file-based IPC.
state.STATES = {
    -- No job has been started (UUID doesn't match or no UUID file)
    NO_JOB = "NO_JOB",
    
    -- Job has been requested but status file is empty (still launching)
    PENDING = "PENDING",
    
    -- Job is actively running (status file contains RUNNING)
    RUNNING = "RUNNING",
    
    -- Job completed successfully (status file contains SUCCESS)
    SUCCESS = "SUCCESS",
    
    -- Job completed with failure (status file contains FAILURE)
    FAILURE = "FAILURE",
    
    -- Job was stopped/aborted by user (status file contains STOPPED)
    STOPPED = "STOPPED"
}

-- ============================================================================
-- State Machine Constructor
-- ============================================================================

function state.new(file_paths, expected_uuid, fileio_instance)
    local self = {}
    
    -- Store references to file paths and expected UUID
    local paths = file_paths
    local uuid = expected_uuid
    local fileio = fileio_instance or fileio_module.new()

    -- ========================================================================
    -- Core State Query
    -- ========================================================================
    
    -- Get the current state of the job
    -- This is the single source of truth for job state
    function self.get_state()
        -- First check: Does the UUID match?
        local file_uuid = fileio.read_uuid(paths.uuid)
        if file_uuid ~= uuid then
            return state.STATES.NO_JOB
        end
        
        -- UUID matches, now check the status
        local status = fileio.read_status(paths.status)
        
        if status == "" then
            return state.STATES.PENDING
        elseif status == defs.STATUS.RUNNING then
            return state.STATES.RUNNING
        elseif status == defs.STATUS.SUCCESS then
            return state.STATES.SUCCESS
        elseif status == defs.STATUS.FAILURE then
            return state.STATES.FAILURE
        elseif status == defs.STATUS.STOPPED then
            return state.STATES.STOPPED
        else
            -- Unknown status, treat as pending
            return state.STATES.PENDING
        end
    end
    
    -- ========================================================================
    -- Convenience State Checks
    -- ========================================================================
    -- These provide named boolean checks for common state queries
    
    function self.is_no_job()
        return self.get_state() == state.STATES.NO_JOB
    end
    
    function self.is_pending()
        return self.get_state() == state.STATES.PENDING
    end
    
    function self.is_running()
        return self.get_state() == state.STATES.RUNNING
    end
    
    function self.is_finished()
        local s = self.get_state()
        return s == state.STATES.SUCCESS or s == state.STATES.FAILURE or s == state.STATES.STOPPED
    end
    
    function self.is_success()
        return self.get_state() == state.STATES.SUCCESS
    end
    
    function self.is_failure()
        return self.get_state() == state.STATES.FAILURE
    end
    
    function self.is_stopped()
        return self.get_state() == state.STATES.STOPPED
    end
    
    -- Check if job is active (either pending or running)
    function self.is_active()
        local s = self.get_state()
        return s == state.STATES.PENDING or s == state.STATES.RUNNING
    end

    -- ========================================================================
    -- State-Based Action Availability
    -- ========================================================================
    -- These methods indicate whether specific actions are allowed in the current state
    
    -- Can we start a new job?
    -- Only allowed if no job exists or previous job finished (including stopped)
    function self.can_run()
        local s = self.get_state()
        return s == state.STATES.NO_JOB or s == state.STATES.SUCCESS or s == state.STATES.FAILURE or s == state.STATES.STOPPED
    end
    
    -- Can we check status?
    -- Allowed if a job exists (any state except NO_JOB)
    function self.can_check_status()
        return self.get_state() ~= state.STATES.NO_JOB
    end
    
    -- Can we abort/stop the job?
    -- Only allowed if job is actively running
    function self.can_abort()
        return self.get_state() == state.STATES.RUNNING
    end

    -- ========================================================================
    -- State Transition Messages
    -- ========================================================================
    -- Human-readable messages explaining why an action cannot be performed
    
    function self.get_run_blocked_reason()
        local s = self.get_state()
        if s == state.STATES.PENDING then
            return "Job still pending."
        elseif s == state.STATES.RUNNING then
            return "Job already running."
        end
        return nil  -- Not blocked
    end
    
    function self.get_status_blocked_reason()
        local s = self.get_state()
        if s == state.STATES.NO_JOB then
            return "Job not running. Please run job first..."
        elseif s == state.STATES.PENDING then
            return "Job pending. Check status momentarily for progress..."
        end
        return nil  -- Not blocked (can show status)
    end
    
    function self.get_abort_blocked_reason()
        local s = self.get_state()
        if s == state.STATES.NO_JOB then
            return "No job to stop."
        elseif s == state.STATES.SUCCESS or s == state.STATES.FAILURE then
            return "Job already finished. No need to stop."
        elseif s == state.STATES.STOPPED then
            return "Job already stopped."
        elseif s == state.STATES.PENDING then
            return "Job still pending. Try to stop again momentarily..."
        end
        return nil  -- Not blocked (can abort)
    end

    -- ========================================================================
    -- UUID Management
    -- ========================================================================
    
    -- Update the expected UUID (called when starting a new job)
    function self.set_uuid(new_uuid)
        uuid = new_uuid
    end
    
    -- Get the current expected UUID
    function self.get_uuid()
        return uuid
    end

    return self
end

return state
