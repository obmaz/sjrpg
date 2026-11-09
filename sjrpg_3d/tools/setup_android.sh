#!/usr/bin/env bash
# Install the pinned toolchain and shared debug key; release keys stay external.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/tools/android-toolchain.env"
VERSION="$(tr -d '[:space:]' < "$ROOT/../.godot-version")"
SDK="${ANDROID_HOME:-$HOME/android-sdk}"
TEMPLATES="${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates/$VERSION.stable"
KEYSTORE="${GODOT_ANDROID_KEYSTORE_DEBUG_PATH:-$ROOT/tools/keys/debug-keystore.jks}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
command -v java >/dev/null || { echo "JDK 17 or newer is required"; exit 1; }
command -v keytool >/dev/null || { echo "JDK keytool is required"; exit 1; }
test -f "$KEYSTORE" || { echo "Missing debug keystore: $KEYSTORE" >&2; exit 1; }
keytool -list -keystore "$KEYSTORE" -storepass android -alias androiddebugkey >/dev/null 2>&1 || {
  echo "Debug keystore must contain androiddebugkey with the standard Android debug password" >&2
  exit 1
}
JDK="${JAVA_HOME:-$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")}"
MANAGER="$SDK/cmdline-tools/sjrpg-$SJRPG_ANDROID_COMMANDLINE_TOOLS/bin/sdkmanager"
if [ ! -x "$MANAGER" ]; then
  mkdir -p "$SDK/cmdline-tools" "$WORK/cmd"
  curl --fail --silent --show-error --location --retry 3 -o "$WORK/cmd.zip" "https://dl.google.com/android/repository/commandlinetools-linux-${SJRPG_ANDROID_COMMANDLINE_TOOLS}_latest.zip"
  unzip -q "$WORK/cmd.zip" -d "$WORK/cmd"
  mv "$WORK/cmd/cmdline-tools" "$SDK/cmdline-tools/sjrpg-$SJRPG_ANDROID_COMMANDLINE_TOOLS"
fi
if [ ! -x "$SDK/build-tools/$SJRPG_ANDROID_BUILD_TOOLS/apksigner" ] || [ ! -d "$SDK/platforms/android-$SJRPG_ANDROID_API" ] || [ ! -x "$SDK/platform-tools/adb" ]; then
  # Ignore only yes's expected broken pipe; preserve sdkmanager's exit status.
  (yes || true) | "$MANAGER" --sdk_root="$SDK" --licenses >"$WORK/licenses.log" 2>&1 || { cat "$WORK/licenses.log"; exit 1; }
  "$MANAGER" --sdk_root="$SDK" "platform-tools" "build-tools;$SJRPG_ANDROID_BUILD_TOOLS" "platforms;android-$SJRPG_ANDROID_API"
fi
if [ ! -f "$TEMPLATES/android_release.apk" ] || [ ! -f "$TEMPLATES/android_debug.apk" ]; then
  python3 "$ROOT/tools/fetch_android_templates.py" --version "$VERSION" --destination "$TEMPLATES"
fi
SETTINGS="${XDG_CONFIG_HOME:-$HOME/.config}/godot/editor_settings-${VERSION%.*}.tres"
mkdir -p "$(dirname "$SETTINGS")"
python3 - "$SETTINGS" "$SDK" "$JDK" "$KEYSTORE" <<'PY'
import json, re, sys
from pathlib import Path
path, sdk, jdk, keystore = sys.argv[1:]
destination = Path(path)
text = destination.read_text() if destination.exists() else '[gd_resource type="EditorSettings" format=3]\n\n[resource]\n'
values = {"export/android/android_sdk_path":sdk, "export/android/java_sdk_path":jdk,
          "export/android/debug_keystore":keystore, "export/android/debug_keystore_user":"androiddebugkey",
          "export/android/debug_keystore_pass":"android"}
for key, value in values.items():
    line = key + " = " + json.dumps(value)
    pattern = "^" + re.escape(key) + r" =.*$"
    text = re.sub(pattern, lambda _: line, text, flags=re.M) if re.search(pattern, text, re.M) else text.rstrip("\n") + "\n" + line + "\n"
destination.write_text(text)
PY
echo "Android toolchain ready: API $SJRPG_ANDROID_API; build-tools $SJRPG_ANDROID_BUILD_TOOLS"
