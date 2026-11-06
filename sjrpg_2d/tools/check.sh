#!/usr/bin/env bash
# 변경 후 한 번에 검증: ① 임포트(스크립트 오류) ② 테스트 러너 ③ (선택) 웹 export.
#   tools/check.sh                    # 임포트 + 전체 테스트
#   tools/check.sh --only=quests,bag  # 일부 케이스만
#   tools/check.sh --export           # 위에 더해 웹 빌드까지
# 종료 코드 0 = 통과. 스크립트·파서·엔진 ERROR 로그는 테스트 결과와 별개로 실패로 봅니다.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT_SH="$ROOT/tools/godot.sh"
ONLY=""; EXPORT=0
for a in "$@"; do
  case "$a" in
    --only=*) ONLY="$a" ;;
    --export) EXPORT=1 ;;
    *) echo "알 수 없는 인자: $a" >&2; exit 2 ;;
  esac
done
LOG="$(mktemp)"; trap 'rm -f "$LOG"' EXIT
fail=0

echo "── 1/3 임포트"
"$GODOT_SH" --headless --import >"$LOG" 2>&1
code=$?
# A clean editor can request the project's custom font before its first import creates it.
# Verify once more after import; persistent engine errors and all test errors still fail.
if [ $code -eq 0 ] && ! grep -qE "SCRIPT ERROR|Parse Error|Failed to load script" "$LOG" && grep -q '^ERROR:' "$LOG"; then
  "$GODOT_SH" --headless --import >"$LOG" 2>&1
  code=$?
fi
if [ $code -ne 0 ]; then echo "임포트 실패: Godot 종료 코드 $code (실행 파일이 이 OS용인지 확인)"; head -3 "$LOG"; fail=1
elif grep -E "SCRIPT ERROR|Parse Error|Failed to load script|^ERROR:" "$LOG"; then echo "임포트 실패"; fail=1
else echo "임포트 ok"; fi

# A broken autoload cannot run the test scene; stop instead of leaving Godot waiting forever.
if [ $fail -ne 0 ]; then exit 1; fi

echo "── 2/3 테스트"
if [ -n "$ONLY" ]; then "$GODOT_SH" --headless res://tests/run_all.tscn -- "$ONLY" >"$LOG" 2>&1
else "$GODOT_SH" --headless res://tests/run_all.tscn >"$LOG" 2>&1; fi
code=$?
grep -E "^(PASS|FAIL|RESULT|ART_AUDIT)|^FAIL |SCRIPT ERROR|^ERROR" "$LOG"
if [ $code -ne 0 ] || grep -qE "SCRIPT ERROR|^ERROR:" "$LOG"; then fail=1; fi
# 테스트 러너가 실제로 돌았는지: RESULT 줄이 없고 실패 0이 아니면 통과로 보지 않는다.
if ! grep -qE "^RESULT cases=[1-9][0-9]* failed=0 " "$LOG"; then echo "테스트 결과(RESULT … failed=0)를 확인하지 못했습니다"; fail=1; fi

if [ $EXPORT -eq 1 ]; then
  echo "── 3/3 웹 export"
  "$ROOT/tools/export_web.sh" || fail=1
fi

if [ $fail -eq 0 ]; then echo "✔ 전체 통과"; else echo "✘ 실패"; fi
exit $fail
