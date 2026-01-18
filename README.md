# VLC Shell Jobs

A VLC media player extension for running shell commands asynchronously without blocking the VLC UI.

## Overview

This project provides a VLC extension (`shell_jobs.lua`) that allows you to execute long-running shell commands in the background while using VLC. When you run commands that take a long time through VLC's normal interfaces, VLC can become unresponsive and may prompt to kill the extension. This extension solves that problem by:

- Running commands asynchronously in background processes
- Tracking job status (RUNNING, SUCCESS, FAILURE, STOPPED)
- Capturing stdout and stderr output separately
- Providing a GUI to start jobs and check their status

## Project Structure

### Core Lua Extension Files

- **`shell_jobs.lua`** - Main VLC extension entry point with GUI
- **`executor.lua`** - Core command execution logic (blocking and async commands)
- **`job_runner.lua`** - Job management and status tracking
- **`gui_manager.lua`** - GUI management for the VLC extension dialog

### Windows Utilities (`utils/`)

The `utils/` directory contains Windows batch file utilities that replicate the VLC extension's functionality for standalone use. These are useful for:

- **Development and debugging** - Test the shell/PowerShell logic outside of VLC
- **Understanding the implementation** - See the exact commands without Lua escaping
- **Troubleshooting** - Isolate issues with command execution

**Main utilities:**
- `job.bat` - Run commands synchronously (blocking)
- `job_async_run.bat` - Run commands asynchronously in background
- `job_async_check.bat` - Check status of running jobs
- `job_async_stop.bat` - Stop running jobs by UUID

See [utils/README.md](utils/README.md) for detailed documentation.

### Tests (`utils/tests/`)

Comprehensive test suites for the Windows batch utilities, written in PowerShell with BAT wrappers for easy execution.

See [utils/tests/README.md](utils/tests/README.md) for detailed documentation.

## Installation

1. Copy the Lua extension files (`shell_jobs.lua`, `executor.lua`, `job_runner.lua`, `gui_manager.lua`) to your VLC extensions directory:
   - **Windows**: `%APPDATA%\vlc\lua\extensions\`
   - **macOS**: `~/Library/Application Support/org.videolan.vlc/lua/extensions/`
   - **Linux**: `~/.local/share/vlc/lua/extensions/`

2. Restart VLC

3. Access the extension via VLC menu: **View** → **Shell Jobs**

## Usage

### In VLC

1. Open the Shell Jobs extension from the VLC menu
2. Click "Run Job" to start the configured command (edit `shell_jobs.lua` to customize)
3. Click "Refresh" to check the job status and see output
4. The extension displays real-time stdout/stderr output

### Standalone (Windows)

Use the batch file utilities in the `utils/` directory to run commands outside of VLC:

```batch
REM Run a command synchronously
utils\job.bat "ping -n 5 localhost"

REM Run a command asynchronously
utils\job_async_run.bat "ping -n 10 localhost" "C:\Windows" "MyPingTest"

REM Check job status (use UUID from previous command)
utils\job_async_check.bat "78f734c4-496c-40d0-83f4-127d43e97195"

REM Stop a running job
utils\job_async_stop.bat "78f734c4-496c-40d0-83f4-127d43e97195"
```

## Platform Support

- **VLC Extension**: Cross-platform (Windows, macOS, Linux)
  - Currently, only Windows implementation is complete in `executor.lua`
  - UNIX support marked as TODO
- **Batch Utilities**: Windows only (requires PowerShell)

## How It Works

The extension uses a multi-stage architecture:

1. **Lua Extension Layer** - Provides VLC integration and GUI
2. **Executor Layer** - Generates and executes PowerShell commands
3. **Job Tracking** - Uses filesystem-based status files in `%APPDATA%\jobrunner\`

For Windows commands, the executor builds PowerShell one-liners that:
- Create process start info objects
- Execute commands with proper output redirection
- Track process IDs for background jobs
- Enable process tree killing for clean job termination

## Development

The Windows batch utilities in `utils/` are helpful for development:

1. Test command execution logic without VLC
2. Inspect generated batch files for debugging
3. Understand the exact PowerShell commands being executed
4. Verify command escaping and output handling

To run tests:

```batch
cd utils\tests
run_all_tests.bat
```

## License

See repository license information.

## Author

dtmland
