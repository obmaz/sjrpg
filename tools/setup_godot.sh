#!/usr/bin/env bash
# Godot 4.5.1 과 웹 export 템플릿을 설치합니다 (이미 있으면 건너뜀).
#   tools/setup_godot.sh            → $GODOT_HOME(기본 ~/.godot-tools)에 설치하고 실행 파일 경로를 출력
set -euo pipefail
VERSION="${GODOT_VERSION:-4.5.1}"
HOME_DIR="${GODOT_HOME:-$HOME/.godot-tools}"
BIN="$HOME_DIR/godot-$VERSION"
TEMPLATES="$HOME/.local/share/godot/export_templates/$VERSION.stable"
BASE="https://github.com/godotengine/godot/releases/download/$VERSION-stable"

mkdir -p "$HOME_DIR"
if [ ! -x "$BIN" ]; then
  curl -fsSL -o "$HOME_DIR/godot.zip" "$BASE/Godot_v$VERSION-stable_linux.x86_64.zip"
  unzip -q -o "$HOME_DIR/godot.zip" -d "$HOME_DIR"
  mv "$HOME_DIR/Godot_v$VERSION-stable_linux.x86_64" "$BIN"
  rm -f "$HOME_DIR/godot.zip"
fi
if [ ! -f "$TEMPLATES/web_nothreads_release.zip" ]; then
  curl -fsSL -o "$HOME_DIR/templates.tpz" "$BASE/Godot_v$VERSION-stable_export_templates.tpz"
  unzip -q -o "$HOME_DIR/templates.tpz" 'templates/web_*' 'templates/version.txt' -d "$HOME_DIR/tpl"
  mkdir -p "$TEMPLATES"
  mv "$HOME_DIR"/tpl/templates/* "$TEMPLATES/"
  rm -rf "$HOME_DIR/tpl" "$HOME_DIR/templates.tpz"
fi
echo "$BIN"
