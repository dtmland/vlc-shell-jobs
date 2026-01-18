# Windows Utility Batch Files

This directory contains Windows batch file utilities that replicate the core functionality from the VLC Shell Jobs Lua extension. These utilities are useful for:

1. **Development and debugging** - Test the shell/PowerShell logic outside of VLC
2. **Understanding the implementation** - See the exact commands without Lua escaping
3. **Troubleshooting** - Isolate issues with command execution

## Architecture

The utilities use a two-stage architecture to avoid complex batch escaping issues:

1. **Wrapper batch file** (e.g., `job.bat`) - Lightweight wrapper that:
   - Parses arguments
   - Generates a UUID for temp files
   - Calls the PowerShell generator script

2. **PowerShell generator** (e.g., `create_job.ps1`) - Generates the final `.bat` file:
   - Writing batch from PowerShell avoids complex escaping
   - The generated `.bat` file matches the lua `one_liner` pattern exactly
   - The generated file can be manually run for troubleshooting

3. **Generated runner batch** (e.g., `job_runner.bat`) - The actual execution script:
   - Contains the PowerShell command in the exact format from `shell_execute.lua`
   - Can be inspected and run manually for debugging
   - Cleaned up after execution (but can be preserved by commenting out cleanup)

## Files

### Main Utilities

### `job.bat`

Runs a command synchronously (blocking) and captures stdout/stderr separately.

**Based on:** `executor.blocking_command()` from `shell_execute.lua`

**Usage:**
```batch
job.bat "command" ["working_directory"]
```

**Arguments:**
- `command` - The command to execute (required)
- `working_directory` - Directory to run command from (optional, defaults to `%USERPROFILE%`)

**Examples:**
```batch
REM Simple ping command
job.bat "ping -n 3 localhost"

REM Command with custom working directory
job.bat "dir /b" "C:\Windows"

REM Chained commands
job.bat "ping -n 3 localhost && echo done"
```

**Output:**
The script will display:
- The command being executed
- Working directory
- Runner script path (temporary bat file)
- Result status (SUCCESS/FAILURE)
- Exit code
- Complete STDOUT content
- Complete STDERR content

---

### `job_async_run.bat`

Runs a command asynchronously in the background, polls for status, and displays ongoing output.

**Based on:** 
- `executor.run_cmd_job()` from `shell_execute.lua`
- Various polling functions from `shell_job.lua`

**Usage:**
```batch
job_async_run.bat "command" ["working_directory"] ["job_name"]
```

**Arguments:**
- `command` - The command to execute (required)
- `working_directory` - Directory to run command from (optional, defaults to `%USERPROFILE%`)
- `job_name` - Display name for the job (optional, defaults to "AsyncJob")

**Examples:**
```batch
REM Simple async ping
job_async_run.bat "ping -n 10 localhost"

REM With custom directory and name
job_async_run.bat "ping -n 10 localhost" "C:\Windows" "PingTest"

REM Long-running command
job_async_run.bat "ping -n 30 localhost && ping -n 30 localhost"
```

**Features:**
- Launches command in a minimized window
- Generates unique UUID for job tracking
- Creates status files in `%APPDATA%\jobrunner\<uuid>\`
- Writes a `launch_job.bat` file for the background job execution (allows manual inspection)
- Polls every 2 seconds and displays current stdout/stderr
- Automatically exits when job completes (SUCCESS or FAILURE)
- Displays final status on completion

**Status Values:**
- `RUNNING` - Job is currently executing
- `SUCCESS` - Job completed successfully (exit code 0)
- `FAILURE` - Job completed with an error (non-zero exit code)
- `STOPPED` - Job was stopped manually via `job_async_stop.bat`

**Note on Ctrl+C:** Windows batch files cannot trap Ctrl+C before the system "Terminate batch job (Y/N)?" prompt. If you press Ctrl+C and answer Y, the polling script will exit but the background job continues. Use `job_async_stop.bat` to stop the background job.

---

### `job_async_check.bat`

Checks the status of a running async job by its UUID.

**Based on:** Various polling functions from `shell_job.lua`

**Usage:**
```batch
job_async_check.bat "job_uuid" [tail_lines]
```

**Arguments:**
- `job_uuid` - The UUID of the job to check (required, displayed when job_async_run.bat starts)
- `tail_lines` - Number of lines to show from stdout/stderr (optional, defaults to 50)

**Examples:**
```batch
REM Check a job by UUID
job_async_check.bat "78f734c4-496c-40d0-83f4-127d43e97195"

