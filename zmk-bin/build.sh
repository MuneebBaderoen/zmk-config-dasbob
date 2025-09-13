#!/usr/bin/env bash

set -exuo pipefail

# Default values from environment variables if set
BOARD="${DEFAULT_BOARD:-}"
SHIELD="${DEFAULT_SHIELD:-}"
SNIPPET=""
BUILD_DIR=""          # will be set dynamically
CONFIG_DIR="/zmk-config"
PRISTINE=0
DEBUG=0
OUT_DIR="/zmk-out"

usage() {
  cat <<EOF
Usage: $0 [options]

Options:
  --board <name>         Board name (default: \$DEFAULT_BOARD)
  --shield <name>        Shield name (default: \$DEFAULT_SHIELD)
  --snippet <name>       ZMK snippet to apply (default: none)
  --pristine             Perform a pristine build (delete previous build dir)
  --debug                Enable west debug logging
  -h, --help             Show this help message
EOF
}

# Parse flags
while [[ $# -gt 0 ]]; do
  case "$1" in
    --board) BOARD="$2"; shift 2 ;;
    --shield) SHIELD="$2"; shift 2 ;;
    --snippet) SNIPPET="$2"; shift 2 ;;
    --pristine) PRISTINE=1; shift ;;
    --debug) DEBUG=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *)
      echo "Unknown option: $1"; usage; exit 1 ;;
  esac
done

# --- Validation ---
if [[ -z "$BOARD" ]]; then
    echo "Error: --board must be provided or DEFAULT_BOARD must be set"
    usage
    exit 1
fi

if [[ -z "$SHIELD" ]]; then
    echo "Error: --shield must be provided or DEFAULT_SHIELD must be set"
    usage
    exit 1
fi

# Set build directory based on shield
BUILD_DIR="build/$SHIELD"

# Build flags
WEST_FLAGS="-s zmk/app -b $BOARD"
[[ $PRISTINE -eq 1 ]] && WEST_FLAGS="$WEST_FLAGS -p"
[[ $DEBUG -eq 1 ]] && WEST_FLAGS="$WEST_FLAGS -- -DWEST_LOG_LEVEL=debug"

# Additional CMake flags
CMAKE_FLAGS="-DZMK_CONFIG=$CONFIG_DIR -DSHIELD=$SHIELD"
[[ -n $SNIPPET ]] && CMAKE_FLAGS="$CMAKE_FLAGS -DSNIPPET=$SNIPPET"

# Run the build
west build $WEST_FLAGS -d "$BUILD_DIR" -- $CMAKE_FLAGS

# Ensure output directory exists
mkdir -p "$OUT_DIR"

# Copy and rename the UF2
cp "$BUILD_DIR/zephyr/zmk.uf2" "$OUT_DIR/${SHIELD}_${BOARD}.uf2"

echo "Build complete!"
echo "UF2 file copied to: $OUT_DIR/${SHIELD}_${BOARD}.uf2"
