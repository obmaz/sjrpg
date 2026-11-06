#!/usr/bin/env python3
"""Rectify one existing chapel glass pane; no paint, synthesis or relighting."""

import hashlib
import json
from pathlib import Path

import cv2
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets/source/remake/chapel-v2.png"
TARGET = ROOT / "assets/art/preview3d/chapel-glass.webp"
QUAD = [[625, 901], [648, 914], [648, 1030], [625, 1018]]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    image = np.asarray(Image.open(SOURCE).convert("RGB"))
    size = (128, 512)
    transform = cv2.getPerspectiveTransform(np.float32(QUAD), np.float32([[0, 0], [127, 0], [127, 511], [0, 511]]))
    patch = cv2.warpPerspective(image, transform, size, flags=cv2.INTER_CUBIC)
    TARGET.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(patch).save(TARGET, "WEBP", quality=94, method=6)
    record = {
        "operation": "Perspective rectification of an existing stained-glass pane; no painting, synthesis or baked scene-light addition.",
        "source": str(SOURCE.relative_to(ROOT)), "source_sha256": sha(SOURCE), "quad": QUAD,
        "output": str(TARGET.relative_to(ROOT)), "sha256": sha(TARGET), "size": list(size),
        "reference": "assets/source/style/approved-game-reference.jpg",
        "reference_sha256": sha(ROOT / "assets/source/style/approved-game-reference.jpg"),
        "limitation": "Original authored surface shading remains. This is a reused albedo detail, not a new PBR scan or generated scene approval.",
    }
    TARGET.with_suffix(".json").write_text(json.dumps(record, indent=2) + "\n")
    imported = TARGET.with_suffix(".webp.import")
    if not imported.exists():
        path = "res://" + str(TARGET.relative_to(ROOT))
        cached = "res://.godot/imported/" + TARGET.name + "-" + hashlib.md5(path.encode()).hexdigest() + ".ctex"
        imported.write_text(f'''[remap]
importer="texture"
type="CompressedTexture2D"
path="{cached}"
metadata={{"vram_texture": false}}

[deps]
source_file="{path}"
dest_files=PackedStringArray("{cached}")

[params]
compress/mode=1
compress/lossy_quality=0.9
mipmaps/generate=true
process/fix_alpha_border=true
''')
    print(str(TARGET.relative_to(ROOT)), TARGET.stat().st_size, sha(TARGET))


if __name__ == "__main__":
    main()
