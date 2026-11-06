#!/usr/bin/env bash
# .godot-version의 실행 파일을 찾아 인자를 그대로 넘깁니다. GODOT/GODOT_VERSION은 명시적 재정의입니다.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${GODOT_VERSION:-$(cat "$ROOT/.godot-version")}"
TOOLS_DIR="${GODOT_HOME:-$HOME/.godot-tools}"
if [ -n "${GODOT:-}" ]; then BIN="$GODOT"
elif [ -x "$TOOLS_DIR/godot-$VERSION" ]; then BIN="$TOOLS_DIR/godot-$VERSION"
elif command -v godot >/dev/null 2>&1 && [[ "$(godot --version)" == "$VERSION."* ]]; then BIN="$(command -v godot)"
else BIN="$("$ROOT/tools/setup_godot.sh")"
fi
ACTUAL_VERSION="$("$BIN" --version)"
if [[ "$ACTUAL_VERSION" != "$VERSION."* ]]; then
  echo "Godot 버전 불일치: 프로젝트 $VERSION, 실행 파일 $ACTUAL_VERSION ($BIN)" >&2
  exit 1
fi
cd "$ROOT"
exec "$BIN" "$@"
