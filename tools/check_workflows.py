"""GitHub Actions는 푸시·PR로 자동 실행하지 않고, 수동 배포 워크플로 하나로 둔다."""
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[1]
DEPLOY = "deploy-pages.yml"


def check_workflows(root: Path = ROOT) -> None:
    names = []
    for path in sorted((root / ".github/workflows").iterdir()):
        if path.suffix not in {".yml", ".yaml"}:
            continue
        # YAML 1.1의 on→bool 변환을 피하고 GitHub와 같은 문자열 키를 읽는다.
        data = yaml.load(path.read_text(), Loader=yaml.BaseLoader)
        events = data.get("on", {})
        assert isinstance(events, dict), f"{path.name}: 이벤트를 명시적으로 설정하세요"
        assert set(events) == {"workflow_dispatch"}, f"{path.name}: 푸시·PR 등 자동 실행 금지, 수동 실행만 허용"
        names.append(path.name)
        if path.name == DEPLOY:
            assert data.get("permissions", {}).get("contents") == "read", path.name
    assert DEPLOY in names, f"{DEPLOY}: 수동 배포 워크플로가 필요합니다"
    print("WORKFLOW_POLICY_PASS: GitHub Actions는 수동 실행만 허용")


if __name__ == "__main__":
    check_workflows()
