#!/bin/sh
#
# VLC Extension - Core Unix Installer (POSIX-compliant)
#
# A modular installer script that can be used for any VLC extension on Unix-like systems.
# This script accepts extension-specific parameters and performs the installation.
#
# Parameters (all required):
#   --platform: Target platform (linux or macos)
#   --extension-name: Name of the main extension file (e.g., "shell_jobs.lua")
#   --extension-display-name: Human-readable name (e.g., "VLC Shell Jobs")
#   --module-files: Comma-separated list of module files to install
#   --icon-file: Path to icon data file (relative to repo root, or empty for no icon)
#   --vlc-extensions-subdir: VLC extensions subdirectory (e.g., "extensions")
#   --vlc-modules-subdir: VLC modules subdirectory (e.g., "modules/extensions")
#
# Optional flags:
#   --force, -f: Force overwrite without prompting
#
# Usage:
#   ./core-install-unix.sh \
#     --platform "linux" \
#     --extension-name "shell_jobs.lua" \
#     --extension-display-name "VLC Shell Jobs" \
#     --module-files "dynamic_dialog.lua,os_detect.lua,shell_execute.lua,shell_job.lua,shell_job_defs.lua,shell_job_state.lua,shell_operator_fileio.lua" \
#     --icon-file "utils/icon/shell_jobs_32x32.lua" \
#     --vlc-extensions-subdir "extensions" \
#     --vlc-modules-subdir "modules/extensions" \
#     --force
#

set -e

# Parse command line arguments
FORCE=false
PLATFORM=""
EXTENSION_NAME=""
EXTENSION_DISPLAY_NAME=""
MODULE_FILES=""
ICON_FILE=""
VLC_EXTENSIONS_SUBDIR=""
VLC_MODULES_SUBDIR=""

while [ $# -gt 0 ]; do
    case $1 in
        --force|-f)
            FORCE=true
            shift
            ;;
        --platform)
            PLATFORM="$2"
            shift 2
            ;;
        --extension-name)
            EXTENSION_NAME="$2"
            shift 2
            ;;
        --extension-display-name)
            EXTENSION_DISPLAY_NAME="$2"
            shift 2
            ;;
        --module-files)
            MODULE_FILES="$2"
            shift 2
            ;;
        --icon-file)
            ICON_FILE="$2"
            shift 2
            ;;
        --vlc-extensions-subdir)
            VLC_EXTENSIONS_SUBDIR="$2"
            shift 2
            ;;
        --vlc-modules-subdir)
            VLC_MODULES_SUBDIR="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Validate required parameters
if [ -z "$PLATFORM" ]; then
    echo "Error: --platform is required (linux or macos)"
    exit 1
fi
if [ "$PLATFORM" != "linux" ] && [ "$PLATFORM" != "macos" ]; then
    echo "Error: --platform must be 'linux' or 'macos'"
    exit 1
fi
if [ -z "$EXTENSION_NAME" ]; then
    echo "Error: --extension-name is required"
    exit 1
fi
if [ -z "$EXTENSION_DISPLAY_NAME" ]; then
    echo "Error: --extension-display-name is required"
    exit 1
fi
if [ -z "$VLC_EXTENSIONS_SUBDIR" ]; then
    echo "Error: --vlc-extensions-subdir is required"
    exit 1
fi
if [ -z "$VLC_MODULES_SUBDIR" ]; then
    echo "Error: --vlc-modules-subdir is required"
    exit 1
fi

# Get the script directory (where this script is located) - POSIX compatible
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"

# Set VLC base directory based on platform
if [ "$PLATFORM" = "linux" ]; then
    VLC_BASE_DIR="$HOME/.local/share/vlc/lua"
    PLATFORM_DISPLAY="Linux"
elif [ "$PLATFORM" = "macos" ]; then
    VLC_BASE_DIR="$HOME/Library/Application Support/org.videolan.vlc/lua"
    PLATFORM_DISPLAY="macOS"
fi

