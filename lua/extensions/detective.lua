--[[
Detective - VLC Extension for Scene Detection and Bookmarking
Author: dtmland
Description: Uses FFmpeg scene detection to create XSPF bookmarks for videos
]]

local job_runner = require("extensions.shell_job")
local os_detect = require("extensions.os_detect")

-- State management
local state = {
    setup_complete = false,
    ffmpeg_path = nil,
    ffprobe_path = nil,
    current_job = nil,
    last_video_path = nil,
    last_xspf_path = nil,
    scene_count = 0,
    open_xspf_after_completion = false
}

-- Dialog references
local dlg = nil
local main_menu_dlg = nil
local setup_dlg = nil
local scene_detection_dlg = nil
local status_html = nil

-- Configuration file path
local config_file_path = nil

--------------------------------------------------------------------------------
-- Extension Descriptor
--------------------------------------------------------------------------------
function descriptor()
    return {
        title = "Detective",
        version = "1.0",
        author = "dtmland",
        url = 'https://github.com/dtmland/vlc-shell-jobs',
        shortdesc = "Detective - Scene Detection and Bookmarking",
        description = [[
Detective - VLC Extension for Scene Detection and Bookmarking

This extension uses FFmpeg to detect scenes in videos and creates XSPF
bookmarks for easy navigation. Features include:

- Non-blocking scene detection using vlc-shell-jobs
- Automatic XSPF playlist generation with scene bookmarks
- Real-time progress monitoring
- Configurable FFmpeg/FFprobe paths
- Option to open results in new VLC instance

Usage:
1. First, configure FFmpeg/FFprobe paths in Setup menu
2. Open a video in VLC
3. Run Detective > Scene Bookmarks to detect scenes
4. Generated XSPF file will contain bookmarks at each scene change

The extension uses vlc-shell-jobs for non-blocking command execution,
ensuring VLC remains responsive during long operations.
        ]],
        capabilities = {},
    }
end

--------------------------------------------------------------------------------
-- Activation/Deactivation
--------------------------------------------------------------------------------
function activate()
    vlc.msg.info("Detective extension activated")
    
    -- Initialize configuration file path
    config_file_path = get_config_path()
    
    -- Load configuration
    load_config()
    
    -- Show main menu
    show_main_menu()
end

function deactivate()
    vlc.msg.info("Detective extension deactivated")
    
    -- Cleanup any running jobs
    if state.current_job then
        state.current_job.abort()
        state.current_job = nil
    end
    
    -- Close any open dialogs
    if dlg then dlg:delete() end
    if main_menu_dlg then main_menu_dlg:delete() end
    if setup_dlg then setup_dlg:delete() end
    if scene_detection_dlg then scene_detection_dlg:delete() end
end

--------------------------------------------------------------------------------
-- Configuration Management
--------------------------------------------------------------------------------
function get_config_path()
    local config_dir
    if os_detect.is_windows() then
        config_dir = os.getenv("APPDATA") .. "\\vlc\\lua\\extensions"
    else
        config_dir = os.getenv("HOME") .. "/.config/vlc/lua/extensions"
    end
    
    -- Ensure directory exists
    local separator = os_detect.is_windows() and "\\" or "/"
    return config_dir .. separator .. "detective_config.txt"
end

function save_config()
    local file = io.open(config_file_path, "w")
    if file then
        file:write("ffmpeg_path=" .. (state.ffmpeg_path or "") .. "\n")
        file:write("ffprobe_path=" .. (state.ffprobe_path or "") .. "\n")
        file:write("setup_complete=" .. tostring(state.setup_complete) .. "\n")
        file:close()
        return true
    end
    return false
end

function load_config()
    local file = io.open(config_file_path, "r")
    if file then
        for line in file:lines() do
            local key, value = line:match("^([^=]+)=(.*)$")
            if key == "ffmpeg_path" and value ~= "" then
                state.ffmpeg_path = value
            elseif key == "ffprobe_path" and value ~= "" then
                state.ffprobe_path = value
            elseif key == "setup_complete" then
                state.setup_complete = (value == "true")
            end
        end
        file:close()
        return true
    end
    return false
end

