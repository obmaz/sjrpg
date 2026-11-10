#!/usr/bin/env bash
# Shared 3D import boundary: policy metadata first, engine-generated resources next.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOG="$(mktemp)"
trap 'rm -f "$LOG" "$LOG.first"' EXIT
python3 "$ROOT/tools/texture_policy.py" --apply
if "$ROOT/tools/godot.sh" --headless --import >"$LOG" 2>&1; then
  CODE=0
else
  CODE=$?
fi
# 최초 폰트 캐시가 없던 4.7.2 에디터는 임포트를 끝낸 뒤 종료 중
# SIGABRT(134)를 내기도 한다. 이 완료된 초기화에만 한 번 재검사를 허용한다.
FONT_BOOTSTRAP_ABORT=0
if [ "$CODE" -eq 134 ] && grep -qE "^ERROR: Cannot open file 'res://\\.godot/imported/[^']+\\.fontdata'" "$LOG" && grep -q 'DONE.*reimport' "$LOG"; then
  FONT_BOOTSTRAP_ABORT=1
fi
if { [ "$CODE" -eq 0 ] || [ "$FONT_BOOTSTRAP_ABORT" -eq 1 ]; } && ! grep -qE "SCRIPT ERROR|Parse Error|Failed to load script" "$LOG" && grep -q '^ERROR:' "$LOG"; then
  cp "$LOG" "$LOG.first"
  echo "3D 최초 임포트 결과를 새 폰트 캐시로 한 번 재검사합니다 (exit $CODE)"
  if "$ROOT/tools/godot.sh" --headless --import >"$LOG" 2>&1; then CODE=0; else CODE=$?; fi
fi
if [ "$CODE" -ne 0 ] || grep -qE "SCRIPT ERROR|Parse Error|Failed to load script|^ERROR:" "$LOG"; then
  if [ -f "$LOG.first" ]; then cat "$LOG.first"; fi
  cat "$LOG"
  echo "3D resource import failed"
  exit 1
fi
python3 "$ROOT/tools/texture_policy.py" --check
echo "3D import ok"