EXTENSIONS_DIR="$VLC_BASE_DIR/$VLC_EXTENSIONS_SUBDIR"
MODULES_DIR="$VLC_BASE_DIR/$VLC_MODULES_SUBDIR"

# Source directories
SRC_EXTENSIONS_DIR="$REPO_DIR/lua/extensions"
SRC_MODULES_DIR="$REPO_DIR/lua/modules/extensions"

# Icon file path (if provided)
if [ -n "$ICON_FILE" ]; then
    ICON_DATA_FILE="$REPO_DIR/$ICON_FILE"
else
    ICON_DATA_FILE=""
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# POSIX-compatible printf with color support
print_color() {
    color="$1"
    shift
    printf "%b%s%b\n" "$color" "$*" "$NC"
}

print_color "$CYAN" "============================================================================"
print_color "$CYAN" "$EXTENSION_DISPLAY_NAME - $PLATFORM_DISPLAY Installer"
print_color "$CYAN" "============================================================================"
echo ""
echo "Source repository: $REPO_DIR"
echo "VLC base directory: $VLC_BASE_DIR"
echo ""

# Compute hash for a file - tries multiple hash commands (POSIX compatible)
compute_hash_file() {
    file="$1"
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$file" | awk '{print $1}'
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$file" | awk '{print $1}'
    elif command -v openssl >/dev/null 2>&1; then
        openssl dgst -sha256 "$file" | awk '{print $2}'
    elif command -v md5sum >/dev/null 2>&1; then
        md5sum "$file" | awk '{print $1}'
    elif command -v md5 >/dev/null 2>&1; then
        md5 -q "$file"
    else
        # Fallback to file comparison if no hash tool available
        echo ""
    fi
}

# Compute hash for content - tries multiple hash commands (POSIX compatible)
compute_hash_content() {
    content="$1"
    if command -v sha256sum >/dev/null 2>&1; then
        printf '%s' "$content" | sha256sum | awk '{print $1}'
    elif command -v shasum >/dev/null 2>&1; then
        printf '%s' "$content" | shasum -a 256 | awk '{print $1}'
    elif command -v openssl >/dev/null 2>&1; then
        printf '%s' "$content" | openssl dgst -sha256 | awk '{print $2}'
    elif command -v md5sum >/dev/null 2>&1; then
        printf '%s' "$content" | md5sum | awk '{print $1}'
    elif command -v md5 >/dev/null 2>&1; then
        printf '%s' "$content" | md5
    else
        # Fallback to empty hash if no hash tool available
        echo ""
    fi
}

# Check if two files are identical
files_identical() {
    a="$1"
    b="$2"
    
    src_hash=$(compute_hash_file "$a")
    dest_hash=$(compute_hash_file "$b")
    
    # If hash is available and matches
    if [ -n "$src_hash" ] && [ "$src_hash" = "$dest_hash" ]; then
        return 0
    fi
    
    # Fallback to cmp if hashing not available
    if [ -z "$src_hash" ]; then
        if cmp -s "$a" "$b"; then
            return 0
        fi
    fi
    
    return 1
}

# Copy file with optional overwrite confirmation (skip if identical)
copy_file_with_prompt() {
    source="$1"
    dest="$2"
    filename=$(basename "$source")

    if [ -f "$dest" ]; then
        if files_identical "$source" "$dest"; then
            print_color "$GREEN" "  Up-to-date, skipping: $filename"
            return 0
        fi

        if [ "$FORCE" = "false" ]; then
            printf "File '%s' already exists at destination. Overwrite? (y/N) " "$filename"
            read -r response
            if [ "$response" != "y" ] && [ "$response" != "Y" ]; then
                print_color "$YELLOW" "  Skipping: $filename"
                return 1
            fi
        fi
    fi

    cp "$source" "$dest"
    print_color "$GREEN" "  Copied: $filename"
    return 0
}

