#!/usr/bin/env bash
#
# VLC Shell Jobs - Linux Installer
#
# Installs the VLC Shell Jobs extension to the correct VLC directories on Linux.
#
# Usage:
#   ./install-linux.sh          # Interactive mode (prompts for overwrites)
#   ./install-linux.sh --force  # Force overwrite without prompting
#

set -e

FORCE=false
if [ "$1" = "--force" ] || [ "$1" = "-f" ]; then
    FORCE=true
fi

# Get the script directory (where this script is located)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

# VLC directories on Linux
VLC_BASE_DIR="$HOME/.local/share/vlc/lua"
EXTENSIONS_DIR="$VLC_BASE_DIR/extensions"
MODULES_DIR="$VLC_BASE_DIR/modules/extensions"

# Source directories
SRC_EXTENSIONS_DIR="$REPO_DIR/lua/extensions"
SRC_MODULES_DIR="$REPO_DIR/lua/modules/extensions"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}============================================================================${NC}"
echo -e "${CYAN}VLC Shell Jobs - Linux Installer${NC}"
echo -e "${CYAN}============================================================================${NC}"
echo ""
echo "Source repository: $REPO_DIR"
echo "VLC base directory: $VLC_BASE_DIR"
echo ""

# Function to copy file with optional overwrite confirmation
copy_file_with_prompt() {
    local source="$1"
    local dest="$2"
    local filename=$(basename "$source")
    
    if [ -f "$dest" ] && [ "$FORCE" = false ]; then
        read -p "File '$filename' already exists at destination. Overwrite? (y/N) " response
        if [ "$response" != "y" ] && [ "$response" != "Y" ]; then
            echo -e "  ${YELLOW}Skipping: $filename${NC}"
            return 1
        fi
    fi
    
    cp "$source" "$dest"
    echo -e "  ${GREEN}Copied: $filename${NC}"
    return 0
}

# Create directories if they don't exist
echo "Creating VLC directories..."
mkdir -p "$EXTENSIONS_DIR"
mkdir -p "$MODULES_DIR"

# Copy main extension file
echo ""
echo "Installing extension file..."
EXTENSION_FILE="$SRC_EXTENSIONS_DIR/shell_jobs.lua"
if [ -f "$EXTENSION_FILE" ]; then
    DEST_FILE="$EXTENSIONS_DIR/shell_jobs.lua"
    copy_file_with_prompt "$EXTENSION_FILE" "$DEST_FILE"
else
    echo -e "  ${RED}ERROR: Extension file not found: $EXTENSION_FILE${NC}"
    exit 1
fi

# Copy module files (exclude tests directory)
echo ""
echo "Installing module files..."
MODULE_FILES=(
    "dynamic_dialog.lua"
    "shell_execute.lua"
    "shell_job.lua"
    "shell_job_defs.lua"
    "shell_job_state.lua"
    "shell_operator_fileio.lua"
)

for file in "${MODULE_FILES[@]}"; do
    SOURCE_FILE="$SRC_MODULES_DIR/$file"
    if [ -f "$SOURCE_FILE" ]; then
        DEST_FILE="$MODULES_DIR/$file"
        copy_file_with_prompt "$SOURCE_FILE" "$DEST_FILE"
    else
        echo -e "  ${YELLOW}WARNING: Module file not found: $file${NC}"
    fi
done

echo ""
echo -e "${CYAN}============================================================================${NC}"
echo -e "${GREEN}Installation Complete!${NC}"
echo -e "${CYAN}============================================================================${NC}"
echo ""
echo "Files installed to:"
echo "  Extensions: $EXTENSIONS_DIR"
echo "  Modules:    $MODULES_DIR"
echo ""
echo "Next steps:"
echo "  1. Restart VLC"
echo "  2. Go to View menu -> Shell Jobs"
echo ""
