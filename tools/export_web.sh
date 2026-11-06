#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$ROOT/build"
touch "$ROOT/build/.gdignore"
for EDITION in 2d 3d; do
  "$ROOT/sjrpg_$EDITION/tools/export_web.sh"
done
python3 "$ROOT/tools/assemble_web.py"
