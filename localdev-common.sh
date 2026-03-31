#!/usr/bin/env zsh
set -euo pipefail

: "${SCRIPT_DIR:?SCRIPT_DIR must be set by the caller}"

REPO_ROOT="$SCRIPT_DIR"
FACTORIO_DATA_PATH="${FACTORIO_DATA_PATH:-$HOME/Library/Application Support/factorio}"
MODS_DIR="$FACTORIO_DATA_PATH/mods"
MOD_LIST_PATH="$MODS_DIR/mod-list.json"

MOD_NAME="$(
  python3 - "$REPO_ROOT/info.json" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as f:
    print(json.load(f)["name"])
PY
)"

set_mod_enabled() {
  local enabled="$1"

  python3 - "$MOD_LIST_PATH" "$MOD_NAME" "$enabled" <<'PY'
import json
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
mod_name = sys.argv[2]
enabled = sys.argv[3] == "true"

if path.exists():
    data = json.loads(path.read_text(encoding="utf-8"))
else:
    data = {"mods": []}

mods = data.setdefault("mods", [])

for mod in mods:
    if mod.get("name") == mod_name:
        mod["enabled"] = enabled
        break
else:
    mods.append({"name": mod_name, "enabled": enabled})

path.parent.mkdir(parents=True, exist_ok=True)
path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
PY
}