--------------------------------------------------------------------------------
-- Main Menu
--------------------------------------------------------------------------------
function show_main_menu()
    if main_menu_dlg then main_menu_dlg:delete() end
    
    main_menu_dlg = vlc.dialog("Detective")
    
    local row = 1
    main_menu_dlg:add_label("<b>Detective - Scene Detection Extension</b>", 1, row, 2, 1)
    row = row + 1
    
    main_menu_dlg:add_label("", 1, row, 2, 1)  -- Spacer
    row = row + 1
    
    -- Setup button
    main_menu_dlg:add_button("Setup", function() show_setup_dialog() end, 1, row, 1, 1)
    if state.setup_complete then
        main_menu_dlg:add_label("✓ Configured", 2, row, 1, 1)
    else
        main_menu_dlg:add_label("⚠ Required", 2, row, 1, 1)
    end
    row = row + 1
    
    -- Scene Bookmarks button
    local scene_btn_enabled = state.setup_complete
    if scene_btn_enabled then
        main_menu_dlg:add_button("Scene Bookmarks", function() show_scene_bookmarks_dialog() end, 1, row, 2, 1)
    else
        main_menu_dlg:add_label("Scene Bookmarks (Setup Required)", 1, row, 2, 1)
    end
    row = row + 1
    
    main_menu_dlg:add_label("", 1, row, 2, 1)  -- Spacer
    row = row + 1
    
    -- Help button
    main_menu_dlg:add_button("Help", function() show_help_dialog() end, 1, row, 2, 1)
    row = row + 1
    
    -- Deactivate button
    main_menu_dlg:add_button("Deactivate", function() 
        main_menu_dlg:delete()
        deactivate()
    end, 1, row, 2, 1)
end

--------------------------------------------------------------------------------
-- Setup Dialog
--------------------------------------------------------------------------------
function show_setup_dialog()
    if setup_dlg then setup_dlg:delete() end
    
    setup_dlg = vlc.dialog("Detective Setup")
    
    local row = 1
    setup_dlg:add_label("<b>Configure CLI Tools</b>", 1, row, 3, 1)
    row = row + 1
    
    setup_dlg:add_label("", 1, row, 3, 1)  -- Spacer
    row = row + 1
    
    -- FFmpeg path
    setup_dlg:add_label("FFmpeg Path:", 1, row, 1, 1)
    local ffmpeg_input = setup_dlg:add_text_input(state.ffmpeg_path or "ffmpeg", 2, row, 1, 1)
    setup_dlg:add_button("Browse", function() end, 3, row, 1, 1)  -- Placeholder for browse
    row = row + 1
    
    -- FFprobe path
    setup_dlg:add_label("FFprobe Path:", 1, row, 1, 1)
    local ffprobe_input = setup_dlg:add_text_input(state.ffprobe_path or "ffprobe", 2, row, 1, 1)
    setup_dlg:add_button("Browse", function() end, 3, row, 1, 1)  -- Placeholder for browse
    row = row + 1
    
    setup_dlg:add_label("", 1, row, 3, 1)  -- Spacer
    row = row + 1
    
    -- Status display
    local status_display = setup_dlg:add_html("Click 'Verify' to check if tools are installed and functional", 1, row, 3, 3)
    row = row + 3
    
    setup_dlg:add_label("", 1, row, 3, 1)  -- Spacer
    row = row + 1
    
    -- Action buttons
    setup_dlg:add_button("Verify", function()
        verify_cli_tools(ffmpeg_input, ffprobe_input, status_display)
    end, 1, row, 1, 1)
    
    setup_dlg:add_button("Save", function()
        state.ffmpeg_path = ffmpeg_input:get_text()
        state.ffprobe_path = ffprobe_input:get_text()
        save_config()
        status_display:set_text("<b style='color:green'>Configuration saved!</b>")
    end, 2, row, 1, 1)
    
    setup_dlg:add_button("Close", function()
        setup_dlg:delete()
        show_main_menu()
    end, 3, row, 1, 1)
end

