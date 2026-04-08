#!/usr/bin/env bash

set -euo pipefail

TEST_PATH="${1:-/repo/zmk-modules/sticky-mod-layer/tests/sticky-mod-layer}"

MODULES=""
for module in /repo/zmk-modules/*; do
  if [[ -f "$module/zephyr/module.yml" ]]; then
    if [[ -n "$MODULES" ]]; then
      MODULES="$MODULES;$module"
    else
      MODULES="$module"
    fi
  fi
done

cd /zmk-workspace/zmk/app
ZMK_EXTRA_MODULES="$MODULES" ./run-test.sh "$TEST_PATH"
