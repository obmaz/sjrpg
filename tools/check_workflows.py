"""자동 CI는 한 곳에서 실행하고 진단 작업은 명시적으로 요청한다."""
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[1]


def check_workflows(root: Path = ROOT) -> None:
    automatic = []
    for path in sorted((root / ".github/workflows").iterdir()):
        if path.suffix not in {".yml", ".yaml"}:
            continue
        # YAML 1.1의 on→bool 변환을 피하고 GitHub와 같은 문자열 키를 읽는다.
        data = yaml.load(path.read_text(), Loader=yaml.BaseLoader)
        events = data.get("on", {})
        assert isinstance(events, dict), f"{path.name}: 이벤트를 명시적으로 설정하세요"
        assert "workflow_dispatch" in events, f"{path.name}: 수동 실행 필요"
        if path.name == "web.yml":
            assert set(events) == {"push", "pull_request", "workflow_dispatch"}
            automatic.append(path.name)
        else:
            assert set(events) == {"workflow_dispatch"}, f"{path.name}: 진단 자동 실행 금지"
        if path.name == "web.yml":
            assert data.get("permissions", {}).get("contents") == "read", path.name
    assert automatic == ["web.yml"], automatic
    print("WORKFLOW_POLICY_PASS: 자동 CI 1개, 나머지는 수동 진단")


if __name__ == "__main__":
    check_workflows()
