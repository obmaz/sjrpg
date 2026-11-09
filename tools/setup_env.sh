#!/usr/bin/env bash
# 새 클론에서 tools/check.sh와 웹 export를 돌릴 수 있게 개발 환경을 준비합니다.
#
#   tools/setup_env.sh                       .godot-version의 Godot를 설치하고 두 프로젝트를 임포트
#   tools/setup_env.sh --project=3d          임포트할 프로젝트 선택 (2d | 3d | all, 기본 all)
#   tools/setup_env.sh --templates web       웹 export 템플릿도 설치 (tools/check.sh --export에 필요, 1.3 GB 다운로드)
#   tools/setup_env.sh --templates android   Android export 템플릿만 설치 (필요한 두 APK만 받음, JDK·SDK는 제외)
#   tools/setup_env.sh --templates all       둘 다
#   tools/setup_env.sh --npm                 루트 node_modules 설치 (npm ci --ignore-scripts, 포털·웹 셸 검사용)
#   tools/setup_env.sh --skip-import         .godot 임포트 캐시를 만들지 않음
#   tools/setup_env.sh --check               아무것도 설치하지 않고 준비된 것과 빠진 것만 보고
#
# 환경 준비의 단일 출처입니다. 특정 에이전트에 묶이지 않으므로 Codex·Claude 클라우드 환경의 설정 스크립트,
# CI 단계, 직접 실행 어디서든 이 스크립트를 호출하세요. 로직을 복사하지 말고 호출해야 Godot 버전과 설치
# 절차가 `.godot-version`과 함께 저장소에 남습니다.
#
# 다시 실행해도 안전합니다. 이미 있는 것은 건너뛰고, 내려받은 Godot·템플릿은 릴리스가 함께 게시하는
# SHA-512 합계로 검증합니다. 어느 디렉터리에서 실행해도 됩니다.
#
# 설치 위치는 기존 래퍼(sjrpg_2d/tools/godot.sh, sjrpg_3d/tools/godot.sh)가 찾는 곳과 같습니다.
# 그래서 tools/setup_godot.sh로 이미 설치했다면 엔진·템플릿 다운로드를 건너뜁니다.
#
# 환경 변수:
#   GODOT          설치하지 않고 이 Godot 실행 파일을 사용 (godot.sh의 명시적 재정의와 동일)
#   GODOT_VERSION  .godot-version 대신 이 버전을 사용 (godot.sh와 동일)
#   GODOT_HOME     엔진 설치 위치 (기본 ~/.godot-tools, 실행 파일은 godot-<버전>)
#   XDG_DATA_HOME  export 템플릿은 $XDG_DATA_HOME/godot에 설치 (기본 ~/.local/share/godot)
#
# 네트워크: github.com, release-assets.githubusercontent.com (Godot 릴리스 다운로드),
# --npm에는 registry.npmjs.org. APK 빌드에는 JDK·Android SDK가 더 필요하며 sjrpg_3d/tools/setup_android.sh가
# 설치합니다. APK 빌드는 사용자가 요청했을 때만 합니다(AGENTS.md).
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

version="${GODOT_VERSION:-$(tr -d '[:space:]' < .godot-version)}"
release="https://github.com/godotengine/godot/releases/download/$version-stable"
godot_home="${GODOT_HOME:-$HOME/.godot-tools}"
engine_bin="$godot_home/godot-$version"
templates_dir="${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates/$version.stable"

check_only=0
skip_import=0
want_npm=0
want_web=0
want_android=0
project=all

usage() { sed -n '2,/^set -euo/p' "$0" | sed '$d' | sed 's/^# \{0,1\}//'; }
log() { printf '[setup_env] %s\n' "$*"; }
fail() { printf '[setup_env] 오류: %s\n' "$*" >&2; exit 1; }

