#!/usr/bin/env bash
# 안드로이드 APK를 만들기 위한 도구를 설치합니다 (이미 있으면 건너뜀). JDK 17+ 가 필요합니다.
#   tools/setup_android.sh     → Android SDK(플랫폼 35, 빌드 도구 35.0.1), Godot 안드로이드 템플릿, 디버그 키스토어,
#                                Godot 에디터 설정(SDK·JDK·키스토어 경로)을 준비
# 환경 변수: ANDROID_HOME(기본 ~/android-sdk), JAVA_HOME(기본 java 위치에서 추정)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="$(tr -d '[:space:]' < "$ROOT/../.godot-version")"
SDK="${ANDROID_HOME:-$HOME/android-sdk}"
CMDLINE_URL="https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip"
BASE="https://github.com/godotengine/godot/releases/download/$VERSION-stable"
TEMPLATES="$HOME/.local/share/godot/export_templates/$VERSION.stable"
KEYSTORE="$HOME/.android/debug.keystore"
JDK="${JAVA_HOME:-$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")}"
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT

command -v java >/dev/null || { echo "JDK가 필요합니다 (apt install openjdk-21-jdk)"; exit 1; }

if [ ! -x "$SDK/build-tools/35.0.1/apksigner" ] || [ ! -d "$SDK/platforms/android-35" ]; then
  mkdir -p "$SDK/cmdline-tools" "$WORK/cmd"
  curl -fsSL -o "$WORK/cmd.zip" "$CMDLINE_URL"
  unzip -q "$WORK/cmd.zip" -d "$WORK/cmd"
  rm -rf "$SDK/cmdline-tools/latest"; cp -r "$WORK/cmd/cmdline-tools" "$SDK/cmdline-tools/latest"
  yes | "$SDK/cmdline-tools/latest/bin/sdkmanager" --licenses >/dev/null 2>&1 || true
  "$SDK/cmdline-tools/latest/bin/sdkmanager" "platform-tools" "build-tools;35.0.1" "platforms;android-35" >/dev/null
fi

if [ ! -f "$TEMPLATES/android_release.apk" ] || [ ! -f "$TEMPLATES/android_debug.apk" ]; then
  mkdir -p "$TEMPLATES" "$WORK/tpl"
  curl -fsSL -o "$WORK/templates.tpz" "$BASE/Godot_v${VERSION}-stable_export_templates.tpz"
  unzip -q "$WORK/templates.tpz" 'templates/android_debug.apk' 'templates/android_release.apk' 'templates/version.txt' -d "$WORK/tpl"
  cp "$WORK"/tpl/templates/android_*.apk "$WORK/tpl/templates/version.txt" "$TEMPLATES/"
fi

if [ ! -f "$KEYSTORE" ]; then
  mkdir -p "$(dirname "$KEYSTORE")"
  keytool -genkey -keystore "$KEYSTORE" -storepass android -alias androiddebugkey -keypass android \
    -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Android Debug,O=Android,C=US" >/dev/null 2>&1
fi

# Godot 에디터 설정: 에디터를 한 번도 열지 않았다면 헤드리스 임포트로 설정 파일을 먼저 만든다.
SETTINGS="$HOME/.config/godot/editor_settings-${VERSION%.*}.tres"
[ -f "$SETTINGS" ] || "$ROOT/tools/godot.sh" --headless --import >/dev/null 2>&1 || true
python3 - "$SETTINGS" "$SDK" "$JDK" "$KEYSTORE" <<'PY'
import re, sys
path, sdk, jdk, keystore = sys.argv[1:]
text = open(path).read() if __import__("os").path.exists(path) else '[gd_resource type="EditorSettings" format=3]\n\n[resource]\n'
values = {
    "export/android/android_sdk_path": sdk, "export/android/java_sdk_path": jdk,
    "export/android/debug_keystore": keystore, "export/android/debug_keystore_user": "androiddebugkey",
    "export/android/debug_keystore_pass": "android",
}
for key, value in values.items():
    line = '%s = "%s"' % (key, value)
    pattern = "^" + re.escape(key) + r" =.*$"
    text = re.sub(pattern, line, text, flags=re.M) if re.search(pattern, text, re.M) else text.rstrip("\n") + "\n" + line + "\n"
open(path, "w").write(text)
PY
echo "android 준비 완료: SDK=$SDK 템플릿=$TEMPLATES"
