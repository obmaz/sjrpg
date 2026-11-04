#!/usr/bin/env bash
# Godot 실행 파일을 찾아 인자를 그대로 넘깁니다. 명시한 $GODOT 또는 프로젝트 버전(기본 4.5.1)을 사용합니다.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [ -n "${GODOT:-}" ]; then BIN="$GODOT"
elif [ -x "$HOME/.godot-tools/godot-${GODOT_VERSION:-4.5.1}" ]; then BIN="$HOME/.godot-tools/godot-${GODOT_VERSION:-4.5.1}"
elif command -v godot >/dev/null 2>&1 && [[ "$(godot --version)" == "${GODOT_VERSION:-4.5.1}."* ]]; then BIN="$(command -v godot)"
else BIN="$("$ROOT/tools/setup_godot.sh")"
fi
cd "$ROOT"
exec "$BIN" "$@"
