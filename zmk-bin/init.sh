#!/bin/bash
set -e

WORKSPACE=/zmk-workspace
CONFIG_DIR=/zmk-config

# --- Initialize and update west ---
rm -rf $WORKSPACE/config
mkdir -p $WORKSPACE/config
cp -r $CONFIG_DIR/* $WORKSPACE/config 

west init -l config