set_templates() {
  case "$1" in
    web) want_web=1 ;;
    android) want_android=1 ;;
    all) want_web=1; want_android=1 ;;
    *) fail "--templates에는 web, android, all 중 하나가 필요합니다 (받은 값: '$1')" ;;
  esac
}
set_project() {
  case "$1" in
    2d|3d|all) project="$1" ;;
    *) fail "--project에는 2d, 3d, all 중 하나가 필요합니다 (받은 값: '$1')" ;;
  esac
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --check) check_only=1 ;;
    --skip-import) skip_import=1 ;;
    --npm) want_npm=1 ;;
    --templates)
      [[ $# -ge 2 ]] || fail "--templates에는 web, android, all 중 하나가 필요합니다"
      set_templates "$2"; shift ;;
    --templates=*) set_templates "${1#*=}" ;;
    --project)
      [[ $# -ge 2 ]] || fail "--project에는 2d, 3d, all 중 하나가 필요합니다"
      set_project "$2"; shift ;;
    --project=*) set_project "${1#*=}" ;;
    -h|--help) usage; exit 0 ;;
    *) fail "알 수 없는 옵션 '$1' (--help 참고)" ;;
  esac
  shift
done

work=""
cleanup() { if [[ -n "$work" ]]; then rm -rf "$work"; fi; }
trap cleanup EXIT

# 래퍼(godot.sh)와 같은 순서로 실행 파일을 찾되, 없을 때 자동 설치로 넘어가지 않습니다.
find_engine() {
  if [[ -n "${GODOT:-}" ]]; then printf '%s\n' "$GODOT"
  elif [[ -x "$engine_bin" ]]; then printf '%s\n' "$engine_bin"
  elif command -v godot > /dev/null 2>&1; then command -v godot
  fi
}
engine_version() { "$1" --version 2> /dev/null || true; }
engine_ready() {
  local bin
  bin="$(find_engine)"
  [[ -n "$bin" && -x "$bin" && "$(engine_version "$bin")" == "$version".stable.* ]]
}
web_ready() { [[ -f "$templates_dir/version.txt" && -f "$templates_dir/web_nothreads_release.zip" ]]; }
android_ready() { [[ -f "$templates_dir/version.txt" && -f "$templates_dir/android_debug.apk" && -f "$templates_dir/android_release.apk" ]]; }
# 임포트 캐시가 있으면 한 번은 임포트한 프로젝트입니다. 정합성은 tools/check.sh가 검사합니다.
imported() { [[ -d "sjrpg_$1/.godot" ]]; }
wants_project() { [[ "$project" == all || "$project" == "$1" ]]; }

# --- 점검 모드: 보고만 -------------------------------------------------------------------------
if [[ $check_only -eq 1 ]]; then
  status=0
  if engine_ready; then
    bin="$(find_engine)"
    log "Godot $version: 준비됨 ($bin, $(engine_version "$bin"))"
  else
    log "Godot $version: 없음 (tools/setup_env.sh를 실행하세요)"; status=1
  fi
  if command -v python3 > /dev/null; then log "python3: $(command -v python3)"; else log "python3: 없음 (3D 임포트와 텍스처 정책 검사에 필요)"; status=1; fi
  if command -v node > /dev/null; then log "node: $(command -v node)"; else log "node: 없음 (포털·웹 셸·화면 검사에만 필요)"; fi
  if [[ -d node_modules/playwright ]]; then log "node_modules: 설치됨"; else log "node_modules: 없음 (--npm, 포털·웹 셸·화면 검사에만 필요)"; fi
  for edition in 2d 3d; do
    if imported "$edition"; then log "sjrpg_$edition 임포트 캐시: 있음"; else log "sjrpg_$edition 임포트 캐시: 없음 (tools/setup_env.sh --project=$edition)"; fi
  done
  if web_ready; then log "웹 export 템플릿: 준비됨"; else log "웹 export 템플릿: 미설치 (웹 빌드에만 필요, --templates web)"; fi
  if android_ready; then log "Android export 템플릿: 준비됨"; else log "Android export 템플릿: 미설치 (APK 빌드에만 필요, --templates android)"; fi
  exit $status
fi

# --- 선행 도구 ---------------------------------------------------------------------------------
missing=()
for tool in curl unzip sha512sum python3; do
  command -v "$tool" > /dev/null || missing+=("$tool")
