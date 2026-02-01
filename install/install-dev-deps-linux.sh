#!/bin/sh
#
# VLC Shell Jobs - Linux Development Dependencies Installer
#
# Installs all packages needed for development, testing, and icon creation on Linux.
# Automatically detects the Linux distribution and uses the appropriate package manager.
#
# Required packages:
#   - lua (or lua5.3/lua5.4): For running Lua unit tests
#   - python3: For icon generation scripts
#   - python3-pip: For installing Python packages
#   - imagemagick: For image conversion (optional, Pillow is fallback)
#   - python3-pillow (or via pip): For image manipulation
#
# Usage:
#   ./install-dev-deps-linux.sh          # Install dev dependencies
#   ./install-dev-deps-linux.sh --check  # Only check what's missing, don't install
#

set -e

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

# Parse arguments
CHECK_ONLY=false
while [ $# -gt 0 ]; do
    case $1 in
        --check)
            CHECK_ONLY=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [--check]"
            echo ""
            echo "Options:"
            echo "  --check    Only check what's missing, don't install"
            echo "  --help     Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

print_color "$CYAN" "============================================================================"
print_color "$CYAN" "VLC Shell Jobs - Linux Development Dependencies"
print_color "$CYAN" "============================================================================"
echo ""

# Detect Linux distribution
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO_ID="$ID"
        DISTRO_ID_LIKE="$ID_LIKE"
        DISTRO_NAME="$NAME"
    elif [ -f /etc/lsb-release ]; then
        . /etc/lsb-release
        DISTRO_ID="$DISTRIB_ID"
        DISTRO_NAME="$DISTRIB_DESCRIPTION"
        DISTRO_ID_LIKE=""
    elif [ -f /etc/debian_version ]; then
        DISTRO_ID="debian"
        DISTRO_NAME="Debian"
        DISTRO_ID_LIKE=""
    elif [ -f /etc/redhat-release ]; then
        DISTRO_ID="rhel"
        DISTRO_NAME=$(cat /etc/redhat-release)
        DISTRO_ID_LIKE=""
    else
        DISTRO_ID="unknown"
        DISTRO_NAME="Unknown"
        DISTRO_ID_LIKE=""
    fi
    
    # Normalize to lowercase
    DISTRO_ID=$(echo "$DISTRO_ID" | tr '[:upper:]' '[:lower:]')
    DISTRO_ID_LIKE=$(echo "$DISTRO_ID_LIKE" | tr '[:upper:]' '[:lower:]')
}

# Determine package manager based on distribution
detect_package_manager() {
    case "$DISTRO_ID" in
        ubuntu|debian|linuxmint|pop|elementary|zorin|kali|raspbian)
            PKG_MANAGER="apt"
            PKG_INSTALL="apt-get install -y"
            PKG_UPDATE="apt-get update"
            ;;
        fedora)
            PKG_MANAGER="dnf"
            PKG_INSTALL="dnf install -y"
            PKG_UPDATE="dnf check-update || true"
            ;;
        rhel|centos|rocky|almalinux|ol)
            # Check if dnf is available (RHEL 8+), otherwise use yum
            if command -v dnf >/dev/null 2>&1; then
                PKG_MANAGER="dnf"
                PKG_INSTALL="dnf install -y"
                PKG_UPDATE="dnf check-update || true"
            else
                PKG_MANAGER="yum"
                PKG_INSTALL="yum install -y"
                PKG_UPDATE="yum check-update || true"
            fi
            ;;
        arch|manjaro|endeavouros|garuda)
            PKG_MANAGER="pacman"
            PKG_INSTALL="pacman -S --noconfirm"
            PKG_UPDATE="pacman -Sy"
            ;;
        opensuse*|suse|sles)
            PKG_MANAGER="zypper"
            PKG_INSTALL="zypper install -y"
            PKG_UPDATE="zypper refresh"
            ;;
        alpine)
            PKG_MANAGER="apk"
            PKG_INSTALL="apk add"
            PKG_UPDATE="apk update"
            ;;
        gentoo)
            PKG_MANAGER="emerge"
            PKG_INSTALL="emerge"
            PKG_UPDATE="emerge --sync"
            ;;
        void)
            PKG_MANAGER="xbps"
            PKG_INSTALL="xbps-install -y"
            PKG_UPDATE="xbps-install -S"
            ;;
        *)
            # Try to detect from ID_LIKE
            case "$DISTRO_ID_LIKE" in
                *debian*|*ubuntu*)
                    PKG_MANAGER="apt"
                    PKG_INSTALL="apt-get install -y"
                    PKG_UPDATE="apt-get update"
                    ;;
                *rhel*|*fedora*|*centos*)
                    if command -v dnf >/dev/null 2>&1; then
                        PKG_MANAGER="dnf"
                        PKG_INSTALL="dnf install -y"
                        PKG_UPDATE="dnf check-update || true"
                    else
                        PKG_MANAGER="yum"
                        PKG_INSTALL="yum install -y"
                        PKG_UPDATE="yum check-update || true"
                    fi
                    ;;
                *arch*)
                    PKG_MANAGER="pacman"
                    PKG_INSTALL="pacman -S --noconfirm"
                    PKG_UPDATE="pacman -Sy"
                    ;;
                *suse*)
                    PKG_MANAGER="zypper"
                    PKG_INSTALL="zypper install -y"
                    PKG_UPDATE="zypper refresh"
                    ;;
                *)
                    PKG_MANAGER="unknown"
                    ;;
            esac
            ;;
    esac
}

