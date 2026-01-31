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
        -- UNIX (Linux and macOS)
        if not command_directory then
            command_directory = os.getenv("HOME")
        end

        -- Build a shell command that captures stdout and stderr separately
        -- Uses temporary files to capture stdout and stderr independently
        -- Then prefixes each line with stdout: or stderr: for parsing
        local tmp_stdout = "/tmp/vlc_shell_job_stdout_$$"
        local tmp_stderr = "/tmp/vlc_shell_job_stderr_$$"
        one_liner = table.concat({
            "sh -c '",
            "cd \"", command_directory, "\" && ",
            "( ", command, " > ", tmp_stdout, " 2> ", tmp_stderr, " && echo \"", success_designator, "\" >> ", tmp_stdout, " || echo \"", failure_designator, "\" >> ", tmp_stdout, " ); ",
            "cat ", tmp_stdout, " | while IFS= read -r line; do echo \"stdout: $line\"; done; ",
            "cat ", tmp_stderr, " | while IFS= read -r line; do echo \"stderr: $line\"; done; ",
            "rm -f ", tmp_stdout, " ", tmp_stderr,
            "'"
        })
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
        -- UNIX (Linux and macOS)
        -- Use pkill with process group or find child processes via ps
        -- First try to kill by process tree using the PID
        local one_liner = table.concat({
            "sh -c '",
            "kill_tree() { ",
            "  local pid=$1; ",
            "  local children=$(pgrep -P $pid 2>/dev/null); ",
            "  for child in $children; do ",
            "    kill_tree $child; ",
            "  done; ",
            "  kill -9 $pid 2>/dev/null; ",
            "}; ",
            "kill_tree ", pid,
            "'"
        })

        vlc.msg.dbg("Stopping job with command: " .. one_liner)
        result = os.execute(one_liner)
    end

    return result
end


function executor.job_async_run(name, cmd_command, cmd_directory, pid_record, uuid, stdout_file, stderr_file, 
                               status_running, status_success, status_failure)
    local one_liner
    
    if package.config:sub(1,1) == '\\' then
        -- Windows
        one_liner = table.concat({
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
    else
        -- UNIX (Linux and macOS)
        -- Run command in background using nohup and capture PID
        -- The command runs in a subshell that:
        -- 1. Sets status to RUNNING
        -- 2. Truncates stdout/stderr files immediately (so status shows correctly right away)
        -- 3. Runs the command with stdout/stderr redirected
        -- 4. Sets status to SUCCESS or FAILURE based on exit code
        -- 5. Records the background process PID
        -- Run command directly - no eval wrapper needed since shell can handle it
        one_liner = table.concat({
            "sh -c '",
            status_running, " && ",
            "> \"", stdout_file, "\" && ",  -- Truncate stdout file immediately
            "> \"", stderr_file, "\" && ",  -- Truncate stderr file immediately
            "( ",
            "cd \"", cmd_directory, "\" && ",
            cmd_command,  -- Run command directly without eval to avoid quote escaping issues
            " >> \"", stdout_file, "\" 2>> \"", stderr_file, "\" && ",
            status_success, " || ", status_failure,
            " ) &",
            " echo $! > \"", pid_record, "\"",
            "'"
        })
    end
    
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
        -- UNIX (Linux and macOS)
        -- Use a portable approach that works on both GNU and BSD systems
        -- List directories and use stat to get modification times
        local cmd = table.concat({
            "sh -c '",
            "if [ -d \"", base_dir, "\" ]; then ",
            "  for dir in \"", base_dir, "\"/*; do ",
            "    if [ -d \"$dir\" ]; then ",
            "      name=$(basename \"$dir\"); ",
            "      if [ \"$(uname)\" = \"Darwin\" ]; then ",
            "        mtime=$(stat -f \"%m\" \"$dir\" 2>/dev/null); ",
            "      else ",
            "        mtime=$(stat -c \"%Y\" \"$dir\" 2>/dev/null); ",
            "      fi; ",
            "      if [ -n \"$mtime\" ]; then ",
            "        age=$(($(date +%s) - mtime)); ",
            "        echo \"$name|$age\"; ",
            "      fi; ",
            "    fi; ",
            "  done; ",
            "fi",
            "'"
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
