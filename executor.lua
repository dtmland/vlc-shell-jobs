local executor = {}


function executor.blocking_command(command, command_directory)
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


function executor.stop_job(pid, uuid)
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


function executor.run_cmd_job(name, cmd_command, cmd_directory, pid_record, uuid, stdout_file, stderr_file, 
                               status_running, status_success, status_failure)
    local background_command = table.concat({
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
    
    vlc.msg.info("Running command: " .. background_command)
    local result = os.execute(background_command)
    vlc.msg.dbg("Command executed with result: " .. tostring(result))
end

return executor
