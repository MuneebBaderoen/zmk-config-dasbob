#!/usr/bin/env bash

set -euo pipefail

# --- User parameters ---
OUT_DIR=/zmk-out

find $OUT_DIR -name "*.uf2" -type f -delete
