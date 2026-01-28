#!/usr/bin/env bash
#
# VLC Extension - Core Linux Installer
#
# A modular installer script that can be used for any VLC extension.
# This script accepts extension-specific parameters and performs the installation.
#
# Parameters (all required):
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
#   ./core-install-linux.sh \
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
EXTENSION_NAME=""
EXTENSION_DISPLAY_NAME=""
MODULE_FILES=""
ICON_FILE=""
VLC_EXTENSIONS_SUBDIR=""
VLC_MODULES_SUBDIR=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --force|-f)
            FORCE=true
            shift
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

# Get the script directory (where this script is located)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

# VLC directories on Linux
VLC_BASE_DIR="$HOME/.local/share/vlc/lua"
EXTENSIONS_DIR="$VLC_BASE_DIR/$VLC_EXTENSIONS_SUBDIR"
MODULES_DIR="$VLC_BASE_DIR/$VLC_MODULES_SUBDIR"

# Source directories
EXTENSION_BASE_NAME="${EXTENSION_NAME%.lua}"
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

echo -e "${CYAN}============================================================================${NC}"
echo -e "${CYAN}$EXTENSION_DISPLAY_NAME - Linux Installer${NC}"
echo -e "${CYAN}============================================================================${NC}"
echo ""
echo "Source repository: $REPO_DIR"
echo "VLC base directory: $VLC_BASE_DIR"
echo ""

# Helper: compare two files using checksum if available, otherwise fall back to cmp
files_identical() {
    local a="$1" b="$2"
    if command -v sha256sum >/dev/null 2>&1; then
        [ "$(sha256sum "$a" | awk '{print $1}')" = "$(sha256sum "$b" | awk '{print $1}')" ]
        return
    elif command -v shasum >/dev/null 2>&1; then
        [ "$(shasum -a 256 "$a" | awk '{print $1}')" = "$(shasum -a 256 "$b" | awk '{print $1}')" ]
        return
    elif command -v md5sum >/dev/null 2>&1; then
        [ "$(md5sum "$a" | awk '{print $1}')" = "$(md5sum "$b" | awk '{print $1}')" ]
        return
    else
        cmp -s "$a" "$b"
        return
    fi
}

# Replace copy_file_with_prompt: skip if identical, otherwise prompt (unless FORCE)
copy_file_with_prompt() {
    local source="$1"
    local dest="$2"
    local filename=$(basename "$source")

    if [ -f "$dest" ]; then
        if files_identical "$source" "$dest"; then
            echo -e "  ${GREEN}Up-to-date, skipping: $filename${NC}"
            return 0
        fi

        if [ "$FORCE" = false ]; then
            read -p "File '$filename' already exists at destination. Overwrite? (y/N) " response
            if [ "$response" != "y" ] && [ "$response" != "Y" ]; then
                echo -e "  ${YELLOW}Skipping: $filename${NC}"
                return 1
            fi
        fi
    fi

    cp "$source" "$dest"
    echo -e "  ${GREEN}Copied: $filename${NC}"
    return 0
}

# Replace install_extension_with_icon: build final content in a temp file, compare, then write/move
install_extension_with_icon() {
    local source="$1"
    local dest="$2"
    local icon_file="$3"
    local filename=$(basename "$source")

    # Read the extension file content
    local ext_content
    ext_content=$(cat "$source")

    # Check if icon file exists and embed if present
    if [ -n "$icon_file" ] && [ -f "$icon_file" ]; then
        local icon_content
        icon_content=$(cat "$icon_file")

        # Add icon reference to descriptor using printf for portable newline handling
        # Replace "capabilities = {}," with "capabilities = {},\n        icon = png_data,"
        ext_content=$(printf '%s' "$ext_content" | sed 's/capabilities = {},/capabilities = {},\'$'\n''        icon = png_data,/')

        # Append icon data at the end
        ext_content="${ext_content}

-- Icon data (embedded during installation)
${icon_content}"

        echo -e "  ${GREEN}Embedding icon data...${NC}"
    else
        if [ -n "$icon_file" ]; then
            echo -e "  ${YELLOW}WARNING: Icon data file not found, installing without icon${NC}"
        fi
    fi

    # Write generated content to a temp file for comparison/atomic install
    local tmp
    tmp=$(mktemp) || { echo -e "  ${RED}ERROR: could not create temp file${NC}"; return 1; }
    printf '%s' "$ext_content" > "$tmp"

    if [ -f "$dest" ]; then
        if files_identical "$tmp" "$dest"; then
            echo -e "  ${GREEN}Up-to-date, skipping: $filename${NC}"
            rm -f "$tmp"
            return 0
        fi

        if [ "$FORCE" = false ]; then
            read -p "File '$filename' already exists at destination. Overwrite? (y/N) " response
            if [ "$response" != "y" ] && [ "$response" != "Y" ]; then
                echo -e "  ${YELLOW}Skipping: $filename${NC}"
                rm -f "$tmp"
                return 1
            fi
        fi
    fi

    mv "$tmp" "$dest"
    echo -e "  ${GREEN}Installed: $filename${NC}"
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
    echo -e "  ${RED}ERROR: Extension file not found: $EXTENSION_FILE${NC}"
    exit 1
fi

# Copy module files if provided
if [ -n "$MODULE_FILES" ]; then
    echo ""
    echo "Installing module files..."
    
    # Convert comma-separated list to array
    IFS=',' read -ra MODULE_ARRAY <<< "$MODULE_FILES"
    
    for file in "${MODULE_ARRAY[@]}"; do
        # Trim whitespace
        file=$(echo "$file" | xargs)
        SOURCE_FILE="$SRC_MODULES_DIR/$file"
        if [ -f "$SOURCE_FILE" ]; then
            DEST_FILE="$MODULES_DIR/$file"
            copy_file_with_prompt "$SOURCE_FILE" "$DEST_FILE"
        else
            echo -e "  ${YELLOW}WARNING: Module file not found: $file${NC}"
        fi
    done
fi

echo ""
echo -e "${CYAN}============================================================================${NC}"
echo -e "${GREEN}Installation Complete!${NC}"
echo -e "${CYAN}============================================================================${NC}"
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