function verify_cli_tools(ffmpeg_input, ffprobe_input, status_display)
    local ffmpeg_path = ffmpeg_input:get_text()
    local ffprobe_path = ffprobe_input:get_text()
    
    status_display:set_text("<b>Verifying CLI tools...</b><br>Please wait...")
    
    -- Create verification job
    local verify_job = job_runner.new()
    local verify_cmd
    
    if os_detect.is_windows() then
        verify_cmd = string.format('"%s" -version && "%s" -version', ffmpeg_path, ffprobe_path)
    else
        verify_cmd = string.format('%s -version && %s -version', ffmpeg_path, ffprobe_path)
    end
    
    -- Run synchronous job for verification
    local success, stdout, stderr = job_runner.job(verify_cmd)
    
    if success and stdout:match("ffmpeg") and stdout:match("ffprobe") then
        state.ffmpeg_path = ffmpeg_path
        state.ffprobe_path = ffprobe_path
        state.setup_complete = true
        save_config()
        
        local version_info = extract_version_info(stdout)
        status_display:set_text(string.format(
            "<b style='color:green'>✓ Verification Successful!</b><br><br>%s",
            version_info
        ))
        
        -- Update main menu to reflect setup completion
        if main_menu_dlg then
            main_menu_dlg:delete()
            show_main_menu()
        end
    else
        state.setup_complete = false
        local error_msg = stderr and stderr ~= "" and stderr or "Tools not found or not functional"
        status_display:set_text(string.format(
            "<b style='color:red'>✗ Verification Failed</b><br><br>%s<br><br>Please check the paths and try again.",
            escape_html(error_msg)
        ))
    end
end

function extract_version_info(output)
    local ffmpeg_version = output:match("ffmpeg version ([^%s]+)")
    local ffprobe_version = output:match("ffprobe version ([^%s]+)")
    
    return string.format(
        "FFmpeg: %s<br>FFprobe: %s",
        ffmpeg_version or "Unknown",
        ffprobe_version or "Unknown"
    )
end

--------------------------------------------------------------------------------
-- Scene Bookmarks Dialog
--------------------------------------------------------------------------------
function show_scene_bookmarks_dialog()
    if scene_detection_dlg then scene_detection_dlg:delete() end
    
    scene_detection_dlg = vlc.dialog("Scene Detection")
    
    local row = 1
    scene_detection_dlg:add_label("<b>Scene Detection & Bookmarking</b>", 1, row, 2, 1)
    row = row + 1
    
    scene_detection_dlg:add_label("", 1, row, 2, 1)  -- Spacer
    row = row + 1
    
    -- Get current video
    local input = vlc.input.item()
    local video_path = nil
    local video_name = "No video loaded"
    
    if input then
        video_path = input:uri()
        -- Clean up URI to file path
        if video_path:match("^file://") then
            video_path = video_path:gsub("^file:///?", "")
            -- URL decode
            video_path = video_path:gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end)
        end
        video_name = input:name()
    end
    
    scene_detection_dlg:add_label("Video:", 1, row, 1, 1)
    scene_detection_dlg:add_label(video_name, 2, row, 1, 1)
    row = row + 1
    
    scene_detection_dlg:add_label("", 1, row, 2, 1)  -- Spacer
    row = row + 1
    
    -- Options
    scene_detection_dlg:add_label("Threshold (0.1-1.0):", 1, row, 1, 1)
    local threshold_input = scene_detection_dlg:add_text_input("0.4", 2, row, 1, 1)
    row = row + 1
    
    local open_checkbox = scene_detection_dlg:add_check_box("Open XSPF in new VLC instance after completion", false, 1, row, 2, 1)
    row = row + 1
    
    scene_detection_dlg:add_label("", 1, row, 2, 1)  -- Spacer
    row = row + 1
    
    -- Status display
    local status_html_obj = scene_detection_dlg:add_html("Click 'Start Detection' to begin", 1, row, 2, 5)
    row = row + 5
    
    scene_detection_dlg:add_label("", 1, row, 2, 1)  -- Spacer
    row = row + 1
    
    -- Action buttons
    scene_detection_dlg:add_button("Start Detection", function()
        if video_path then
            state.open_xspf_after_completion = open_checkbox:get_checked()
            start_scene_detection(video_path, threshold_input:get_text(), status_html_obj)
        else
            status_html_obj:set_text("<b style='color:red'>Error: No video loaded</b>")
        end
    end, 1, row, 1, 1)
    
    scene_detection_dlg:add_button("Refresh Status", function()
        refresh_detection_status()
    end, 2, row, 1, 1)
    
    row = row + 1
    
    scene_detection_dlg:add_button("Close", function()
        -- Cleanup job if still running
        if state.current_job then
            state.current_job.abort()
            state.current_job = nil
        end
        scene_detection_dlg:delete()
        show_main_menu()
    end, 1, row, 2, 1)
