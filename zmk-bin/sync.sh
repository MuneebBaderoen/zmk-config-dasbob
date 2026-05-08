#!/bin/bash

set -euo pipefail

WORKSPACE=/zmk-workspace
CONFIG_DIR=/zmk-config

# --- Initialize and update west ---
rm -rf $WORKSPACE/config
mkdir -p $WORKSPACE/config
cp -r $CONFIG_DIR/* $WORKSPACE/config 
