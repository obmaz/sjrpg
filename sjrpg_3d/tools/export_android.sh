#!/usr/bin/env bash
# 안드로이드 APK를 build/android/ 에 만듭니다. 먼저 tools/setup_android.sh 로 도구를 준비합니다.
#   tools/export_android.sh            → 디버그 APK (디버그 키로 서명, 설치해 시험하는 용도)
#   tools/export_android.sh --release  → 릴리스 APK. 서명 키는 환경 변수로 받습니다:
#       GODOT_ANDROID_KEYSTORE_RELEASE_PATH / _USER / _PASSWORD  (키스토어는 저장소에 두지 않습니다)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MODE="debug"; [ "${1:-}" = "--release" ] && MODE="release"
VERSION="$(tr -d '[:space:]' < "$ROOT/../.godot-version")"
SDK="${ANDROID_HOME:-$HOME/android-sdk}"
test -f "$HOME/.local/share/godot/export_templates/$VERSION.stable/android_$MODE.apk" || { echo "템플릿이 없습니다: tools/setup_android.sh 를 먼저 실행하세요"; exit 1; }
if [ "$MODE" = "release" ]; then
  : "${GODOT_ANDROID_KEYSTORE_RELEASE_PATH:?릴리스 키스토어 경로(GODOT_ANDROID_KEYSTORE_RELEASE_PATH)가 필요합니다}"
  : "${GODOT_ANDROID_KEYSTORE_RELEASE_USER:?}"; : "${GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD:?}"
fi
mkdir -p "$ROOT/build/android"; touch "$ROOT/build/.gdignore"
OUT="$ROOT/build/android/sjrpg_3d-$MODE.apk"
LOG="$(mktemp)"; trap 'rm -f "$LOG"' EXIT
"$ROOT/tools/godot.sh" --headless --import >"$LOG" 2>&1 || true
if grep -E "SCRIPT ERROR|Parse Error" "$LOG"; then echo "스크립트 오류로 export 중단"; exit 1; fi
"$ROOT/tools/godot.sh" --headless "--export-$MODE" "Android" "$OUT" >"$LOG" 2>&1 || { grep -E "ERROR|error" "$LOG"; exit 1; }
grep -q "^ERROR" "$LOG" && { grep "^ERROR" "$LOG"; exit 1; }
test -s "$OUT"
"$SDK/build-tools/35.0.1/apksigner" verify "$OUT" >/dev/null 2>&1 || { echo "서명 검증 실패"; exit 1; }
printf "export ok: %s (%s, %s)\n" "${OUT#$ROOT/}" "$(du -h "$OUT" | cut -f1)" "$("$SDK/build-tools/35.0.1/aapt2" dump badging "$OUT" 2>/dev/null | sed -n "s/^package: name='\([^']*\)'.*versionName='\([^']*\)'.*/\1 v\2/p")"
