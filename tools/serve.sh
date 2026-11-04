#!/usr/bin/env bash
# build/web 을 로컬에서 서빙합니다. 기본 http://localhost:8765  (인자: 포트)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PORT="${1:-8765}"
cd "$ROOT/build/web"
echo "http://localhost:$PORT/index.html"
exec python3 -m http.server "$PORT"