# Get package names for each package manager
get_package_names() {
    case "$PKG_MANAGER" in
        apt)
            PKG_LUA="lua5.3"
            PKG_PYTHON="python3"
            PKG_PIP="python3-pip"
            PKG_IMAGEMAGICK="imagemagick"
            PKG_PILLOW="python3-pil"
            ;;
        dnf|yum)
            PKG_LUA="lua"
            PKG_PYTHON="python3"
            PKG_PIP="python3-pip"
            PKG_IMAGEMAGICK="ImageMagick"
            PKG_PILLOW="python3-pillow"
            ;;
        pacman)
            PKG_LUA="lua"
            PKG_PYTHON="python"
            PKG_PIP="python-pip"
            PKG_IMAGEMAGICK="imagemagick"
            PKG_PILLOW="python-pillow"
            ;;
        zypper)
            PKG_LUA="lua54"
            PKG_PYTHON="python3"
            PKG_PIP="python3-pip"
            PKG_IMAGEMAGICK="ImageMagick"
            PKG_PILLOW="python3-Pillow"
            ;;
        apk)
            PKG_LUA="lua5.3"
            PKG_PYTHON="python3"
            PKG_PIP="py3-pip"
            PKG_IMAGEMAGICK="imagemagick"
            PKG_PILLOW="py3-pillow"
            ;;
        emerge)
            PKG_LUA="dev-lang/lua"
            PKG_PYTHON="dev-lang/python"
            PKG_PIP=""  # Comes with python on Gentoo
            PKG_IMAGEMAGICK="media-gfx/imagemagick"
            PKG_PILLOW="dev-python/pillow"
            ;;
        xbps)
            PKG_LUA="lua"
            PKG_PYTHON="python3"
            PKG_PIP="python3-pip"
            PKG_IMAGEMAGICK="ImageMagick"
            PKG_PILLOW="python3-Pillow"
            ;;
        *)
            PKG_LUA=""
            PKG_PYTHON=""
            PKG_PIP=""
            PKG_IMAGEMAGICK=""
            PKG_PILLOW=""
            ;;
    esac
}

# Check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if Python module is installed
python_module_exists() {
    python3 -c "import $1" >/dev/null 2>&1
}

