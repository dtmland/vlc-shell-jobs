local job_runner = require("extensions.shell_job")

local runner_instance

local dlg
local html_object

function descriptor()
    return {
        title = "Shell Jobs",
        version = "1.0",
        author = "dtmland",
        url = 'http://www.example.com',
        shortdesc = "Shell Jobs",
        description = [[
            Run os shell command job asynchronously

            The script is intended to be a starting point or template for 
            writing your own extension that runs shell jobs in VLC.

            This extension allows you to run a shell job asynchronously and check its status.
            It is useful for running long-running jobs that you don't want to block the VLC UI.

            To use, click the 'Run Job' button to start the job. Click the 'Check Job' button to 
            check the job status. The job status will be displayed in the dialog box.
            
            You can stack as many commands as you want in instance. 

            Intended to be used for commands that return text output. I haven't tested the script 
            with commands that return binary data, undefined behavior may occur.

            The script creates temporary job files for status and output.
            Both stdout and stderr are redirected to unique files.
            
            Completely independent of this script, but during your development you might be 
            surprised to find that some applications write to stderr even when they are successful, 
            for example, ffmpeg.
            ]],
        capabilities = {},
    }
end



function activate()

    -- Sample command to ping localhost 10 times
    local description = "Ping localhost"
    local command
    if package.config:sub(1,1) == '\\' then
        -- Windows
        command = "ping -n 5 localhost ^&^& ping -n 5 localhost ^&^& ping -n 5 localhost"
    else
        -- UNIX
        command = "ping -c 5 localhost;ping -c 5 localhost;ping -c 5 localhost"
    end

    vlc.msg.info("Job Runner activated")
    runner_instance = job_runner.new()
    runner_instance.initialize(description, command)
    create_dialog()
end

function deactivate()
    vlc.msg.info("Job Runner deactivated")
end

function create_dialog()
    dlg = vlc.dialog("Job Runner")
    dlg:add_button("Run Job", run_button_handler,          1, 1, 1, 1)
    dlg:add_button("Check Status", refresh_button_handler, 2, 1, 1, 1)
    dlg:add_button("Abort Job", abort_button_handler,      3, 1, 1, 1)

    -- Platform detection: Windows via package.config; on Unix try uname -s to detect macOS (Darwin).
    local is_windows = package.config:sub(1,1) == '\\'
    local is_macos = false
    if not is_windows then
        local ok, uname = pcall(function()
            local f = io.popen("uname -s")
            if f then
                local s = f:read("*l")
                f:close()
                return s
            end
            return nil
        end)
        if ok and uname and uname:match("Darwin") then
            is_macos = true
        end
    end

    if is_macos then
        vlc.msg.info("Only print in macos unix")

        dlg:add_button("________________________________________", empty_handler, 4, 1, 1, 1)
        dlg:add_button("|", empty_handler, 5, 1, 1, 1)
        dlg:add_button("|", empty_handler, 5, 2, 1, 1)
        dlg:add_button("|", empty_handler, 5, 3, 1, 1)
        dlg:add_button("|", empty_handler, 5, 4, 1, 1)
        dlg:add_button("|", empty_handler, 5, 5, 1, 1)
        dlg:add_button("|", empty_handler, 5, 6, 1, 1)
        dlg:add_button("|", empty_handler, 5, 7, 1, 1)

        html_object = dlg:add_html("Click 'Run' when ready. Click 'Refresh' to check run status", 1, 4, 4, 4)
    else
        html_object = dlg:add_html("Click 'Run' when ready. Click 'Refresh' to check run status", 1, 2, 50, 50)
    end
end

function empty_handler()
end

function update_message(message)
    if html_object then
        html_object:set_text("<p>" .. message:gsub("\n", "<br>") .. "</p>")
    end
end

function run_button_handler()
    local result = runner_instance.run()
    if type(result) ~= "string" then
        result = tostring(result)
    end
    update_message(result)
    
    -- Example of a synchronous job run
    --local result,stdout,stderr = job_runner.job("echo 'Hello World'")
    --local combined_output = "[RESULT]\n" .. tostring(result) .. "\n\n[STDOUT]\n" .. stdout .. "\n\n[STDERR]\n" .. stderr
    --update_message(combined_output) 
end

function refresh_button_handler()
    local result = runner_instance.status()

    if type(result) ~= "string" then
        result = tostring(result)
    end
    update_message(result)
end

function abort_button_handler()
    local result = runner_instance.abort()

    if type(result) ~= "string" then
        result = tostring(result)
    end
    update_message(result)
end
