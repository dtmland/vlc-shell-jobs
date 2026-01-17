local job_runner = {}
local executor = require("extensions.executor")

math.randomseed(os.time())

local function generate_random_number()
    return tostring(math.random(10000, 99999))
end


-- Function to generate a UUID
local function generate_uuid()
    local template = "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"
    return string.gsub(template, "[xy]", function(c)
        local v = (c == "x") and math.random(0, 15) or math.random(8, 11)
        return string.format("%x", v)
    end)
end

function job_runner.blocking_command(command, command_directory)
    return executor.blocking_command(command, command_directory)
end

function job_runner.new()
    local self = {
        instance_id = nil,
        name = nil,
        command = nil,
        command_directory = nil,
        internals_directory = nil,
        job_status_file = nil,
        job_uuid_file = nil,
        job_pid_file = nil,
        job_uuid = nil,
        stdout_file = nil,
        stderr_file = nil
    }

    local function msg_wrapper(level, message)
        vlc.msg[level](self.instance_id .. ": " .. message)
    end


    local function mkdir_wrapper(directory)
        -- Read, write, and execute permissions for the owner, and read and execute permissions for group and others
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

        -- Attempt to create the directory
        local result = mkdir_wrapper(directory)

        -- If successful or directory already exists, stop recursion
        if result then
            return true
        end

        -- Recursively create the parent directory
        local parent_directory = directory:match("^(.*)[/\\]")
        if parent_directory then
            msg_wrapper("dbg", "Creating parent directory: " .. parent_directory)
            local parent_result = create_directories_recursively(parent_directory)
            if not parent_result then
                return parent_result
            end
        end

        -- Retry creating the directory after parent directories are created
        return mkdir_wrapper(directory)
    end

    local function ensure_directory(path)
        return create_directories_recursively(path)
    end

    local function open_wrapper(path, mode)
        return vlc.io.open(path, mode)
    end

    local function configure_paths()
        local init_internals_directory
        local init_job_status_file
        local init_job_uuid_file
        local init_job_pid_file
        local init_stdout_file
        local init_stderr_file
        
        if package.config:sub(1,1) == '\\' then
            -- Windows
            if not self.command_directory then
                self.command_directory = os.getenv("USERPROFILE")
            end

            if not self.internals_directory then
                init_internals_directory = os.getenv("APPDATA") .. "\\jobrunner\\" .. self.instance_id
            end

            init_job_status_file = init_internals_directory .. "\\job_status.txt"
            init_job_uuid_file = init_internals_directory .. "\\job_uuid.txt"
            init_job_pid_file = init_internals_directory .. "\\job_pid.txt"
            init_stdout_file = init_internals_directory .. "\\stdout.txt"
            init_stderr_file = init_internals_directory .. "\\stderr.txt"
        else
            -- "It's a UNIX system! I know this!"
            if not self.command_directory then
                self.command_directory = os.getenv("HOME")
            end

            if not self.internals_directory then
                init_internals_directory = os.getenv("HOME") .. "/.config/" .. "/jobrunner/" .. self.instance_id    
            end

            init_job_status_file = init_internals_directory .. "/job_status.txt"
            init_job_uuid_file = init_internals_directory .. "/job_uuid.txt"
            init_job_pid_file = init_internals_directory .. "/job_pid.txt"
            init_stdout_file = init_internals_directory .. "/stdout.txt"
            init_stderr_file = init_internals_directory .. "/stderr.txt"
        end
        
        if not self.internals_directory then
            self.internals_directory = init_internals_directory
        end

        self.job_status_file = init_job_status_file
        self.job_uuid_file = init_job_uuid_file
        self.job_pid_file = init_job_pid_file
        self.stdout_file = init_stdout_file
        self.stderr_file = init_stderr_file

        msg_wrapper("dbg", "Will use internals directory: " .. self.internals_directory)
    end


    function self.initialize(description, command, command_directory)

        self.instance_id = generate_random_number()
        self.name = description
        self.command = command
        self.command_directory = command_directory

        configure_paths()
    end

    function self.get_internals_directory()
        return self.internals_directory
    end
    
    function self.set_internals_directory(path)
        self.internals_directory = path
        configure_paths()
    end

    function self.get_stdout_file_path()
        return self.stdout_file
    end

    function self.get_stderr_file_path()
        return self.stdout_file
    end

    function self.get_stdout()
        local file = open_wrapper(self.stdout_file, "r")
        if file then
            local content = file:read("*all")
            file:close()
            return content
        else
            msg_wrapper("dbg", "Failed to open stdout file")
            return nil
        end
    end

    function self.get_stderr()
        local file = open_wrapper(self.stderr_file, "r")
        if file then
            local content = file:read("*all")
            file:close()
            return content
        else
            msg_wrapper("dbg", "Failed to open stderr file")
            return nil
        end
    end

    function self.get_raw_status()
        local file = open_wrapper(self.job_status_file, "r")
        if file then
            local content = file:read("*all")
            file:close()
            return content
        else
            msg_wrapper("dbg", "Failed to open job status file")
            return nil
        end
    end



    local function stop_job(pid, uuid)
        return executor.stop_job(pid, uuid)
    end

    local function get_status_via_file_polling()
        local result = ""
        local file = open_wrapper(self.job_status_file, "r")
        if file then
            result = file:read("*all"):gsub("%s+", "")
            file:close()
        else
            msg_wrapper("dbg", "Failed to open job status file")
        end

        return result
    end

    local function get_pid_via_file_polling()
        local result = ""
        local file = open_wrapper(self.job_pid_file, "r")
        if file then
            result = file:read("*all"):gsub("%s+", "")
            file:close()
        else
            msg_wrapper("dbg", "Failed to open job PID file")
        end

        return result
    end

    local function set_uuid_via_file_polling(file_path, uuid)
        local file = open_wrapper(file_path, "w")
        if file then
            file:write(uuid)
            file:close()
        else
            msg_wrapper("dbg", "Failed to open job UUID file")
        end
    end

    local function get_uuid_via_file_polling(file_path)
        local result = ""
        local file = open_wrapper(file_path, "r")
        if file then
            result = file:read("*all"):gsub("%s+", "")
            file:close()
        else
            msg_wrapper("dbg", "Failed to open job UUID file")
        end

        return result
    end

    local function job_pending_via_file_polling()
        local result = false

        if get_uuid_via_file_polling(self.job_uuid_file) == self.job_uuid then
            if get_status_via_file_polling() == "" then
                result = true
            end            
        end

        return result
    end

    local function job_aleady_running_via_file_polling()
        local result = false

        if get_uuid_via_file_polling(self.job_uuid_file) == self.job_uuid then
            local status = get_status_via_file_polling()
            if status == "RUNNING" then
                result = true
            end
        end

        return result
    end

    local function no_job_found_via_file_polling()
        local result = false
        
        if get_uuid_via_file_polling(self.job_uuid_file) ~= self.job_uuid then
            result = true
        end

        return result
    end

    local function job_finished_via_file_polling()
        local result = false

        if get_uuid_via_file_polling(self.job_uuid_file) == self.job_uuid then
            local status = get_status_via_file_polling()
            if status == "SUCCESS" or status == "FAILURE" then
                result = true
            end
        end

        return result
    end

    local function get_pretty_status_via_file_polling()
        local function safe_read(file_path)
            local file = open_wrapper(file_path, "r")
            if file then
                local content = file:read("*all")
                file:close()
                return content or "<waiting for status...>"
            else
                return "<waiting for status...>"
            end
        end

        local status = safe_read(self.job_status_file)
        local stdout = safe_read(self.stdout_file)
        local stderr = safe_read(self.stderr_file)

        local result = ""
        result = result .. "Job Status: " .. status .. "\n"
        result = result .. "Standard Output: " .. stdout .. "\n"
        result = result .. "Standard Error: " .. stderr .. "\n"
        return result
    end


    local function job_pending()
        return job_pending_via_file_polling()
    end

    local function job_already_running()
        return job_aleady_running_via_file_polling()
    end

    local function no_job_found()
        return no_job_found_via_file_polling()
    end

    local function job_finished()
        return job_finished_via_file_polling()
    end

    local function run_cmd_job(name, cmd_command, cmd_directory, pid_record, uuid, stdout_file, stderr_file, 
                               status_running, status_success, status_failure)
        return executor.run_cmd_job(name, cmd_command, cmd_directory, pid_record, uuid, stdout_file, stderr_file, 
                                    status_running, status_success, status_failure)
    end

    local function run_job_via_file_polling(name, cmd_command, cmd_directory, uuid, stdout_file, 
                                            stderr_file, job_status_file)
        local pid_record = self.job_pid_file

        local status_running = table.concat({"echo RUNNING > ",self.job_status_file})
        local status_success = table.concat({"echo SUCCESS > ",self.job_status_file})
        local status_failure = table.concat({"echo FAILURE > ",self.job_status_file})

        run_cmd_job(name, cmd_command, cmd_directory, pid_record, uuid, self.stdout_file, self.stderr_file,
                    status_running, status_success, status_failure)
    end


    function self.run()

        if not ensure_directory(self.internals_directory) then
            local msg = "Failed to create internals directory. Please see logs"
            msg_wrapper("err", msg)
            return msg
        end

        if job_pending() then
            local msg = "Job still pending."
            msg_wrapper("info", msg)
            return msg
        end

        if job_already_running() then
            local msg = "Job already running."
            msg_wrapper("info", msg)
            return msg
        end

        self.job_uuid = generate_uuid()
        set_uuid_via_file_polling(self.job_uuid_file, self.job_uuid)

        run_job_via_file_polling(self.name, self.command, self.command_directory,
                                 self.job_uuid, self.stdout_file, self.stderr_file, self.job_status_file)

        local result = "Job \"" .. self.name .. "\" now launching..."
        return result
    end    


    function self.status()
        local result = ""

        if no_job_found() then
            local msg = "Job not running. Please run job first..."
            msg_wrapper("info", msg)
            return msg
        end

        if job_pending() then
            local msg = "Job pending. Check status momentarily for progress..."
            msg_wrapper("info", msg)
            return msg
        end

        result = get_pretty_status_via_file_polling()

        return result
    end


    
    function self.abort()
        local result = ""

        if no_job_found() then
            local msg = "No job to stop."
            msg_wrapper("info", msg)
            return msg
        end

        if job_finished() then
            local msg = "Job already finished. No need to stop."
            msg_wrapper("info", msg)
            return msg
        end

        if job_pending() then
            local msg = "Job still pending. Try to stop again momentarily..."
            msg_wrapper("info", msg)
            return msg
        end

        result = get_pid_via_file_polling()

        if result == "" then
            local msg = "No PID found. Cannot stop job."
            msg_wrapper("info", msg)
            return msg
        end

        pid = result
        msg_wrapper("dbg", "PID found: " .. pid)
        result = stop_job(pid, self.job_uuid)

        result = "Job stopped..."

        return result
    end

    return self
end

return job_runner