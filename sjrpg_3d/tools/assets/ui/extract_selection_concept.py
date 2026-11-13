#!/usr/bin/env python3
"""사용자가 지정한 선택 시안의 장식을 잘라 라이브 글자가 없는9패치로 조립한다."""
import hashlib
import json
from pathlib import Path

from PIL import Image

PROJECT = Path(__file__).resolve().parents[3]
SOURCE = PROJECT / "assets/source/entry-redesign/selection-and-continue-concept.png"
OUTPUT = PROJECT / "assets/ui/entry/concept"
RECORD = PROJECT / "assets/source/entry-redesign/concept-extraction.json"

# 원본 좌표. 글자가 없는 내부 색 표본만 사용하고 테두리·모서리는 그대로 유지한다.
PARTS = {
    "info": ((30, 755, 639, 996), (14, 14), (570, 972, 586, 980)),
    "slot": ((694, 596, 1303, 702), (14, 14), (1210, 610, 1226, 626)),
    "slot_selected": ((694, 476, 1303, 584), (14, 14), (1210, 492, 1226, 508)),
    "stat": ((94, 915, 329, 968), (10, 8), (153, 932, 163, 948)),
}
ICONS = {
    "swords": (60, 778, 131, 842),
    "staff": (408, 231, 437, 267),
    "heart": (117, 929, 148, 956),
    "resource": (390, 924, 424, 958),
}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    original = Image.open(SOURCE).convert("RGBA")
    OUTPUT.mkdir(parents=True, exist_ok=True)
    report = {"source": str(SOURCE.relative_to(PROJECT)), "sourceSha256": sha(SOURCE),
              "method": "Original corners/edges, text-free source fill, live runtime labels; no generative redraw",
              "parts": {}}
    for name, (rect, margins, sample) in PARTS.items():
        crop = original.crop(rect)
        left, top = margins
        middle = 24
        width, height = crop.size
        # 9영역으로 줄여 원본 글자·직업 아이콘·슬롯 초상을 리소스에 굽지 않는다.
        result = Image.new("RGBA", (left * 2 + middle, top * 2 + middle))
        result.paste(original.crop(sample).resize(result.size, Image.Resampling.BILINEAR))
        boxes = [
            ((0, 0, left, top), (0, 0)),
            ((width-left, 0, width, top), (left+middle, 0)),
            ((0, height-top, left, height), (0, top+middle)),
            ((width-left, height-top, width, height), (left+middle, top+middle)),
        ]
        for source, at in boxes:
            result.paste(crop.crop(source), at)
        result.paste(crop.crop((width//2-12, 0, width//2+12, top)), (left, 0))
        result.paste(crop.crop((width//2-12, height-top, width//2+12, height)), (left, top+middle))
        result.paste(crop.crop((0, height//2-12, left, height//2+12)), (0, top))
        result.paste(crop.crop((width-left, height//2-12, width, height//2+12)), (left+middle, top))
        path = OUTPUT / (name + ".png")
        result.save(path, optimize=True)
        report["parts"][name] = {"sourceRect": list(rect), "sourceFillRect": list(sample),
                                 "margins": [left, top, left, top], "size": list(result.size),
                                 "runtime": str(path.relative_to(PROJECT)), "sha256": sha(path)}
    # 어두운 패널에서 옅은 선형 아이콘을 분리한다. RGB 붓질은 보존하고 알파만 만든다.
    report["icons"] = {}
    for name, rect in ICONS.items():
        icon = original.crop(rect)
        alpha = Image.new("L", icon.size)
        pixels = icon.load()
        alpha.putdata([round(max(0.0, min(1.0, (max(pixels[x, y][:3])-85)/60))*255)
                       for y in range(icon.height) for x in range(icon.width)])
        icon.putalpha(alpha)
        path = OUTPUT / (name + ".png")
        icon.save(path, optimize=True)
        report["icons"][name] = {"sourceRect": list(rect), "runtime": str(path.relative_to(PROJECT)),
                                "alpha": "source maximum RGB: 85..145 soft threshold", "sha256": sha(path)}
    RECORD.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")


if __name__ == "__main__":
    main()
