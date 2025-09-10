#!/usr/bin/env bash
set -euo pipefail

# Default volume name (just the name, not full path)
VOLUME_NAME="${DEFAULT_VOLUME:-NICENANO}"  
UF2_FILE=""

usage() {
  cat <<EOF
Usage: $0 [options]

Options:
  --volume <name>     Name of the mounted board under /Volumes (default: \$DEFAULT_VOLUME or NICENANO)
  --uf2 <file>        Path to UF2 file to flash (required)
  -h, --help          Show this help message
EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --volume) VOLUME_NAME="$2"; shift 2 ;;
        --uf2) UF2_FILE="$2"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *)
            echo "Unknown argument: $1"
            usage
            exit 1 ;;
    esac
done

VOLUME_PATH="/Volumes/$VOLUME_NAME"

# Validation
if [[ -z "$UF2_FILE" ]]; then
    echo "Error: --uf2 must be provided"
    usage
    exit 1
fi

if [[ ! -f "$UF2_FILE" ]]; then
    echo "Error: UF2 file '$UF2_FILE' does not exist"
    exit 1
fi

echo "Flashing UF2 file: $UF2_FILE"
echo "Waiting for MCU to appear at $VOLUME_PATH ..."

# Spinner chars
SPINNER='|/-\'
i=0

# Wait until the volume exists and is writable
while true; do
    if [[ -d "$VOLUME_PATH" && -w "$VOLUME_PATH" ]]; then
        echo -e "\nFound device at $VOLUME_PATH."
        echo -e "Waiting a few seconds to ensure it's ready..."
        sleep 5  # Give some extra time for the device to be ready
        break
    fi
    # Print spinner
    printf "\r[%c] Waiting for device..." "${SPINNER:i++%${#SPINNER}:1}"
    sleep 0.2
done

echo "Flashing $UF2_FILE to NICENANO ..."
cp "$UF2_FILE" "$VOLUME_PATH/"

if [[ $? -eq 0 ]]; then
    echo "Flash complete!"
else
    echo "Error: failed to copy UF2 to $VOLUME_PATH"
    exit 1
fi
