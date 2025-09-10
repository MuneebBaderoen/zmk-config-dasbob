#!/usr/bin/env bash
# flash.sh
# Usage: ./flash.sh /path/to/firmware.uf2

UF2_FILE="$1"

if [[ -z "$UF2_FILE" ]]; then
    echo "Usage: $0 /path/to/firmware.uf2"
    exit 1
fi

if [[ ! -f "$UF2_FILE" ]]; then
    echo "Error: file '$UF2_FILE' not found"
    exit 1
fi

VOLUME_PATH="/Volumes/NICENANO"

echo "Waiting for Nice!Nano to appear at $VOLUME_PATH ..."

# Spinner chars
SPINNER='|/-\'
i=0

# Wait until the volume exists and is writable
while true; do
    if [[ -d "$VOLUME_PATH" && -w "$VOLUME_PATH" ]]; then
        echo -e "\nFound device at $VOLUME_PATH"
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