done
if [[ ${#missing[@]} -gt 0 ]]; then
  fail "필요한 도구가 없습니다: ${missing[*]}. Debian/Ubuntu: apt-get install -y curl unzip coreutils python3"
fi
if ! command -v node > /dev/null; then
  if [[ $want_npm -eq 1 ]]; then fail "--npm에는 node(npm 포함)가 필요합니다"; fi
  log "참고: node가 없습니다. 포털·웹 셸·화면 검사에만 필요합니다."
fi

fetch() {
  curl -fL --retry 4 --retry-delay 3 --retry-connrefused -sS -o "$2" "$1" \
    || fail "다운로드 실패: $1 (github.com과 release-assets.githubusercontent.com 접근이 허용되는지 확인하세요)"
}

# 내려받은 파일($work 안의 $1)을 릴리스의 SHA512-SUMS.txt와 대조합니다.
verify_download() {
  local name="$1" expected actual
  expected="$(awk -v n="$name" '$2 == n || $2 == "*" n {print $1; exit}' "$work/SHA512-SUMS.txt")"
  [[ -n "$expected" ]] || fail "$name 이(가) 릴리스의 SHA512-SUMS.txt에 없습니다"
  actual="$(sha512sum "$work/$name" | cut -d' ' -f1)"
  [[ "$expected" == "$actual" ]] || fail "$name 의 SHA-512가 다릅니다 (기대 $expected, 실제 $actual)"
}

# 다운로드 작업 디렉터리는 엔진 설치 위치 아래에 둡니다. 마지막 이동이 같은 파일시스템의 rename이 되고,
# 큰 임시 파일이 작은 /tmp를 채우지 않습니다.
ensure_work() {
  if [[ -z "$work" ]]; then
    mkdir -p "$godot_home"
    work="$(mktemp -d "$godot_home/.setup-XXXXXX")"
    log "Godot $version 의 SHA512-SUMS.txt를 받는 중 ..."
    fetch "$release/SHA512-SUMS.txt" "$work/SHA512-SUMS.txt"
  fi
}

# --- Godot 엔진 --------------------------------------------------------------------------------
if engine_ready; then
  bin="$(find_engine)"
  log "Godot $version 은(는) 이미 있습니다 ($bin)."
elif [[ -n "${GODOT:-}" ]]; then
  fail "GODOT=$GODOT 은(는) Godot $version stable 실행 파일이 아닙니다. 고치거나 GODOT를 해제하세요."
else
  [[ "$(uname -s)-$(uname -m)" == "Linux-x86_64" ]] || fail "자동 설치는 Linux x86_64만 지원합니다. Godot $version stable을 직접 설치하고 GODOT를 지정하세요."
  zip_name="Godot_v$version-stable_linux.x86_64.zip"
  ensure_work
  log "Godot $version 을(를) 받는 중 (약 78 MB) ..."
  fetch "$release/$zip_name" "$work/$zip_name"
  verify_download "$zip_name"
  unzip -q -o "$work/$zip_name" -d "$work/engine"
  staged="$work/engine/Godot_v$version-stable_linux.x86_64"
  [[ -f "$staged" ]] || fail "Godot 압축 파일에 Godot_v$version-stable_linux.x86_64 가 없습니다"
  chmod +x "$staged"
  # 래퍼는 실행 가능한 파일이면 신뢰하므로, 제자리에 놓기 전에 실제로 실행되는지 확인합니다.
  [[ "$(engine_version "$staged")" == "$version".stable.* ]] || fail "내려받은 Godot가 $version stable로 실행되지 않습니다. 시스템 라이브러리 누락이 흔한 원인입니다: $staged --version"
  mv -f "$staged" "$engine_bin"
  log "$engine_bin 에 설치했습니다."
fi
engine_ready || fail "Godot가 Godot $version stable로 실행되지 않습니다. $(find_engine) --version 으로 원인을 확인하세요."

# --- export 템플릿 (선택) ----------------------------------------------------------------------
need_web=0
need_android=0
if [[ $want_web -eq 1 ]] && ! web_ready; then need_web=1; fi
if [[ $want_android -eq 1 ]] && ! android_ready; then need_android=1; fi

if [[ $need_android -eq 1 ]]; then
  # 전체 묶음 대신 HTTP Range로 APK 두 개와 version.txt만 받고 항목별 CRC를 검증합니다.
  log "Android export 템플릿을 받는 중 (필요한 항목만) ..."
  if range_err="$(python3 sjrpg_3d/tools/fetch_android_templates.py --version "$version" --destination "$templates_dir" 2>&1 > /dev/null)"; then
    need_android=0
    log "Android export 템플릿을 $templates_dir 에 설치했습니다."
  else
    # Range 수신은 프록시·CDN 사정(간헐적 504, Range 미지원)으로 실패할 수 있습니다. 전체 묶음 수신(SHA-512 검증)으로 대체합니다.
    log "Range 수신이 실패했습니다 ($(tail -n 1 <<< "$range_err")). 전체 템플릿 묶음으로 대체합니다."
  fi
fi

# 웹 템플릿과, Range 수신이 안 된 Android 템플릿은 같은 묶음(.tpz)에서 한 번에 꺼냅니다.
if [[ $need_web -eq 1 || $need_android -eq 1 ]]; then
  tpz="Godot_v$version-stable_export_templates.tpz"
  patterns=('templates/version.txt')
  if [[ $need_web -eq 1 ]]; then patterns+=('templates/web_*'); fi
  if [[ $need_android -eq 1 ]]; then patterns+=('templates/android_debug.apk' 'templates/android_release.apk'); fi
  ensure_work
  log "export 템플릿 묶음을 받는 중 (약 1.3 GB) ..."
  fetch "$release/$tpz" "$work/$tpz"
  verify_download "$tpz"
  unzip -q -o "$work/$tpz" "${patterns[@]}" -d "$work/templates"
  rm -f "$work/$tpz"
  [[ "$(tr -d '[:space:]' < "$work/templates/templates/version.txt")" == "$version.stable" ]] || fail "내려받은 템플릿 버전이 $version.stable 과 다릅니다"
  mkdir -p "$templates_dir"
  mv -f "$work"/templates/templates/* "$templates_dir/"
  log "export 템플릿을 $templates_dir 에 설치했습니다."
fi
if [[ $want_web -eq 1 ]]; then web_ready || fail "$templates_dir 의 웹 export 템플릿이 불완전합니다"; fi
if [[ $want_android -eq 1 ]]; then android_ready || fail "$templates_dir 의 Android export 템플릿이 불완전합니다"; fi

# --- Node 의존성 (선택) ------------------------------------------------------------------------
if [[ $want_npm -eq 1 ]]; then
  log "npm 의존성을 설치하는 중 (npm ci --ignore-scripts) ..."
  npm ci --ignore-scripts --no-audit --no-fund > /dev/null || fail "npm ci가 실패했습니다. npm ci --ignore-scripts 로 원인을 확인하세요."
  log "브라우저 검사에는 Chromium이 필요합니다. 없다면: npx playwright install --with-deps chromium"
fi

# --- 프로젝트 임포트 ---------------------------------------------------------------------------
# 3D는 텍스처 정책 적용 → 임포트 → 정책 검증을 하는 공용 경계(import_project.sh)를 그대로 씁니다.
import_3d() { sjrpg_3d/tools/import_project.sh; }

# 2D는 동결된 프로젝트라 소스를 건드리지 않고 임포트 캐시(.godot)만 만듭니다. 새 에디터는 첫 임포트가
# 끝나기 전에 커스텀 글꼴을 요청해 ERROR를 남길 수 있으므로 한 번 더 실행해 확인합니다(check.sh와 동일한 이유).
import_2d() {
  local log_file attempt code
  log_file="$(mktemp)"
  for attempt in 1 2; do
    if sjrpg_2d/tools/godot.sh --headless --import > "$log_file" 2>&1; then code=0; else code=$?; fi
    if [[ $code -eq 0 ]] && ! grep -qE "SCRIPT ERROR|Parse Error|Failed to load script|^ERROR:" "$log_file"; then
      rm -f "$log_file"; return 0
    fi
  done
  cat "$log_file"; rm -f "$log_file"
  return 1
}

if [[ $skip_import -eq 0 ]]; then
  if wants_project 3d; then
    log "sjrpg_3d 를 임포트하는 중 (무시되는 .godot 캐시를 만듭니다) ..."
    import_3d > /dev/null || fail "sjrpg_3d 임포트가 실패했습니다. sjrpg_3d/tools/import_project.sh 로 원인을 확인하세요."
  fi
  if wants_project 2d; then
    log "sjrpg_2d 를 임포트하는 중 ..."
    import_2d || fail "sjrpg_2d 임포트가 실패했습니다. sjrpg_2d/tools/godot.sh --headless --import 로 원인을 확인하세요."
  fi
fi

log "준비됐습니다. 다음: tools/check.sh (웹 빌드는 --templates web 설치 후 tools/check.sh --export)"
