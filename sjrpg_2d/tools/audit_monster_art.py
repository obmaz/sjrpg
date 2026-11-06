#!/usr/bin/env python3
"""Check the reviewed monster atlas bytes/layout; this cannot certify a camera angle."""

import hashlib
import json
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "tools/extract/monster_art_measure.json"


def inspect(name: str) -> dict:
    texture = ROOT / f"assets/art/actors/{name}.webp"
    metadata = ROOT / f"assets/art/actors/{name}.json"
    data = json.loads(metadata.read_text())
    with Image.open(texture) as image:
        size = list(image.size)
    frames = data["frames"]
    feet = data["feet"]
    invalid = []
    ground_below_crop = []
    for index, (x, y, width, height) in enumerate(frames):
        if min(x, y) < 0 or min(width, height) <= 0 or x + width > size[0] or y + height > size[1]:
            invalid.append(index)
        foot_x, foot_y = feet[index]
        if not 0 <= foot_x - x <= width:
            invalid.append(index)
        if foot_y > y + height:
            ground_below_crop.append([index, foot_y - y - height])
    return {
        "texture": str(texture.relative_to(ROOT)),
        "texture_sha256": hashlib.sha256(texture.read_bytes()).hexdigest(),
        "metadata": str(metadata.relative_to(ROOT)),
        "metadata_sha256": hashlib.sha256(metadata.read_bytes()).hexdigest(),
        "texture_size": size,
        "frame_count": len(frames),
        "anchor_count": len(feet),
        "walk": data["walk"],
        "attack": data["enemyAttack"],
        "frame_width_range": [min(f[2] for f in frames), max(f[2] for f in frames)],
        "frame_height_range": [min(f[3] for f in frames), max(f[3] for f in frames)],
        "reference_height": data["sizes"][0][1],
        "native_body_height": data["nativeBodyHeight"],
        "artwork_world_height_multiplier": data["artworkWorldHeightMultiplier"],
        "ground_below_crop": ground_below_crop,
        "invalid_frames": invalid,
    }


def main() -> None:
    manifest = json.loads(MANIFEST.read_text())
    failures = []
    total = 0
    for name, reviewed in manifest["atlases"].items():
        actual = inspect(name)
        total += actual["frame_count"]
        for key, value in actual.items():
            if reviewed.get(key) != value:
                failures.append(f"{name}: {key} differs from the reviewed manifest")
        if actual["invalid_frames"] or actual["frame_count"] != 128 or actual["anchor_count"] != 128:
            failures.append(f"{name}: invalid frame/anchor layout")
        if actual["walk"] != {"directions": 8, "frames": 8, "layout": "direction-major"}:
            failures.append(f"{name}: unexpected walking layout")
        if actual["attack"] != {"directions": 8, "frames": 8, "offset": 64, "layout": "direction-major"}:
            failures.append(f"{name}: unexpected attack layout")
    if failures:
        raise SystemExit("\n".join(failures))
    print(f"Reviewed monster bytes/layout: {len(manifest['atlases'])} atlases, {total} frames; camera elevation remains visually assessed, not numerically certified.")


if __name__ == "__main__":
    main()
