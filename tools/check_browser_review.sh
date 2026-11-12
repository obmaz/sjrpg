#!/usr/bin/env bash
# tools/ci.sh 산출물 또는 같은 CI 아티팩트로 실제 브라우저 검사를 실행한다.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
REVIEW="${1:-all}"
if [[ "$REVIEW" == all ]]; then
  for ITEM in native save loading gamepad music equipment; do "$0" "$ITEM"; done
  exit 0
fi
case "$REVIEW" in
  native) CHECKER="" ;;
  save) CHECKER=check_save_layout.mjs ;;
  loading) CHECKER=check_entry_loading.mjs ;;
  gamepad) CHECKER=check_gamepad.mjs ;;
  music) CHECKER=check_music_memory.mjs ;;
  equipment) CHECKER=check_equipment_layout.mjs ;;
  *) echo "알 수 없는 브라우저 검사: $REVIEW" >&2; exit 2 ;;
esac
EXPORT="$ROOT/build/ci/web"
test -f "$EXPORT/3d/index.html"
if [[ "$REVIEW" == native ]]; then
  for CHECK in check_shell check_install check_fullscreen check_orientation check_back check_canvas_budget; do
    node "sjrpg_3d/web/$CHECK.mjs"
  done
  node sjrpg_3d/tools/check_music_memory.mjs --self-test
  if [[ -f "$EXPORT/index.html" ]]; then node tools/test_portal.mjs; fi
  export SJRPG_WEB_TEST_ROOT="$EXPORT"
  exec tools/check_native_web.sh
fi
PORT="${SJRPG_BROWSER_REVIEW_PORT:-8779}"
[[ "$PORT" =~ ^[0-9]+$ ]] || { echo "잘못된 포트" >&2; exit 2; }
OUT="$ROOT/build/review/$REVIEW"
mkdir -p "$OUT"
python3 -m http.server "$PORT" --bind 127.0.0.1 --directory "$EXPORT/3d" > "$OUT/server.log" 2>&1 &
SERVER_PID=$!
trap 'kill "$SERVER_PID" 2>/dev/null || true' EXIT
curl --fail --silent --show-error --max-time 2 --retry 10 --retry-connrefused --retry-delay 1 --retry-max-time 12 "http://127.0.0.1:$PORT/" > /dev/null
kill -0 "$SERVER_PID" 2>/dev/null || { echo "브라우저 검사 포트 사용 중" >&2; exit 1; }
SJRPG_MUSIC_PROFILE=fold node "sjrpg_3d/tools/$CHECKER" "http://127.0.0.1:$PORT/" "$OUT"