end

--------------------------------------------------------------------------------
-- Scene Detection
--------------------------------------------------------------------------------
function start_scene_detection(video_path, threshold, status_html_obj)
    status_html_obj:set_text("<b>Starting scene detection...</b><br>Please wait, this may take several minutes.")
    
    -- Create output paths
    local video_dir = get_directory(video_path)
    local video_basename = get_basename(video_path)
    local output_base = video_dir .. get_separator() .. video_basename
    local scenes_file = output_base .. "_scenes.txt"
    local xspf_file = output_base .. "_scenes.xspf"
    
    -- Store paths
    state.last_video_path = video_path
    state.last_xspf_path = xspf_file
    
    -- Build FFmpeg command for scene detection
    local ffmpeg_cmd = build_scene_detection_command(video_path, threshold, scenes_file)
    
    -- Create and run job
    state.current_job = job_runner.new()
    state.current_job.initialize("Scene Detection", ffmpeg_cmd, video_dir)
    
    local result = state.current_job.run()
    vlc.msg.info(result)
    
    -- Start polling for completion
    poll_job_status(status_html_obj, scenes_file, xspf_file)
end

function build_scene_detection_command(video_path, threshold, scenes_file)
    local cmd
    
    -- FFmpeg command to detect scenes
    -- We use select filter with scene detection and metadata output
    if os_detect.is_windows() then
        cmd = string.format(
            '"%s" -i "%s" -vf "select=\'gt(scene,%s)\',showinfo" -f null - 2>&1 | findstr "pts_time" > "%s"',
            state.ffmpeg_path,
            video_path,
            threshold,
            scenes_file
        )
    else
        cmd = string.format(
            '%s -i "%s" -vf "select=\'gt(scene,%s)\',showinfo" -f null - 2>&1 | grep "pts_time" > "%s"',
            state.ffmpeg_path,
            video_path,
            threshold,
            scenes_file
        )
    end
    
    return cmd
end

function poll_job_status(status_html_obj, scenes_file, xspf_file)
    -- Show initial running status
    status_html_obj:set_text(
        "<b>Scene detection running...</b><br><br>" ..
        "Click 'Refresh Status' below to check progress.<br>" ..
        "This operation runs in the background and won't block VLC."
    )
    
    -- Store references for refresh button
    state.status_display = status_html_obj
    state.scenes_file = scenes_file
    state.xspf_file = xspf_file
    
    -- Add a refresh button if dialog still exists
    if scene_detection_dlg then
        -- Note: Button creation needs to happen in initial dialog setup
        -- This is a limitation we'll document
    end
end

function refresh_detection_status()
    if not state.current_job then return end
    if not state.status_display then return end
    
    local status_text = state.current_job.status()
    
    if status_text:match("SUCCESS") then
        -- Job completed successfully
        local stdout = state.current_job.get_stdout()
        local stderr = state.current_job.get_stderr()
        
        -- Parse scenes and create XSPF
        local scenes = parse_scene_file(state.scenes_file)
        state.scene_count = #scenes
        
        if #scenes > 0 then
            create_xspf_with_scenes(state.xspf_file, state.last_video_path, scenes)
            
            local summary = string.format(
                "<b style='color:green'>✓ Detection Complete!</b><br><br>" ..
                "Scenes detected: %d<br>" ..
                "XSPF file: %s<br><br>" ..
                "Stdout: %s<br>" ..
                "Stderr: %s<br><br>" ..
                "Output saved to:<br>%s",
                #scenes,
                escape_html(get_filename(state.xspf_file)),
                escape_html(state.scenes_file),
                escape_html(state.scenes_file:gsub("_scenes.txt", "_stdout.txt")),
                escape_html(state.xspf_file)
            )
            state.status_display:set_text(summary)
            
            -- Open XSPF if requested
            if state.open_xspf_after_completion then
                open_xspf_in_vlc(state.xspf_file)
            end
        else
            state.status_display:set_text(
                "<b style='color:orange'>⚠ No scenes detected</b><br><br>" ..
                "Try adjusting the threshold value.<br><br>" ..
                "Stderr output:<br>" .. escape_html(stderr)
            )
        end
        
        state.current_job = nil
    elseif status_text:match("FAILURE") or status_text:match("STOPPED") then
        local stderr = state.current_job.get_stderr()
        state.status_display:set_text(
            "<b style='color:red'>✗ Detection Failed</b><br><br>" ..
            escape_html(stderr)
        )
        state.current_job = nil
    else
        -- Still running - show progress
        local stderr = state.current_job.get_stderr()
        local progress_info = extract_progress_info(stderr)
        state.status_display:set_text(
            "<b>Detection in progress...</b><br><br>" ..
            progress_info .. "<br><br>" ..
            "Click 'Refresh Status' to update."
        )
    end
