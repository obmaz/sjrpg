#!/usr/bin/env bash
# Shared 3D import boundary: policy metadata first, engine-generated resources next.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOG="$(mktemp)"
trap 'rm -f "$LOG"' EXIT
python3 "$ROOT/tools/texture_policy.py" --apply
if "$ROOT/tools/godot.sh" --headless --import >"$LOG" 2>&1; then
  CODE=0
else
  CODE=$?
fi
# A fresh editor may request the custom font before its first import creates it.
if [ "$CODE" -eq 0 ] && ! grep -qE "SCRIPT ERROR|Parse Error|Failed to load script" "$LOG" && grep -q '^ERROR:' "$LOG"; then
  if "$ROOT/tools/godot.sh" --headless --import >"$LOG" 2>&1; then CODE=0; else CODE=$?; fi
fi
if [ "$CODE" -ne 0 ] || grep -qE "SCRIPT ERROR|Parse Error|Failed to load script|^ERROR:" "$LOG"; then
  cat "$LOG"
  echo "3D resource import failed"
  exit 1
fi
python3 "$ROOT/tools/texture_policy.py" --check
echo "3D import ok"
