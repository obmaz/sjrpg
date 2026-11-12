"""일회용 체크아웃에만 전투 검수 관찰기를 연결한다. 로컬/수동 CI 공용."""
from pathlib import Path
import shutil
import sys

ROOT = Path(__file__).resolve().parents[1]
HOOK = '''\tif OS.has_feature("web") and str(JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('combat_visibility_review')", true)) == "1":
\t\tadd_child(load("res://scripts/combat_visibility_review.gd").new().setup(self))
'''


def prepare(target: Path) -> None:
    target = target.resolve()
    if target == ROOT:
        raise ValueError("운영 소스 대신 일회용 체크아웃 경로를 지정하세요")
    main = target / 'sjrpg_3d/scripts/app/main.gd'
    source = main.read_text()
    if HOOK not in source:
        needle = '\tshow_title()\n'
        if needle not in source or 'combat_visibility_review.gd' in source:
            raise ValueError("현재 진입 구조에 검수 연결 지점을 확인할 수 없습니다")
        main.write_text(source.replace(needle, needle + HOOK, 1))
    shutil.copy2(ROOT / 'sjrpg_3d/tools/perf/combat_visibility_review.gd', main.parent / 'combat_visibility_review.gd')


if __name__ == '__main__':
    if len(sys.argv) != 2:
        raise SystemExit('사용법: python3 tools/prepare_combat_review.py <일회용 체크아웃>')
    prepare(Path(sys.argv[1]))
