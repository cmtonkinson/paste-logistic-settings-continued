#!/usr/bin/env zsh
set -euo pipefail

SCRIPT_DIR=${0:A:h}
source "$SCRIPT_DIR/localdev-common.sh"

rm -f "$MODS_DIR/$MOD_NAME"
set_mod_enabled false