# Check what's installed
check_dependencies() {
    MISSING=""
    INSTALLED=""
    
    echo "Checking installed dependencies..."
    echo ""
    
    # Check Lua
    if command_exists lua || command_exists lua5.3 || command_exists lua5.4; then
        LUA_VERSION=$(lua -v 2>&1 | head -1 || lua5.3 -v 2>&1 | head -1 || lua5.4 -v 2>&1 | head -1)
        print_color "$GREEN" "  ✓ Lua: $LUA_VERSION"
        INSTALLED="$INSTALLED lua"
    else
        print_color "$RED" "  ✗ Lua: NOT INSTALLED"
        MISSING="$MISSING $PKG_LUA"
    fi
    
    # Check Python3
    if command_exists python3; then
        PYTHON_VERSION=$(python3 --version 2>&1)
        print_color "$GREEN" "  ✓ Python: $PYTHON_VERSION"
        INSTALLED="$INSTALLED python3"
    else
        print_color "$RED" "  ✗ Python3: NOT INSTALLED"
        MISSING="$MISSING $PKG_PYTHON"
    fi
    
    # Check pip
    if command_exists pip3 || command_exists pip; then
        PIP_VERSION=$(pip3 --version 2>&1 || pip --version 2>&1)
        print_color "$GREEN" "  ✓ pip: $PIP_VERSION"
        INSTALLED="$INSTALLED pip"
    else
        print_color "$YELLOW" "  ? pip: NOT INSTALLED (optional)"
        # Only add to missing if we need to install Pillow via pip
        if ! python_module_exists PIL 2>/dev/null; then
            MISSING="$MISSING $PKG_PIP"
        fi
    fi
    
    # Check ImageMagick (convert command)
    if command_exists convert; then
        IM_VERSION=$(convert --version 2>&1 | head -1)
        print_color "$GREEN" "  ✓ ImageMagick: $IM_VERSION"
        INSTALLED="$INSTALLED imagemagick"
    else
        print_color "$YELLOW" "  ? ImageMagick: NOT INSTALLED (optional, Pillow is fallback)"
        MISSING="$MISSING $PKG_IMAGEMAGICK"
    fi
    
    # Check Pillow (Python PIL)
    if command_exists python3 && python_module_exists PIL; then
        PIL_VERSION=$(python3 -c "import PIL; print(PIL.__version__)" 2>/dev/null || echo "installed")
        print_color "$GREEN" "  ✓ Pillow: $PIL_VERSION"
        INSTALLED="$INSTALLED pillow"
    else
        print_color "$RED" "  ✗ Pillow (PIL): NOT INSTALLED"
        MISSING="$MISSING $PKG_PILLOW"
    fi
    
    echo ""
}

# Install missing packages
install_packages() {
    if [ -z "$MISSING" ] || [ "$MISSING" = " " ]; then
        print_color "$GREEN" "All dependencies are already installed!"
        return 0
    fi
    
    # Trim whitespace
    MISSING=$(echo "$MISSING" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    
    if [ "$CHECK_ONLY" = "true" ]; then
        echo "Missing packages:"
        echo "  $MISSING"
        echo ""
        echo "Run without --check to install these packages."
        return 0
    fi
    
    print_color "$YELLOW" "Installing missing packages: $MISSING"
    echo ""
    
    # Check if running as root
    if [ "$(id -u)" -ne 0 ]; then
        if command_exists sudo; then
            SUDO="sudo"
            print_color "$YELLOW" "Running with sudo..."
        else
            print_color "$RED" "Error: This script needs root privileges to install packages."
            print_color "$RED" "Please run as root or install sudo."
            exit 1
        fi
    else
        SUDO=""
    fi
    
    # Update package lists
    print_color "$CYAN" "Updating package lists..."
    $SUDO sh -c "$PKG_UPDATE" || true
    
    # Install packages
    print_color "$CYAN" "Installing packages..."
    # shellcheck disable=SC2086
    $SUDO sh -c "$PKG_INSTALL $MISSING"
    
    # If Pillow wasn't available as a system package, try pip
    if ! python_module_exists PIL 2>/dev/null; then
        print_color "$YELLOW" "Installing Pillow via pip..."
        if command_exists pip3; then
            pip3 install --user Pillow || $SUDO pip3 install Pillow
        elif command_exists pip; then
            pip install --user Pillow || $SUDO pip install Pillow
        fi
    fi
    
    echo ""
    print_color "$GREEN" "Installation complete!"
}

# Main execution
detect_distro
echo "Detected distribution: $DISTRO_NAME ($DISTRO_ID)"

detect_package_manager
if [ "$PKG_MANAGER" = "unknown" ]; then
    print_color "$RED" "Error: Could not detect package manager for this distribution."
    print_color "$YELLOW" "Please install the following packages manually:"
    echo "  - lua (or lua5.3/lua5.4)"
    echo "  - python3"
    echo "  - python3-pip"
    echo "  - imagemagick (optional)"
    echo "  - python3-pillow (or: pip3 install Pillow)"
    exit 1
fi

echo "Package manager: $PKG_MANAGER"
echo ""

get_package_names
check_dependencies
install_packages

echo ""
print_color "$CYAN" "============================================================================"
print_color "$GREEN" "Development dependencies setup complete!"
print_color "$CYAN" "============================================================================"
echo ""
echo "You can now:"
echo "  - Run Lua tests:     ./lua/modules/extensions/tests/run_lua_tests.sh"
echo "  - Generate icons:    ./utils/icon/img_to_lua.sh <image.png>"
echo ""