REM Check with more output lines
job_async_check.bat "78f734c4-496c-40d0-83f4-127d43e97195" 200
```

**Features:**
- Shows current job status (RUNNING, SUCCESS, FAILURE, STOPPED)
- Displays process ID (PID)
- Shows recent stdout/stderr output
- Can be run multiple times while job is running
- Does not stop the job (use `job_async_stop.bat` for that)

---

### `job_async_stop.bat`

Stops a running async job by its UUID.

**Based on:** `executor.stop_job()` from `shell_execute.lua`

**Usage:**
```batch
job_async_stop.bat "job_uuid"
```

**Arguments:**
- `job_uuid` - The UUID of the job to stop (required, displayed when job_async_run.bat starts)

**Examples:**
```batch
REM Stop a job by UUID
job_async_stop.bat "78f734c4-496c-40d0-83f4-127d43e97195"
```

**Features:**
- Finds the job by UUID in `%APPDATA%\jobrunner\<uuid>\`
- Generates a `kill_tree_runner.bat` file (matching the lua one_liner pattern)
- Uses process tree walking to stop all child processes
- Updates job status to STOPPED
- Shows final stdout/stderr at time of stop
- Cleans up the generated script after execution

**How to use:**
1. Run `job_async_run.bat` and note the Job UUID displayed
2. Open a new command prompt
3. Run `job_async_stop.bat "your-job-uuid"` to stop the job

---

### `job_cleanup.bat`

Cleans up old job directories from the jobrunner folder.

**Based on:** `job_runner.cleanup_old_jobs()` from `shell_job.lua`

**Usage:**
```batch
job_cleanup.bat [max_age_seconds]
```

**Arguments:**
- `max_age_seconds` - Maximum age in seconds before a job directory is considered old (optional, defaults to 86400 = 1 day)

**Examples:**
```batch
REM Cleanup jobs older than 1 day (default)
job_cleanup.bat

REM Cleanup jobs older than 1 hour
job_cleanup.bat 3600

REM Cleanup jobs older than 1 week
job_cleanup.bat 604800
```

**Features:**
- Scans `%APPDATA%\jobrunner\` for job directories
- Checks modification time of stdout.txt or job_status.txt files
- Removes directories older than the specified age threshold
- Reports which directories were removed vs kept
- Safe to run at any time - does not affect running jobs that are still recent

---

### PowerShell Generators

### `create_job.ps1`

PowerShell script that generates the `job_runner.bat` file. Called by `job.bat`.

**Parameters:**
- `-Command` - The command to execute
- `-CommandDir` - Working directory
- `-OutputBatFile` - Path to write the generated .bat file
- `-SuccessDesignator` - Success marker text
- `-FailureDesignator` - Failure marker text

---

### `create_job_async_run.ps1`

PowerShell script that generates the `launch_job.bat` file. Called by `job_async_run.bat`.

**Parameters:**
- `-Command` - The command to execute
- `-JobUUID` - The job's unique identifier
- `-StatusFile` - Path to status file
- `-PidFile` - Path to PID file
- `-StdoutFile` - Path to stdout file
- `-StderrFile` - Path to stderr file
- `-OutputBatFile` - Path to write the generated .bat file

---

### `create_job_async_stop.ps1`

PowerShell script that generates the `kill_tree_runner.bat` file. Called by `job_async_stop.bat`.

**Parameters:**
- `-JobPID` - The process ID to kill
- `-JobUUID` - The job's unique identifier (for matching)
- `-OutputBatFile` - Path to write the generated .bat file

---

### Helper Scripts

### `kill_tree.ps1`

Standalone PowerShell script that walks a process tree and kills processes matching a UUID.

**Based on:** The Kill-Tree function from `executor.stop_job()` in `shell_execute.lua`

**Usage:**
```powershell
powershell -File kill_tree.ps1 -ProcessId <pid> -MatchString "<uuid>"
```

**Note:** This is a standalone helper script for manual use. The `job_async_stop.bat` utility uses `create_job_async_stop.ps1` to generate a batch file with the same logic inline.

---

## How These Map to shell_execute.lua

### blocking_command (job.bat)

The Lua code builds a PowerShell one-liner that:
1. Creates a ProcessStartInfo object
2. Sets up cmd.exe as the process with output redirection
3. Runs the command synchronously
4. Captures stdout/stderr with prefixes
5. Determines success/failure via exit code markers

```lua
-- From shell_execute.lua
one_liner = table.concat({
    "powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command ",
    ...
    "$psi = New-Object System.Diagnostics.ProcessStartInfo; ",
    "$psi.FileName = \\\"cmd.exe\\\"; ",
    ...
})
```

### run_cmd_job (job_async_run.bat launch section)

The Lua code uses `start` command to launch a background process:

```lua
-- From shell_execute.lua
background_command = table.concat({
    "start ",
    "\"",name,"\"",
    " /d \"",cmd_directory,"\"",
    " /min cmd.exe /c ",
    ...
})
```

### stop_job (job_async_stop.bat)

The Lua code defines a Kill-Tree PowerShell function that:
1. Walks the process tree from a given PID
2. Matches processes by UUID in command line
3. Only kills processes after finding a match (to avoid killing VLC itself)

```lua
-- From shell_execute.lua
"function Kill-Tree { ",
    "param([int] $ppid, [string] $matchString, [bool] $matchFound = $false); ",
    ...
}; ",
"Kill-Tree ",
"-ppid ", pid, " -matchString ", uuid,
```

---

## Troubleshooting

### Inspecting Generated Files

To inspect the generated batch files before they're cleaned up:
1. Comment out the cleanup lines at the end of the wrapper script
2. Run the command
3. Navigate to `%APPDATA%\jobrunner\<uuid>\` to find the generated files
4. Run the generated `.bat` file manually to test

### Common Issues

1. **PowerShell Execution Policy**: The scripts use `-ExecutionPolicy Bypass` to avoid policy issues
2. **Hidden Windows**: The generated scripts use `-WindowStyle Hidden` to suppress PowerShell window popup
3. **Escaping**: The PowerShell generators handle all escaping, so the generated batch files have correct syntax
4. **PID Recording**: The async job uses WMI to get the parent process ID for proper tree killing

---

## Requirements

- Windows 7 or later
- PowerShell (Windows PowerShell or PowerShell Core)
- Admin rights may be required for some operations (like killing processes)
