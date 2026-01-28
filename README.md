# VLC Shell Jobs

A VLC media player extension for running shell commands asynchronously without blocking the VLC UI.

## Overview

This project provides a VLC extension (`shell_jobs.lua`) that allows you to execute long-running shell commands in the background while using VLC. When you run commands that take a long time through VLC's normal interfaces, VLC can become unresponsive and may prompt to kill the extension. This extension solves that problem by:

- Running commands asynchronously in background processes
- Tracking job status (RUNNING, SUCCESS, FAILURE, STOPPED)
- Capturing stdout and stderr output separately
- Providing a GUI to start jobs and check their status

## Project Structure

```
vlc-shell-jobs/
├── lua/
│   ├── extensions/              # Main VLC extension entry point
│   │   └── shell_jobs.lua       # Extension with GUI
│   └── modules/
│       └── extensions/          # Supporting modules (loaded by shell_jobs.lua)
│           ├── dynamic_dialog.lua
│           ├── os_detect.lua
│           ├── shell_execute.lua
│           ├── shell_job.lua
│           ├── shell_job_defs.lua
│           ├── shell_job_state.lua
│           ├── shell_operator_fileio.lua
│           └── tests/           # Lua module unit tests
├── utils/
│   └── win/                     # Windows batch file utilities
│       ├── *.bat, *.ps1         # Utility scripts
│       └── tests/               # Windows utility tests
└── install/                     # Installation scripts
```

### Core Lua Extension Files

- **`lua/extensions/shell_jobs.lua`** - Main VLC extension entry point with GUI

### Supporting Modules (`lua/modules/extensions/`)

These modules provide clear separation of concerns and improve testability:

- **`os_detect.lua`** - OS detection utilities
  - Platform detection (is_windows, is_macos, is_linux, is_unix)
  - Cached detection results for performance
  - Path separator helpers
- **`shell_execute.lua`** - Core command execution logic (blocking and async commands)
- **`shell_job.lua`** - Job management and status tracking (orchestrates the modules below)
- **`dynamic_dialog.lua`** - GUI management for the VLC extension dialog
- **`shell_job_defs.lua`** - Shared constants and path utilities (acts like a C header file)
  - Job status constants (RUNNING, SUCCESS, FAILURE)
  - File name constants (job_status.txt, job_uuid.txt, etc.)
  - Platform-aware path building functions
- **`shell_operator_fileio.lua`** - File-based IPC operations
  - Reading/writing status, UUID, PID, stdout, stderr files
  - Abstracts file I/O from job logic
  - Enables future replacement with different IPC mechanisms
- **`shell_job_state.lua`** - State machine for job lifecycle
  - Clear state definitions (NO_JOB, PENDING, RUNNING, SUCCESS, FAILURE)
  - State query functions (is_running, is_finished, can_run, can_abort)
  - Human-readable blocking reason messages

### Windows Utilities (`utils/win/`)

The `utils/win/` directory contains Windows batch file utilities that replicate the VLC extension's functionality for standalone use. These are useful for:

- **Development and debugging** - Test the shell/PowerShell logic outside of VLC
- **Understanding the implementation** - See the exact commands without Lua escaping
- **Troubleshooting** - Isolate issues with command execution

**Main utilities:**
- `job.bat` - Run commands synchronously (blocking)
- `job_async_run.bat` - Run commands asynchronously in background
- `job_async_check.bat` - Check status of running jobs
- `job_async_stop.bat` - Stop running jobs by UUID

See [utils/win/README.md](utils/win/README.md) for detailed documentation.

### Tests

- **`utils/win/tests/`** - Comprehensive test suites for the Windows batch utilities, written in PowerShell with BAT wrappers for easy execution. See [utils/win/tests/README.md](utils/win/tests/README.md).

- **`lua/modules/extensions/tests/`** - Unit tests for the Lua modules, designed to run standalone outside of VLC. See [lua/modules/extensions/tests/README.md](lua/modules/extensions/tests/README.md).

## Installation

### Quick Install (Recommended)

Use the setup scripts in the `install/` directory:

**Windows (PowerShell):**
```powershell
.\install\setup-windows.ps1
```

**Linux (Bash):**
```bash
./install/setup-linux.sh
```

**macOS (Bash):**
```bash
./install/setup-macos.sh
```

### Manual Installation

Copy the Lua files to your VLC directory structure:

1. Copy `lua/extensions/shell_jobs.lua` to your VLC extensions directory:
   - **Windows**: `%APPDATA%\vlc\lua\extensions\`
   - **macOS**: `~/Library/Application Support/org.videolan.vlc/lua/extensions/`
   - **Linux**: `~/.local/share/vlc/lua/extensions/`

2. Copy all files from `lua/modules/extensions/` (except `tests/`) to your VLC modules directory:
   - **Windows**: `%APPDATA%\vlc\lua\modules\extensions\`
   - **macOS**: `~/Library/Application Support/org.videolan.vlc/lua/modules/extensions/`
   - **Linux**: `~/.local/share/vlc/lua/modules/extensions/`

3. Restart VLC

4. Access the extension via VLC menu: **View** → **Shell Jobs**

### VLC Directory Structure

VLC uses a `Roaming` AppData directory on Windows (`%APPDATA%`) because user preferences and extensions should follow the user across different machines in a domain environment. This is standard Windows behavior for user-specific application data that isn't machine-dependent.

## Usage

### In VLC

1. Open the Shell Jobs extension from the VLC menu
2. Click "Run Job" to start the configured command (edit `shell_jobs.lua` to customize)
3. Click "Refresh" to check the job status and see output
4. The extension displays real-time stdout/stderr output

### Standalone (Windows)

Use the batch file utilities in the `utils/win/` directory to run commands outside of VLC:

```batch
REM Run a command synchronously
utils\win\job.bat "ping -n 5 localhost"

REM Run a command asynchronously
utils\win\job_async_run.bat "ping -n 10 localhost" "C:\Windows" "MyPingTest"

REM Check job status (use UUID from previous command)
utils\win\job_async_check.bat "78f734c4-496c-40d0-83f4-127d43e97195"

REM Stop a running job
utils\win\job_async_stop.bat "78f734c4-496c-40d0-83f4-127d43e97195"
```

## Platform Support

- **VLC Extension**: Cross-platform (Windows, macOS, Linux)
  - Currently, only Windows implementation is complete in `shell_execute.lua`
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

The Windows batch utilities in `utils/win/` are helpful for development:

1. Test command execution logic without VLC
2. Inspect generated batch files for debugging
3. Understand the exact PowerShell commands being executed
4. Verify command escaping and output handling

### Running Tests

**Lua module tests:**
```bash
cd lua/modules/extensions/tests
./run_lua_tests.sh
```

**Windows utility tests:**
```batch
cd utils\win\tests
run_all_tests.bat
```

## License

See repository license information.

## Author

dtmland