# Install extension with embedded icon
install_extension_with_icon() {
    source="$1"
    dest="$2"
    icon_file="$3"
    filename=$(basename "$source")

    # Read the extension file content
    ext_content=$(cat "$source")

    # Check if icon file exists and embed if present
    if [ -n "$icon_file" ] && [ -f "$icon_file" ]; then
        icon_content=$(cat "$icon_file")

        # Add icon reference to descriptor using printf for portable newline handling
        # Replace "capabilities = {}," with "capabilities = {},\n        icon = png_data,"
        ext_content=$(printf '%s' "$ext_content" | sed 's/capabilities = {},/capabilities = {},\
        icon = png_data,/')

        # Append icon data at the end
        ext_content="${ext_content}

-- Icon data (embedded during installation)
${icon_content}"

        print_color "$GREEN" "  Embedding icon data..."
    else
        if [ -n "$icon_file" ]; then
            print_color "$YELLOW" "  WARNING: Icon data file not found, installing without icon"
        fi
    fi

    # Write generated content to a temp file for comparison/atomic install
    tmp=$(mktemp) || { print_color "$RED" "  ERROR: could not create temp file"; return 1; }
    printf '%s' "$ext_content" > "$tmp"

    if [ -f "$dest" ]; then
        if files_identical "$tmp" "$dest"; then
            print_color "$GREEN" "  Up-to-date, skipping: $filename"
            rm -f "$tmp"
            return 0
        fi

        if [ "$FORCE" = "false" ]; then
            printf "File '%s' already exists at destination. Overwrite? (y/N) " "$filename"
            read -r response
            if [ "$response" != "y" ] && [ "$response" != "Y" ]; then
                print_color "$YELLOW" "  Skipping: $filename"
                rm -f "$tmp"
                return 1
            fi
        fi
    fi

    mv "$tmp" "$dest"
    print_color "$GREEN" "  Installed: $filename"
    return 0
}

# Create directories if they don't exist
echo "Creating VLC directories..."
mkdir -p "$EXTENSIONS_DIR"
if [ -n "$MODULE_FILES" ]; then
    mkdir -p "$MODULES_DIR"
fi

# Install main extension file with icon (if applicable)
echo ""
echo "Installing extension file..."
EXTENSION_FILE="$SRC_EXTENSIONS_DIR/$EXTENSION_NAME"
if [ -f "$EXTENSION_FILE" ]; then
    DEST_FILE="$EXTENSIONS_DIR/$EXTENSION_NAME"
    install_extension_with_icon "$EXTENSION_FILE" "$DEST_FILE" "$ICON_DATA_FILE"
else
    print_color "$RED" "  ERROR: Extension file not found: $EXTENSION_FILE"
    exit 1
fi

# Copy module files if provided
if [ -n "$MODULE_FILES" ]; then
    echo ""
    echo "Installing module files..."
    
    # POSIX-compatible way to iterate over comma-separated list
    # Save IFS and set to comma
    OLD_IFS="$IFS"
    IFS=','
    
    for file in $MODULE_FILES; do
        # Trim whitespace (POSIX compatible)
        file=$(echo "$file" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        SOURCE_FILE="$SRC_MODULES_DIR/$file"
        if [ -f "$SOURCE_FILE" ]; then
            DEST_FILE="$MODULES_DIR/$file"
            copy_file_with_prompt "$SOURCE_FILE" "$DEST_FILE"
        else
            print_color "$YELLOW" "  WARNING: Module file not found: $file"
        fi
    done
    
    # Restore IFS
    IFS="$OLD_IFS"
fi

echo ""
print_color "$CYAN" "============================================================================"
print_color "$GREEN" "Installation Complete!"
print_color "$CYAN" "============================================================================"
echo ""
echo "Files installed to:"
echo "  Extensions: $EXTENSIONS_DIR"
if [ -n "$MODULE_FILES" ]; then
    echo "  Modules:    $MODULES_DIR"
fi
echo ""
echo "Next steps:"
echo "  1. Restart VLC"
echo "  2. Go to View menu -> $EXTENSION_DISPLAY_NAME"
echo ""
