local job_runner = require("extensions.shell_job")
local GuiManager = require("extensions.dynamic_dialog")

local runner_instance
local gui_manager

function descriptor()
    return {
        title = "Shell Jobs",
        version = "1.0",
        author = "dtmland",
        url = 'http://www.example.com',
        shortdesc = "Shell Jobs",
        description = [[
            Run os shell command job asynchronously

            This extension allows you to run a shell job asynchronously and check its status.
            It is useful for running long-running jobs that you don't want to block the VLC UI.
            If you block the UI in VLC it gets grumpy and prompts to kill the extension.

            To use, click the 'Run Job' button to start the job. Click the 'Check Job' button to 
            check the job status. The job status will be displayed in the dialog box.

            The job command is hardcoded in the script. You can change the command in the script 
            to run your own job. The script is intended to be a starting point or template for 
            writing your own extension that runs shell jobs in VLC.

            You can stack as many commands as you want in the call to run_job. However, the script
            does not handle multiple jobs running at the same time. If you run multiple jobs at the
            same time, the script will only check the status of the last job that was started.

            Intended to be used for commands that return text output. I haven't tested the script 
            with commands that return binary data, undefined behavior may occur.

            The script creates a directory in the user's home directory to store job output files.
            Both stdout and stderr are redirected to unique files.
            
            Completely independent of this script, but during your development you might be 
            surprised to find that some applications write to stderr even when they are successful, 
            for example, ffmpeg.
            ]],
        capabilities = {},
        icon = png_data,
    }
end

local output_html

local GUI_COL_1 = 1
local GUI_COL_2 = 2
local GUI_COL_3 = 3
local GUI_COL_4 = 4
local GUI_COL_5 = 5
local GUI_COL_6 = 6
local GUI_COL_7 = 7
local GUI_COL_8 = 8
local GUI_COL_9 = 9
local GUI_COL_10 = 10

local GUI_ROW_1 = 1
local GUI_ROW_2 = 2
local GUI_ROW_3 = 3
local GUI_ROW_4 = 4
local GUI_ROW_5 = 5
local GUI_ROW_6 = 6
local GUI_ROW_7 = 7
local GUI_ROW_8 = 8
local GUI_ROW_9 = 9
local GUI_ROW_10 = 10
local GUI_ROW_25 = 25

local MIN_HEIGHT = 10
local MAX_HEIGHT = 50
local MIN_WIDTH = 20
local MAX_WIDTH = 200

local height_in_chars = MIN_HEIGHT
local width_in_chars = MIN_WIDTH
local jump_amount_height = 10
local jump_amount_width = 20
local pipe_labels = {} -- Array to store pipe label widgets
local underscore_label -- Variable to store the underscore label widget
local start_message = "Click 'Run' when ready. Click 'Refresh' to check run status"
local relevant_message = start_message

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
    dlg:add_button("↑", up_button_handler,                1, 2, 1, 1)
    dlg:add_button("↓", down_button_handler,              2, 2, 1, 1)
    dlg:add_button("←", left_button_handler,              3, 2, 1, 1)
    dlg:add_button("→", right_button_handler,             4, 2, 1, 1)

    gui_manager = GuiManager.new(dlg, 10, 20, 10, 20, 10, 50, 20, 200)
    gui_manager:initialize_gui(4, 4)
end

function run_button_handler()
    local result = runner_instance.run()
    gui_manager:update_message(result)
    
    --local result,stdout,stderr = job_runner.job("echo 'Hello World'")
    --local combined_output = "[RESULT]\n" .. tostring(result) .. "\n\n[STDOUT]\n" .. stdout .. "\n\n[STDERR]\n" .. stderr
    --gui_manager:update_message(combined_output)
end

function refresh_button_handler()
    local result = runner_instance.status()
    gui_manager:update_message(result)
end

function abort_button_handler()
    local result = runner_instance.abort()
    gui_manager:update_message(result)
end

function up_button_handler()
    refresh_button_handler()
    gui_manager:adjust_height(-gui_manager.jump_amount_height)
    gui_manager:redraw_gui(4, 4)
end

function down_button_handler()
    refresh_button_handler()
    gui_manager:adjust_height(gui_manager.jump_amount_height)
    gui_manager:redraw_gui(4, 4)
end

function left_button_handler()
    refresh_button_handler()
    gui_manager:adjust_width(-gui_manager.jump_amount_width)
    gui_manager:redraw_gui(4, 4)
end

function right_button_handler()
    refresh_button_handler()
    gui_manager:adjust_width(gui_manager.jump_amount_width)
    gui_manager:redraw_gui(4, 4)
end


