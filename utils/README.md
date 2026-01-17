# Windows Utility Batch Files

This directory contains Windows batch file utilities that replicate the core functionality from the VLC Shell Jobs Lua extension. These utilities are useful for:

1. **Development and debugging** - Test the shell/PowerShell logic outside of VLC
2. **Understanding the implementation** - See the exact commands without Lua escaping
3. **Troubleshooting** - Isolate issues with command execution

## Files

### `block_command.bat`

Runs a command synchronously (blocking) and captures stdout/stderr separately.

**Based on:** `executor.blocking_command()` from `executor.lua`

**Usage:**
```batch
block_command.bat "command" ["working_directory"]
```

**Arguments:**
- `command` - The command to execute (required)
- `working_directory` - Directory to run command from (optional, defaults to `%USERPROFILE%`)

**Examples:**
```batch
REM Simple ping command
block_command.bat "ping -n 3 localhost"

REM Command with custom working directory
block_command.bat "dir /b" "C:\Windows"

REM Chained commands
block_command.bat "ping -n 3 localhost && echo done"
```

**Output:**
The script will display:
- The command being executed
- Working directory
- Result status (SUCCESS/FAILURE)
- Exit code
- Complete STDOUT content
- Complete STDERR content

---

### `async_job.bat`

Runs a command asynchronously in the background, polls for status, and displays ongoing output.

**Based on:** 
- `executor.run_cmd_job()` from `executor.lua`
- Various polling functions from `job_runner.lua`

**Usage:**
```batch
async_job.bat "command" ["working_directory"] ["job_name"]
```

**Arguments:**
- `command` - The command to execute (required)
- `working_directory` - Directory to run command from (optional, defaults to `%USERPROFILE%`)
- `job_name` - Display name for the job (optional, defaults to "AsyncJob")

**Examples:**
```batch
REM Simple async ping
async_job.bat "ping -n 10 localhost"

REM With custom directory and name
async_job.bat "ping -n 10 localhost" "C:\Windows" "PingTest"

REM Long-running command
async_job.bat "ping -n 30 localhost && ping -n 30 localhost"
```

**Features:**
- Launches command in a minimized window
- Generates unique UUID for job tracking
- Creates status files in `%APPDATA%\jobrunner\<uuid>\`
- Polls every 2 seconds and displays current stdout/stderr
- Automatically exits when job completes (SUCCESS or FAILURE)
- Displays final status on completion

**Status Values:**
- `RUNNING` - Job is currently executing
- `SUCCESS` - Job completed successfully (exit code 0)
- `FAILURE` - Job completed with an error (non-zero exit code)
- `STOPPED` - Job was stopped manually via `stop_job.bat`

**Note on Ctrl+C:** Windows batch files cannot trap Ctrl+C before the system "Terminate batch job (Y/N)?" prompt. If you press Ctrl+C and answer Y, the polling script will exit but the background job continues. Use `stop_job.bat` to stop the background job.

---

### `stop_job.bat`

Stops a running async job by its UUID.

**Based on:** `executor.stop_job()` from `executor.lua`

**Usage:**
```batch
stop_job.bat "job_uuid"
```

**Arguments:**
- `job_uuid` - The UUID of the job to stop (required, displayed when async_job.bat starts)

**Examples:**
```batch
REM Stop a job by UUID
stop_job.bat "78f734c4-496c-40d0-83f4-127d43e97195"
```

**Features:**
- Finds the job by UUID in `%APPDATA%\jobrunner\<uuid>\`
- Uses process tree walking to stop all child processes
- Updates job status to STOPPED
- Shows final stdout/stderr at time of stop

**How to use:**
1. Run `async_job.bat` and note the Job UUID displayed
2. Open a new command prompt
3. Run `stop_job.bat "your-job-uuid"` to stop the job

---

## How These Map to executor.lua

### blocking_command (block_command.bat)

The Lua code builds a PowerShell one-liner that:
1. Creates a ProcessStartInfo object
2. Sets up cmd.exe as the process with output redirection
3. Runs the command synchronously
4. Captures stdout/stderr with prefixes
5. Determines success/failure via exit code markers

```lua
-- From executor.lua
one_liner = table.concat({
    "powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command ",
    ...
    "$psi = New-Object System.Diagnostics.ProcessStartInfo; ",
    "$psi.FileName = \\\"cmd.exe\\\"; ",
    ...
})
```

### run_cmd_job (async_job.bat launch section)

The Lua code uses `start` command to launch a background process:

```lua
-- From executor.lua
background_command = table.concat({
    "start ",
    "\"",name,"\"",
    " /d \"",cmd_directory,"\"",
    " /min cmd.exe /c ",
    ...
})
```

### stop_job (stop_job.bat)

The Lua code defines a Kill-Tree PowerShell function that:
1. Walks the process tree from a given PID
2. Matches processes by UUID in command line
3. Only kills processes after finding a match (to avoid killing VLC itself)

```lua
-- From executor.lua
"function Kill-Tree { ",
    "param([int] $ppid, [string] $matchString, [bool] $matchFound = $false); ",
    ...
}; ",
"Kill-Tree ",
"-ppid ", pid, " -matchString ", uuid,
```

---

## Troubleshooting

1. **PowerShell Execution Policy**: The scripts use `-ExecutionPolicy Bypass` to avoid policy issues
2. **Hidden Windows**: Use `-WindowStyle Hidden` to suppress PowerShell window popup
3. **Escaping**: In batch files, `^` is used to escape special characters like `&` and `|`
4. **PID Recording**: The async job uses WMI to get the parent process ID for proper tree killing

---

## Requirements

- Windows 7 or later
- PowerShell (Windows PowerShell or PowerShell Core)
- Admin rights may be required for some operations (like killing processes)
