#!/usr/bin/env python3
"""운영 자산의 소유 폴더와 정적 리소스 연결을 검사한다."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
RESOURCE_SUFFIXES = {".gd", ".tscn", ".tres", ".gdshader", ".gdshaderinc"}


def check_layout(root=ROOT):
    errors = []
    assets = root / "assets"
    for model in assets.rglob("*.glb"):
        if "source" in model.relative_to(assets).parts:
            continue
        if not model.is_relative_to(assets / "models") or model.name != "model.glb":
            errors.append(f"모델은 assets/models/<분류>/<이름>/model.glb에 둡니다: {model.relative_to(root)}")
        scene = model.with_name("visual.tscn")
        if not scene.is_file():
            errors.append(f"모델 진입 씬 누락: {scene.relative_to(root)}")
        elif f'path="res://{model.relative_to(root).as_posix()}"' not in scene.read_text():
            errors.append(f"진입 씬이 같은 폴더의 모델을 읽지 않습니다: {scene.relative_to(root)}")
    for script in (root / "scripts").glob("*.gd"):
        errors.append(f"운영 스크립트를 역할 폴더에 배치합니다: {script.relative_to(root)}")
    for folder in ("scripts", "scenes", "assets/models", "assets/materials", "assets/sprites", "tests", "tools"):
        for resource in (root / folder).rglob("*"):
            if resource.suffix not in RESOURCE_SUFFIXES or not resource.is_file():
                continue
            for reference in re.findall(r'\bres://([^"\s)]+)', resource.read_text()):
                if "%" in reference or not Path(reference).suffix:  # 동적 템플릿은 실제 씬/모델 테스트가 검사한다.
                    continue
                target = root / reference
                if not target.resolve().is_relative_to(root.resolve()) or not target.exists():
                    errors.append(f"연결이 끊긴 리소스: {resource.relative_to(root)} -> {reference}")
    if errors:
        raise ValueError("\n".join(errors))
    print("RESOURCE_LAYOUT_PASS: 모델 소유 폴더·씬·정적 리소스 연결")


if __name__ == "__main__":
    check_layout()