end

function parse_scene_file(scenes_file)
    local scenes = {}
    local file = io.open(scenes_file, "r")
    
    if file then
        for line in file:lines() do
            -- Parse pts_time from FFmpeg showinfo output
            local pts_time = line:match("pts_time:([%d%.]+)")
            if pts_time then
                table.insert(scenes, tonumber(pts_time))
            end
        end
        file:close()
    end
    
    return scenes
end

function extract_progress_info(stderr)
    if not stderr or stderr == "" then
        return "Processing..."
    end
    
    -- Extract frame, fps, time info from FFmpeg output
    local frame = stderr:match("frame=%s*(%d+)")
    local fps = stderr:match("fps=%s*([%d%.]+)")
    local time = stderr:match("time=%s*([%d:%.]+)")
    
    if frame and time then
        return string.format("Frame: %s | Time: %s | FPS: %s", frame, time, fps or "N/A")
    end
    
    return "Processing..."
end

--------------------------------------------------------------------------------
-- XSPF Generation
--------------------------------------------------------------------------------
function write_xspf_file(filename, xspf_data)
    --[[
    General XSPF writing function
    
    xspf_data structure:
    {
        title = "Playlist Title",
        creator = "Creator Name",
        tracks = {
            {
                location = "file:///path/to/video.mp4",
                title = "Track Title",
                extension = {
                    {application = "http://www.videolan.org/vlc/playlist/0",
                     items = {"vlc:id=0", ...}}
                }
            }
        }
    }
    ]]
    
    local file = io.open(filename, "w")
    if not file then
        return false, "Could not open file for writing"
    end
    
    -- Write XSPF header
    file:write('<?xml version="1.0" encoding="UTF-8"?>\n')
    file:write('<playlist xmlns="http://xspf.org/ns/0/" xmlns:vlc="http://www.videolan.org/vlc/playlist/ns/0/" version="1">\n')
    
    -- Write title and creator if provided
    if xspf_data.title then
        file:write('  <title>' .. escape_xml(xspf_data.title) .. '</title>\n')
    end
    if xspf_data.creator then
        file:write('  <creator>' .. escape_xml(xspf_data.creator) .. '</creator>\n')
    end
    
    -- Write trackList
    file:write('  <trackList>\n')
    
    for _, track in ipairs(xspf_data.tracks or {}) do
        file:write('    <track>\n')
        
        if track.location then
            file:write('      <location>' .. escape_xml(track.location) .. '</location>\n')
        end
        if track.title then
            file:write('      <title>' .. escape_xml(track.title) .. '</title>\n')
        end
        
        -- Write extensions
        if track.extension then
            for _, ext in ipairs(track.extension) do
                file:write('      <extension application="' .. escape_xml(ext.application) .. '">\n')
                for _, item in ipairs(ext.items or {}) do
                    file:write('        ' .. item .. '\n')
                end
                file:write('      </extension>\n')
            end
        end
        
        file:write('    </track>\n')
    end
    
    file:write('  </trackList>\n')
    file:write('</playlist>\n')
    
    file:close()
    return true
end

