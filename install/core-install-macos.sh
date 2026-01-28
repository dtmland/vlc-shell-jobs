#!/usr/bin/env bash
#
# VLC Extension - Core macOS Installer
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
#   ./core-install-macos.sh \
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

# VLC directories on macOS
VLC_BASE_DIR="$HOME/Library/Application Support/org.videolan.vlc/lua"
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
echo -e "${CYAN}$EXTENSION_DISPLAY_NAME - macOS Installer${NC}"
echo -e "${CYAN}============================================================================${NC}"
echo ""
echo "Source repository: $REPO_DIR"
echo "VLC base directory: $VLC_BASE_DIR"
echo ""

# Hash helpers: compute SHA-256 for a file or for text content (uses shasum/sha256sum/openssl)
compute_hash_file() {
    local file="$1"
    if command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$file" | awk '{print $1}'
    elif command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$file" | awk '{print $1}'
    elif command -v openssl >/dev/null 2>&1; then
        openssl dgst -sha256 "$file" | awk '{print $2}'
    else
        # Fallback to a simple checksum (less ideal) if none available
        md5 -q "$file"
    fi
}

compute_hash_content() {
    local content="$1"
    if command -v shasum >/dev/null 2>&1; then
        printf '%s' "$content" | shasum -a 256 | awk '{print $1}'
    elif command -v sha256sum >/dev/null 2>&1; then
        printf '%s' "$content" | sha256sum | awk '{print $1}'
    elif command -v openssl >/dev/null 2>&1; then
        printf '%s' "$content" | openssl dgst -sha256 | awk '{print $2}'
    else
        printf '%s' "$content" | md5
    fi
}

# Function to copy file with optional overwrite confirmation and hash comparison
copy_file_with_prompt() {
    local source="$1"
    local dest="$2"
    local filename=$(basename "$source")
    
    if [ -f "$dest" ]; then
        # If files are identical by hash, skip silently (or inform)
        local src_hash
        local dest_hash
        src_hash=$(compute_hash_file "$source")
        dest_hash=$(compute_hash_file "$dest")
        if [ "$src_hash" = "$dest_hash" ]; then
            echo -e "  ${YELLOW}Skipping identical file: $filename${NC}"
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

# Function to install extension with embedded icon
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

    # If destination exists, compare hashes of the final content vs destination
    if [ -f "$dest" ]; then
        local new_hash
        local dest_hash
        new_hash=$(compute_hash_content "$ext_content")
        dest_hash=$(compute_hash_file "$dest")
        if [ "$new_hash" = "$dest_hash" ]; then
            echo -e "  ${YELLOW}Skipping identical extension (embedded) : $filename${NC}"
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
    
    # Write the combined content to destination
    printf '%s' "$ext_content" > "$dest"
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
