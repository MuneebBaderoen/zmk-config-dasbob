#!/usr/bin/env bash
set -euo pipefail

BUILD_SCRIPT="/zmk-bin/build.sh"
TARGETS_FILE="/zmk-build.yaml"

# Use Python to read include entries
mapfile -t TARGETS < <(
    python3 - <<PY
import yaml, sys
with open("$TARGETS_FILE") as f:
    data = yaml.safe_load(f)
for entry in data.get("include", []):
    board = entry.get("board")
    shield = entry.get("shield")
    snippet = entry.get("snippet", "")
    print(f"{board}\t{shield}\t{snippet}")
PY
)

for t in "${TARGETS[@]}"; do
    IFS=$'\t' read -r BOARD SHIELD SNIPPET <<< "$t"
    echo "Building board=$BOARD shield=$SHIELD snippet=$SNIPPET"

    CMD=("$BUILD_SCRIPT" --board "$BOARD" --shield "$SHIELD")
    [[ -n "$SNIPPET" ]] && CMD+=(--snippet "$SNIPPET")

    echo "Running: ${CMD[*]}"
    "${CMD[@]}"
done
