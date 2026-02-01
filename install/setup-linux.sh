#!/bin/sh
#
# VLC Shell Jobs - Linux Setup
#
# Wrapper script that calls the core installer with shell-jobs specific parameters.
# Installs the VLC Shell Jobs extension to the correct VLC directories on Linux.
# Embeds the icon data into the installed shell_jobs.lua file.
#
# Usage:
#   ./setup-linux.sh               # Interactive mode (prompts for overwrites)
#   ./setup-linux.sh --force       # Force overwrite without prompting
#   ./setup-linux.sh --dev-deps    # Install development dependencies first
#

set -e

# Get the script directory (where this script is located) - POSIX compatible
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Check for --dev-deps flag
INSTALL_DEV_DEPS=false
REMAINING_ARGS=""
for arg in "$@"; do
    case "$arg" in
        --dev-deps)
            INSTALL_DEV_DEPS=true
            ;;
        *)
            REMAINING_ARGS="$REMAINING_ARGS $arg"
            ;;
    esac
done

# Install development dependencies if requested
if [ "$INSTALL_DEV_DEPS" = "true" ]; then
    echo "Installing development dependencies..."
    echo ""
    "$SCRIPT_DIR/install-dev-deps-linux.sh"
    echo ""
fi

# Extension-specific configuration
EXTENSION_NAME="shell_jobs.lua"
EXTENSION_DISPLAY_NAME="VLC Shell Jobs"
MODULE_FILES="dynamic_dialog.lua,os_detect.lua,shell_execute.lua,shell_job.lua,shell_job_defs.lua,shell_job_state.lua,shell_operator_fileio.lua,xspf_writer.lua,path_utils.lua,vlc_compat.lua"
ICON_FILE="utils/icon/shell_jobs_32x32.lua"
VLC_EXTENSIONS_SUBDIR="extensions"
VLC_MODULES_SUBDIR="modules/extensions"

# Call the core installer with the extension-specific parameters
# shellcheck disable=SC2086
"$SCRIPT_DIR/core/core-install-unix.sh" \
    --platform "linux" \
    --extension-name "$EXTENSION_NAME" \
    --extension-display-name "$EXTENSION_DISPLAY_NAME" \
    --module-files "$MODULE_FILES" \
    --icon-file "$ICON_FILE" \
    --vlc-extensions-subdir "$VLC_EXTENSIONS_SUBDIR" \
    --vlc-modules-subdir "$VLC_MODULES_SUBDIR" \
    $REMAINING_ARGS
