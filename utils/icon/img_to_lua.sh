#!/bin/bash

# Script to convert an image (jpg/png) to a 32x32 Lua file
# Usage: ./img_to_lua.sh <input_image>
# Output: Creates a <basename>_32x32.lua file in the current directory
# Requires: ImageMagick (convert) or Python3 with Pillow

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ $# -ne 1 ]; then
    echo "Usage: $0 <input_image.jpg|png>"
    exit 1
fi

INPUT_FILE="$1"

if [ ! -f "$INPUT_FILE" ]; then
    echo "Error: File '$INPUT_FILE' not found"
    exit 1
fi

# Check file extension
EXT="${INPUT_FILE##*.}"
EXT_LOWER=$(echo "$EXT" | tr '[:upper:]' '[:lower:]')

if [ "$EXT_LOWER" != "jpg" ] && [ "$EXT_LOWER" != "jpeg" ] && [ "$EXT_LOWER" != "png" ]; then
    echo "Error: Only jpg and png files are supported"
    exit 1
fi

# Get the base name without extension
BASENAME=$(basename "$INPUT_FILE")
NAME="${BASENAME%.*}"

# Create temporary 32x32 PNG
TEMP_PNG=$(mktemp --suffix=.png)
trap "rm -f \"$TEMP_PNG\"" EXIT

# Convert to 32x32 PNG using ImageMagick or Python/Pillow
if command -v convert &> /dev/null; then
    convert "$INPUT_FILE" -resize 32x32! "$TEMP_PNG"
else
    if ! command -v python3 &> /dev/null; then
        echo "Error: ImageMagick 'convert' not found and python3 is not installed."
        exit 1
    fi
    if ! python3 -c "import PIL" &> /dev/null; then
        echo "Error: Python Pillow (PIL) is not installed."
        echo "Install with: pip3 install Pillow"
        echo "Or install ImageMagick so 'convert' is available."
        exit 1
    fi

    python3 - <<PY
from PIL import Image
img = Image.open("$INPUT_FILE")
img = img.resize((32, 32), Image.LANCZOS)
img.save("$TEMP_PNG", "PNG")
PY
fi

# Generate Lua file
OUTPUT_LUA="${NAME}_32x32.lua"
python3 "$SCRIPT_DIR/png_to_lua_string.py" "$TEMP_PNG" "$OUTPUT_LUA"

echo "Created: $OUTPUT_LUA"
