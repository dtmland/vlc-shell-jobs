local executor = {}


function executor.job(command, command_directory)
    local result
    local stdout
    local stderr
    local one_liner
    local stdsandwhich

    local success_designator = "EXITCODE:SUCCESS"
    local failure_designator = "EXITCODE:FAILURE"

    if package.config:sub(1,1) == '\\' then
        if not command_directory then
            command_directory = os.getenv("USERPROFILE")
        end

        one_liner = table.concat({
            "powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command ",
            "\"",
            "$psi = New-Object System.Diagnostics.ProcessStartInfo; ",
            "$psi.FileName = \\\"cmd.exe\\\"; ",
            "$psi.Arguments = \\\"/c ",
            " cd ", command_directory, " ^&^& ",
            command,
            " ^&^& echo ",success_designator," ^|^| echo ",failure_designator," \\\"; ",
            "$psi.RedirectStandardOutput = $true; ",
            "$psi.RedirectStandardError = $true; ",
            "$psi.UseShellExecute = $false; ",
            "$psi.CreateNoWindow = $true; ",
            "$process = [System.Diagnostics.Process]::Start($psi); ",
            "$process.WaitForExit(); ",
            "$stdout = $process.StandardOutput.ReadToEnd(); ",
            "$stderr = $process.StandardError.ReadToEnd(); ",
            "$stdout = $stdout -split \\\"`r?`n\\\" | ForEach-Object { \\\"stdout: \\\" + $_ } | Out-String; ",
            "$stderr = $stderr -split \\\"`r?`n\\\" | ForEach-Object { \\\"stderr: \\\" + $_ } | Out-String; ",
            "$output = $stdout + $stderr; Write-Output $output",
            "\"",
        })
    else
        if not command_directory then
            command_directory = os.getenv("HOME")
        end
        -- TODO: Add support for UNIX
    end

    vlc.msg.info("Command: " .. one_liner)
    
    local handle = io.popen(one_liner, "r")
    if handle then
        stdsandwhich = handle:read("*all")
        handle:close()
    end

    stdout = ""
    stderr = ""
    if stdsandwhich and stdsandwhich:find(success_designator) then
        result = true

        for line in stdsandwhich:gmatch("[^\r\n]+") do
            if line:find("^stdout:") then
                stdout = stdout .. line:gsub("^stdout:%s*", "") .. "\n"
            end
        end

        stdout = stdout:gsub(success_designator, ""):gsub(failure_designator, "")

        for line in stdsandwhich:gmatch("[^\r\n]+") do
            if line:find("^stderr:") then
                stderr = stderr .. line:gsub("^stderr:%s*", "") .. "\n"
            end
        end
    else
        result = false
    end

    return result, stdout, stderr
end


function executor.job_async_stop(pid, uuid)
    local result = ""

    if package.config:sub(1,1) == '\\' then
        local one_liner = table.concat({
            "powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command ",
            "\"",
            "param([int] $ppid, [string] $matchString); ",
            "function Kill-Tree { ",
                "param([int] $ppid, [string] $matchString, [bool] $matchFound = $false); ",
                "$process = Get-CimInstance Win32_Process | ",
                "Where-Object { $_.ProcessId -eq $ppid }; ",
                "if (-not $process) { ",
                    "Write-Host \"Process with PID\" $ppid \"not found.\"; return }; ",
                "if (-not $matchFound -and $process.CommandLine -like \\\"*$matchString*\\\") { ",
                    "Write-Host \"Match found for process PID\" $ppid \"",
                                 "and\" $matchString \"",
                                 "with CommandLine:\" $process.CommandLine; ",
                    "$matchFound = $true } ",
                "elseif (-not $matchFound) { ",
                    "Write-Host \"No match for process PID\" $ppid \"",
                    "and\" $matchString \"",
                    "with CommandLine:\" $process.CommandLine \". Skipping.\" } ",
                "else { ",
                    "Write-Host \"Killing process PID\" $ppid \"with CommandLine:\" $process.CommandLine; ",
                    "if ($matchFound) { Stop-Process -Id $ppid -Force } }; ",
                "Get-CimInstance Win32_Process | ",
                "Where-Object { $_.ParentProcessId -eq $ppid } | ",
                "ForEach-Object { Kill-Tree -ppid $_.ProcessId -matchString $matchString -matchFound $matchFound } }; ",
            "Kill-Tree ",
            "-ppid ", pid, " -matchString ", uuid,
            "\""
        })

        vlc.msg.dbg("Stopping job with command: " .. one_liner)
        result = os.execute(one_liner)
    else
        -- UNIX
    end

    return result
end


