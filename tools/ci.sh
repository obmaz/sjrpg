#!/usr/bin/env bash
# 로컬과 GitHub가 같은 검사·빌드를 실행한다. 공개 배포/API 호출은 하지 않는다.
# tools/ci.sh                 3D 전체 검사 + Web export
# tools/ci.sh --browser       위 검사 + 실제 브라우저 검수 6종
# tools/ci.sh --all-editions  공개 웹 배포 준비용: 동결된 2D와 포털도 검사·조립
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
ALL=0
WITH_BROWSER=0
for ARG in "$@"; do
  case "$ARG" in
    --all-editions) ALL=1 ;;
    --browser) WITH_BROWSER=1 ;;
    *) echo "알 수 없는 인자: $ARG" >&2; exit 2 ;;
  esac
done
python3 tools/check_workflows.py
python3 tools/test_ci.py
python3 sjrpg_3d/tools/test_stamp_web.py
python3 sjrpg_3d/tools/test_import_project.py
python3 sjrpg_3d/tools/test_resource_layout.py
node sjrpg_3d/tools/review/test_diagnostic_contracts.mjs
node --check sjrpg_3d/tools/check_native_style.mjs
node --check sjrpg_3d/tools/check_combat_visibility.mjs
if [[ "$ALL" == 1 ]]; then
  tools/check.sh --export
else
  tools/check.sh --project=3d
  sjrpg_3d/tools/export_web.sh
fi
# 이번 검사의 산출물만 보관한다. 기존 build/web와 게임 export는 지우지 않는다.
python3 - "$ALL" <<'PY'
from pathlib import Path
import shutil, sys
target = Path('build/ci/web')
if target.exists():
    shutil.rmtree(target)
if sys.argv[1] == '1':
    shutil.copytree('build/web', target)
else:
    shutil.copytree('sjrpg_3d/build/web', target / '3d')
(target / '.nojekyll').touch()
PY
if [[ "$WITH_BROWSER" == 1 ]]; then tools/check_browser_review.sh all; fi
echo "CI_PASS: 로컬/원격 공통 검사와 웹 빌드 완료"
