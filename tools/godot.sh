#!/usr/bin/env bash
# Godot 실행 파일을 찾아 인자를 그대로 넘깁니다. 우선순위: $GODOT → PATH의 godot → ~/.godot-tools → 자동 설치.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [ -n "${GODOT:-}" ]; then BIN="$GODOT"
elif command -v godot >/dev/null 2>&1; then BIN="$(command -v godot)"
elif [ -x "$HOME/.godot-tools/godot-${GODOT_VERSION:-4.5.1}" ]; then BIN="$HOME/.godot-tools/godot-${GODOT_VERSION:-4.5.1}"
else BIN="$("$ROOT/tools/setup_godot.sh")"
fi
cd "$ROOT"
exec "$BIN" "$@"