function executor.job_async_run(name, cmd_command, cmd_directory, pid_record, uuid, stdout_file, stderr_file, 
                               status_running, status_success, status_failure)
    local one_liner = table.concat({
        "start ",
        "\"",name,"\"",
        " /d \"",cmd_directory,"\"",
        " /min cmd.exe /c ",
        "\"",
        status_running," && ",
        "echo ",uuid," >NUL && ",
        "powershell -NoProfile -ExecutionPolicy Bypass -Command ",
        "\"(Get-WmiObject Win32_Process -Filter \\\"ProcessId=$PID\\\").ParentProcessId\" > ",pid_record," && ",
        "cmd /c \"",cmd_command,"\"",
        " 2> ",stderr_file," > ",stdout_file," ",
        "&& ",status_success," || ",status_failure,
        "\""
    })
    
    vlc.msg.info("Running command: " .. one_liner)
    local result = os.execute(one_liner)
    vlc.msg.dbg("Command executed with result: " .. tostring(result))
end


-- Function to get the base jobrunner directory
function executor.get_jobrunner_base_directory()
    if package.config:sub(1,1) == '\\' then
        -- Windows
        return os.getenv("APPDATA") .. "\\jobrunner"
    else
        -- UNIX
        return os.getenv("HOME") .. "/.config/jobrunner"
    end
end


-- Function to get list of directories with their ages in seconds
-- Returns a table of {name = "dirname", age_seconds = 12345} or nil on error
function executor.get_job_directories_with_ages()
    local base_dir = executor.get_jobrunner_base_directory()
    local result = {}
    
    if package.config:sub(1,1) == '\\' then
        -- Windows: Use PowerShell to get all directories with their LastWriteTime in one call
        local cmd = table.concat({
            'powershell -NoProfile -ExecutionPolicy Bypass -Command "',
            'if (Test-Path \'', base_dir, '\') { ',
                'Get-ChildItem -Path \'', base_dir, '\' -Directory | ',
                'ForEach-Object { ',
                    '$age = [int]((Get-Date) - $_.LastWriteTime).TotalSeconds; ',
                    'Write-Output ($_.Name + \'|\' + $age) ',
                '} ',
            '}"'
        })
        
        vlc.msg.dbg("Getting job directories with command: " .. cmd)
        local handle = io.popen(cmd, "r")
        if handle then
            local output = handle:read("*all")
            handle:close()
            
            -- Parse output: each line is "dirname|age_seconds"
            for line in output:gmatch("[^\r\n]+") do
                local name, age_str = line:match("^(.+)|(%d+)$")
                if name and age_str then
                    table.insert(result, {name = name, age_seconds = tonumber(age_str)})
                end
            end
        end
    else
        -- UNIX: Use find command with GNU-specific -printf option
        -- Note: This requires GNU find. For BSD/macOS, a different approach would be needed.
        -- Since UNIX support is currently marked as TODO throughout the codebase, this is acceptable.
        local cmd = 'find "' .. base_dir .. '" -maxdepth 1 -mindepth 1 -type d -printf "%f|%T@\\n" 2>/dev/null'
        
        vlc.msg.dbg("Getting job directories with command: " .. cmd)
        local handle = io.popen(cmd, "r")
        if handle then
            local output = handle:read("*all")
            handle:close()
            
            local current_time = os.time()
            -- Parse output: each line is "dirname|mtime_timestamp"
            for line in output:gmatch("[^\r\n]+") do
                -- Match directory name and timestamp (integer or decimal)
                local name, mtime_str = line:match("^(.+)|([%d]+%.?[%d]*)$")
                if name and mtime_str then
                    local mtime = tonumber(mtime_str)
                    if mtime then
                        local age_seconds = math.floor(current_time - mtime)
                        table.insert(result, {name = name, age_seconds = age_seconds})
                    end
                end
            end
        end
    end
    
    return result
end


-- Function to remove a job directory by name
-- Returns true on success, false on failure
function executor.remove_job_directory(dir_name)
    local base_dir = executor.get_jobrunner_base_directory()
    local sep = package.config:sub(1,1) == '\\' and '\\' or '/'
    local full_path = base_dir .. sep .. dir_name
    
    if package.config:sub(1,1) == '\\' then
        -- Windows: Use PowerShell to remove directory recursively
        local cmd = 'powershell -NoProfile -ExecutionPolicy Bypass -Command "Remove-Item -Path \'' .. full_path .. '\' -Recurse -Force -ErrorAction SilentlyContinue"'
        vlc.msg.dbg("Removing directory with command: " .. cmd)
        local result = os.execute(cmd)
        return result == 0 or result == true
    else
        -- UNIX: Use rm -rf
        local cmd = 'rm -rf "' .. full_path .. '"'
        vlc.msg.dbg("Removing directory with command: " .. cmd)
        local result = os.execute(cmd)
        return result == 0 or result == true
    end
end

return executor
