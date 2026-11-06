#!/usr/bin/env bash
# 웹(HTML5/WASM, 단일 스레드) 빌드를 build/web 에 만듭니다. GitHub Pages 배포물과 같은 결과.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$ROOT/build/web"
# Local screenshots and prior exports are artifacts, not game resources.
touch "$ROOT/build/.gdignore"
LOG="$(mktemp)"; trap 'rm -f "$LOG"' EXIT
"$ROOT/tools/godot.sh" --headless --import >"$LOG" 2>&1 || true
if grep -E "SCRIPT ERROR|Parse Error" "$LOG"; then echo "스크립트 오류로 export 중단"; exit 1; fi
"$ROOT/tools/godot.sh" --headless --export-release "Web" build/web/index.html >"$LOG" 2>&1 || { cat "$LOG"; exit 1; }
test -s "$ROOT/build/web/index.wasm" && test -s "$ROOT/build/web/index.pck"
# The loading backdrop is available before the Godot pack is downloaded.
cp "$ROOT/web/loading-bg.webp" "$ROOT/web/entry-button.webp" "$ROOT/build/web/"
cp "$ROOT/web/manifest.webmanifest" "$ROOT/web/install.js" "$ROOT/web/install-sw.js" "$ROOT"/web/install-*.png "$ROOT/build/web/"
touch "$ROOT/build/web/.nojekyll"
# Immutable pack URLs prevent a cached prior deployment from supplying old game code.
PACK="$(python3 "$ROOT/tools/stamp_web.py" "$ROOT/build/web")"
printf "export ok: %s %s, wasm %s\n" "$PACK" "$(du -h "$ROOT/build/web/$PACK" | cut -f1)" "$(du -h "$ROOT/build/web/index.wasm" | cut -f1)"
