#!/usr/bin/env bash
# Exercise live WebGL resize, not just separate fresh-orientation screenshots.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PORT="${SJRPG_WEB_TEST_PORT:-8766}"
[[ "$PORT" =~ ^[0-9]+$ ]] || { echo "Invalid test port" >&2; exit 2; }
mkdir -p "$ROOT/build/review"
python3 -m http.server "$PORT" --bind 127.0.0.1 --directory "$ROOT/build/web" > "$ROOT/build/review/server.log" 2>&1 &
SERVER_PID=$!
trap 'kill "$SERVER_PID" 2>/dev/null || true' EXIT
python3 - "$PORT" <<'PY'
import sys, time, urllib.request
for attempt in range(50):
    try:
        urllib.request.urlopen(f"http://127.0.0.1:{sys.argv[1]}/3d/", timeout=1).close()
        break
    except OSError:
        time.sleep(.1)
else:
    raise SystemExit("Native web test server did not start")
PY
kill -0 "$SERVER_PID" 2>/dev/null || { echo "Native web test port is already occupied" >&2; exit 1; }
for SCENE in chapel_reference cave_entry; do
  QUALITY=high
  if [[ "$SCENE" == cave_entry ]]; then QUALITY=low; fi
  node "$ROOT/sjrpg_3d/tools/screenshot.mjs" \
    --url "http://127.0.0.1:$PORT/3d/" --scene "$SCENE" --class mage \
    --device phone --viewport 390x844 --dpr 1 --quality "$QUALITY" --rotate 1 \
    --settle 1500 --out "$ROOT/build/review/$SCENE.png"
done
