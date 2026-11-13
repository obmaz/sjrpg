#!/usr/bin/env python3
"""생성형 정제 원본에서 선택 화면 버튼을 픽셀 변경 없이 자르고 출처 해시를 기록한다."""
import hashlib
import json
from pathlib import Path

from PIL import Image

PROJECT = Path(__file__).resolve().parents[3]
SOURCE_DIR = PROJECT / "assets/source/entry-redesign"
RECORD = SOURCE_DIR / "selection-controls-generation.json"
OUTPUT = PROJECT / "assets/ui/entry/controls"


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    record = json.loads(RECORD.read_text())
    source = SOURCE_DIR / record["acceptedSource"]
    image = Image.open(source).convert("RGBA")
    OUTPUT.mkdir(parents=True, exist_ok=True)
    record["sourceSha256"] = sha(source)
    for generation in record["passes"]:
        generation["sourceSha256"] = sha(SOURCE_DIR / generation["source"])
        generation["referenceSha256"] = {
            name: sha(SOURCE_DIR / name) for name in generation["references"]
        }
    record["runtime"] = {}
    for name, rect in record["runtimeCrops"].items():
        crop = image.crop(rect)
        destination = OUTPUT / (name + ".png")
        crop.save(destination, optimize=True)
        record["runtime"][name] = {
            "path": str(destination.relative_to(PROJECT)),
            "size": list(crop.size),
            "sha256": sha(destination),
            "alphaRange": list(crop.getchannel("A").getextrema()),
        }
    RECORD.write_text(json.dumps(record, ensure_ascii=False, indent=2) + "\n")


if __name__ == "__main__":
    main()
