#!/usr/bin/env bash
# 로컬에서 디버그 APK를 만들고 Dropbox에 올립니다. 사용자가 APK 빌드를 명시적으로 요청했을 때만 실행합니다.
#   sjrpg_3d/tools/build_apk_dropbox.sh [--skip-build] [--dest-dir /sjrpg] [--link]
#     --skip-build   이미 만든 build/android/sjrpg_3d-debug.apk를 다시 빌드하지 않고 올립니다.
#     --dest-dir DIR Dropbox 폴더(기본 /sjrpg, 앱 폴더형 앱이면 앱 폴더 기준)
#     --link         공유 링크도 만들어 출력합니다.
# 자격 증명은 환경 변수로만 받습니다(upload_dropbox.py 참고). 빌드 전에 먼저 확인해 오래 걸린 뒤 실패하지 않게 합니다.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO="$(cd "$ROOT/.." && pwd)"
BUILD=1
UPLOAD_ARGS=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    --skip-build) BUILD=0 ;;
    --link) UPLOAD_ARGS+=(--link) ;;
    --dest-dir) [ "$#" -ge 2 ] || { echo "--dest-dir needs a value" >&2; exit 2; }; UPLOAD_ARGS+=(--dest-dir "$2"); shift ;;
    *) echo "Usage: build_apk_dropbox.sh [--skip-build] [--dest-dir DIR] [--link]" >&2; exit 2 ;;
  esac
  shift
done
if [ -z "${DROPBOX_ACCESS_TOKEN:-}" ] && { [ -z "${DROPBOX_APP_KEY:-}" ] || [ -z "${DROPBOX_APP_SECRET:-}" ] || [ -z "${DROPBOX_REFRESH_TOKEN:-}" ]; }; then
  echo "Set DROPBOX_APP_KEY, DROPBOX_APP_SECRET and DROPBOX_REFRESH_TOKEN before building" >&2
  exit 1
fi
if [ "$BUILD" = 1 ]; then
  "$REPO/tools/setup_godot.sh" >/dev/null
  "$ROOT/tools/setup_android.sh"
  "$ROOT/tools/export_android.sh"
fi
APK="$ROOT/build/android/sjrpg_3d-debug.apk"
test -s "$APK" || { echo "Missing $APK" >&2; exit 1; }
SHA="$(git -C "$REPO" rev-parse --short=8 HEAD)"
git -C "$REPO" diff --quiet HEAD -- || SHA="$SHA-dirty"
NAME="sjrpg_3d-debug-$(date -u +%Y%m%d)-$SHA.apk"
python3 "$ROOT/tools/upload_dropbox.py" "$APK" --name "$NAME" "${UPLOAD_ARGS[@]}"
