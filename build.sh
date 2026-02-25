#!/bin/bash
# =============================================================================
# Dungeon Visualizer Build Script
# =============================================================================
# Finds Odin compiler and runs the project
# Configure ODIN_PATH environment variable to override default locations
#
# Usage:
#   ./build.sh              # Build and run
#   ./build.sh -debug       # Debug build
#   ./build.sh -check       # Check syntax only
#   ODIN_PATH=/custom/path ./build.sh
# =============================================================================

# Default Odin paths to check (in order of preference)
DEFAULT_PATHS=(
    "$ODIN_PATH"                      # User override via env var
    "$HOME/tools/Odin"                # Common location
    "$HOME/.local/odin"               # Alternative
    "/opt/odin"                       # System location
    "/usr/local/odin"                 # Another system location
    "$(which odin 2>/dev/null)"       # Check PATH
)

# Find Odin compiler
ODIN_BIN=""
for path in "${DEFAULT_PATHS[@]}"; do
    if [ -z "$path" ]; then
        continue
    fi

    # Check if it's a directory and has odin binary
    if [ -d "$path" ]; then
        if [ -f "$path/odin" ]; then
            ODIN_BIN="$path/odin"
            break
        fi
    # Check if it's a direct path to odin binary
    elif [ -f "$path" ] && [ -x "$path" ]; then
        ODIN_BIN="$path"
        break
    fi
done

# If still not found, try system PATH
if [ -z "$ODIN_BIN" ]; then
    ODIN_BIN=$(command -v odin)
fi

# Error if not found
if [ -z "$ODIN_BIN" ]; then
    echo "Error: Odin compiler not found!"
    echo ""
    echo "Please install Odin or set ODIN_PATH environment variable:"
    echo "  export ODIN_PATH=~/tools/Odin"
    echo "  ./build.sh"
    echo ""
    echo "Checked locations:"
    for path in "${DEFAULT_PATHS[@]}"; do
        [ -n "$path" ] && echo "  - $path"
    done
    exit 1
fi

echo "Found Odin: $ODIN_BIN"
echo ""

# Parse arguments
BUILD_MODE="run"
DEBUG_FLAG=""

for arg in "$@"; do
    case "$arg" in
        -debug)
            DEBUG_FLAG="-debug"
            ;;
        -check)
            BUILD_MODE="check"
            ;;
        -run)
            BUILD_MODE="run"
            ;;
        -build)
            BUILD_MODE="build"
            ;;
        *)
            echo "Unknown argument: $arg"
            echo "Usage: ./build.sh [-debug] [-check] [-run] [-build]"
            exit 1
            ;;
    esac
done

# Run build
case "$BUILD_MODE" in
    run)
        echo "Running: $ODIN_BIN run src/ $DEBUG_FLAG"
        $ODIN_BIN run src/ $DEBUG_FLAG
        ;;
    check)
        echo "Checking: $ODIN_BIN check src/"
        $ODIN_BIN check src/
        ;;
    build)
        echo "Building: $ODIN_BIN build src/ $DEBUG_FLAG"
        $ODIN_BIN build src/ $DEBUG_FLAG
        ;;
esac
