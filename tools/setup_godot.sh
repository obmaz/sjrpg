#!/usr/bin/env bash
# .godot-version의 Godot와 같은 버전의 웹 export 템플릿을 설치합니다.
#   tools/setup_godot.sh            → $GODOT_HOME(기본 ~/.godot-tools)에 설치하고 실행 파일 경로를 출력
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${GODOT_VERSION:-$(cat "$ROOT/.godot-version")}"
HOME_DIR="${GODOT_HOME:-$HOME/.godot-tools}"
BIN="$HOME_DIR/godot-$VERSION"
TEMPLATES="${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates/$VERSION.stable"
BASE="https://github.com/godotengine/godot/releases/download/$VERSION-stable"

mkdir -p "$HOME_DIR"
WORK_DIR="$(mktemp -d "$HOME_DIR/.godot-setup.XXXXXX")"
trap 'rm -rf "$WORK_DIR"' EXIT
if [ ! -x "$BIN" ]; then
  curl -fsSL -o "$WORK_DIR/godot.zip" "$BASE/Godot_v$VERSION-stable_linux.x86_64.zip"
  unzip -q "$WORK_DIR/godot.zip" -d "$WORK_DIR/bin"
  ACTUAL_VERSION="$("$WORK_DIR/bin/Godot_v$VERSION-stable_linux.x86_64" --version)"
  if [[ "$ACTUAL_VERSION" != "$VERSION."* ]]; then
    echo "다운로드한 Godot 버전 불일치: $ACTUAL_VERSION (예상 $VERSION)" >&2
    exit 1
  fi
  mv "$WORK_DIR/bin/Godot_v$VERSION-stable_linux.x86_64" "$BIN"
fi
if [ ! -f "$TEMPLATES/web_nothreads_release.zip" ]; then
  curl -fsSL -o "$WORK_DIR/templates.tpz" "$BASE/Godot_v$VERSION-stable_export_templates.tpz"
  unzip -q "$WORK_DIR/templates.tpz" 'templates/web_*' 'templates/version.txt' -d "$WORK_DIR/tpl"
  if [ "$(cat "$WORK_DIR/tpl/templates/version.txt")" != "$VERSION.stable" ]; then
    echo "다운로드한 export template 버전이 $VERSION.stable과 다릅니다" >&2
    exit 1
  fi
  mkdir -p "$TEMPLATES"
  mv "$WORK_DIR"/tpl/templates/* "$TEMPLATES/"
fi
echo "$BIN"
