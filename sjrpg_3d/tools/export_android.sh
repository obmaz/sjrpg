#!/usr/bin/env bash
# APK debug uses the configured debug keystore; release requires the user's signing key.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/tools/android-toolchain.env"
MODE=debug
case "${1:-}" in
  ""|--debug) ;;
  --release) MODE=release ;;
  *) echo "Usage: tools/export_android.sh [--debug|--release]" >&2; exit 2 ;;
esac
[ "$#" -le 1 ] || { echo "Unexpected Android export argument" >&2; exit 2; }
VERSION="$(tr -d '[:space:]' < "$ROOT/../.godot-version")"
SDK="${ANDROID_HOME:-$HOME/android-sdk}"
test -f "${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates/$VERSION.stable/android_$MODE.apk" || { echo "Run tools/setup_android.sh first"; exit 1; }
if [ "$MODE" = release ]; then
  : "${GODOT_ANDROID_KEYSTORE_RELEASE_PATH:?Release keystore path is required}"
  : "${GODOT_ANDROID_KEYSTORE_RELEASE_USER:?Release keystore alias is required}"
  : "${GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD:?Release keystore password is required}"
fi
mkdir -p "$ROOT/build/android"
touch "$ROOT/build/.gdignore"
OUT="$ROOT/build/android/sjrpg_3d-$MODE.apk"
LOG="$(mktemp)"
trap 'rm -f "$LOG"' EXIT
"$ROOT/tools/import_project.sh"
if ! "$ROOT/tools/godot.sh" --headless "--export-$MODE" Android "$OUT" >"$LOG" 2>&1; then cat "$LOG"; exit 1; fi
if grep -E "SCRIPT ERROR|Parse Error|^ERROR:" "$LOG"; then echo "Android export failed"; exit 1; fi
test -s "$OUT"
"$SDK/build-tools/$SJRPG_ANDROID_BUILD_TOOLS/zipalign" -c -P 16 4 "$OUT"
"$SDK/build-tools/$SJRPG_ANDROID_BUILD_TOOLS/apksigner" verify "$OUT"
"$SDK/build-tools/$SJRPG_ANDROID_BUILD_TOOLS/aapt2" dump badging "$OUT" >"$ROOT/build/android/package.txt"
grep -E "^(package:|sdkVersion:|targetSdkVersion:|native-code:|application-label:)" "$ROOT/build/android/package.txt"
python3 "$ROOT/tools/check_platform_exports.py" --android "$OUT" --package-info "$ROOT/build/android/package.txt" --out "$ROOT/build/android/export-report.json"
printf 'export ok: %s\n' "${OUT#$ROOT/}"