function create_xspf_with_scenes(xspf_file, video_path, scenes)
    --[[
    Scene-bookmarks-specific XSPF function
    Uses the general write_xspf_file function
    ]]
    
    -- Convert file path to file:// URI
    local video_uri = path_to_uri(video_path)
    
    -- Build bookmarks in VLC extension format
    local bookmark_items = {}
    table.insert(bookmark_items, '<vlc:id>0</vlc:id>')
    
    for i, scene_time in ipairs(scenes) do
        -- Convert time to milliseconds
        local time_ms = math.floor(scene_time * 1000)
        table.insert(bookmark_items, string.format('<vlc:option>bookmark%d=%d</vlc:option>', i, time_ms))
        table.insert(bookmark_items, string.format('<vlc:option>bookmark-name%d=Scene %d</vlc:option>', i, i))
    end
    
    -- Build XSPF data structure
    local xspf_data = {
        title = get_filename(video_path) .. " - Scene Bookmarks",
        creator = "Detective Extension",
        tracks = {
            {
                location = video_uri,
                title = get_filename(video_path),
                extension = {
                    {
                        application = "http://www.videolan.org/vlc/playlist/0",
                        items = bookmark_items
                    }
                }
            }
        }
    }
    
    return write_xspf_file(xspf_file, xspf_data)
end

function open_xspf_in_vlc(xspf_path)
    -- Open XSPF in new VLC instance
    local cmd
    
    if os_detect.is_windows() then
        -- Use Windows 'start' command to open with default program
        cmd = string.format('start "" "%s"', xspf_path)
    elseif os_detect.is_macos() then
        cmd = string.format('open "%s"', xspf_path)
    else
        -- Linux - try xdg-open
        cmd = string.format('xdg-open "%s"', xspf_path)
    end
    
    -- Execute command
    os.execute(cmd)
end

--------------------------------------------------------------------------------
-- Help Dialog
--------------------------------------------------------------------------------
function show_help_dialog()
    local help_dlg = vlc.dialog("Detective Help")
    
    local help_text = [[
<h2>Detective - Scene Detection Extension</h2>

<h3>Quick Start:</h3>
<ol>
<li><b>Setup:</b> Configure paths to FFmpeg and FFprobe</li>
<li><b>Load Video:</b> Open a video file in VLC</li>
<li><b>Detect Scenes:</b> Use Scene Bookmarks to detect scenes</li>
<li><b>Review:</b> Open the generated XSPF file to view bookmarks</li>
</ol>

<h3>Features:</h3>
<ul>
<li>Non-blocking scene detection</li>
<li>Automatic XSPF playlist generation</li>
<li>Real-time progress monitoring</li>
<li>Configurable detection threshold</li>
<li>Option to open results automatically</li>
</ul>

<h3>Threshold Guide:</h3>
<ul>
<li><b>0.1-0.3:</b> More sensitive (more scenes detected)</li>
<li><b>0.4:</b> Balanced (recommended)</li>
<li><b>0.5-1.0:</b> Less sensitive (fewer scenes)</li>
</ul>

<h3>Requirements:</h3>
<ul>
<li>FFmpeg installed and accessible</li>
<li>FFprobe installed and accessible</li>
</ul>

<p><i>For more information, visit the project repository.</i></p>
    ]]
    
    help_dlg:add_html(help_text, 1, 1, 1, 20)
    help_dlg:add_button("Close", function() help_dlg:delete() end, 1, 21, 1, 1)
end

--------------------------------------------------------------------------------
-- Utility Functions
--------------------------------------------------------------------------------
function escape_html(text)
    if not text then return "" end
    text = text:gsub("&", "&amp;")
    text = text:gsub("<", "&lt;")
    text = text:gsub(">", "&gt;")
    text = text:gsub('"', "&quot;")
    text = text:gsub("'", "&#39;")
    return text
end

function escape_xml(text)
    if not text then return "" end
    text = text:gsub("&", "&amp;")
    text = text:gsub("<", "&lt;")
    text = text:gsub(">", "&gt;")
    text = text:gsub('"', "&quot;")
    text = text:gsub("'", "&apos;")
    return text
end

function get_separator()
    return os_detect.is_windows() and "\\" or "/"
end

function get_directory(path)
    local sep = get_separator()
    return path:match("(.*)" .. sep)
end

function get_filename(path)
    local sep = get_separator()
    return path:match(".*" .. sep .. "(.*)") or path
end

function get_basename(path)
    local filename = get_filename(path)
    return filename:match("(.+)%..+") or filename
end

function path_to_uri(path)
    if os_detect.is_windows() then
        -- Convert Windows path to file:// URI
        path = path:gsub("\\", "/")
        return "file:///" .. path
    else
        return "file://" .. path
    end
end
