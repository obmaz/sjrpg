#!/usr/bin/env python3
"""Mechanically pack the generated light candidate; never paint replacement art."""
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/source/atmosphere/sunshaft-candidate.png"
GENERATION = ROOT / "tools/extract/forest_atmosphere_generation.json"
OUTPUT = ROOT / "assets/art/effects/forest-atmosphere.webp"


def record(path):
    return {"path": str(path.relative_to(ROOT)), "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}


def hull(points):
    points = sorted(set(points))

    def cross(origin, a, b):
        return (a[0] - origin[0]) * (b[1] - origin[1]) - (a[1] - origin[1]) * (b[0] - origin[0])

    lower, upper = [], []
    for point in points:
        while len(lower) >= 2 and cross(lower[-2], lower[-1], point) <= 0:
            lower.pop()
        lower.append(point)
    for point in reversed(points):
        while len(upper) >= 2 and cross(upper[-2], upper[-1], point) <= 0:
            upper.pop()
        upper.append(point)
    return lower[:-1] + upper[:-1]


def main():
    image = Image.open(SOURCE).convert("RGB")
    pixels = np.array(image)
    # Mechanical black-matte cleanup only. The complete generated source remains untouched.
    pixels[pixels.max(axis=2) <= 2] = 0
    image = Image.fromarray(pixels).resize((768, 768), Image.Resampling.LANCZOS)
    pixels = np.array(image)
    pixels[pixels.max(axis=2) <= 2] = 0
    image = Image.fromarray(pixels)
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    image.save(OUTPUT, "WEBP", quality=94, method=6)
    deployed = np.array(Image.open(OUTPUT).convert("RGB"))
    luminance = deployed @ np.array([0.2126, 0.7152, 0.0722])
    yy, xx = np.indices(luminance.shape)
    strong = luminance > 8
    weights = luminance * strong
    pivot = [round(float((xx * weights).sum() / weights.sum()), 4), round(float((yy * weights).sum() / weights.sum()), 4)]
    # A convex source envelope avoids spending fill rate on a full black rectangle.
    # It includes every decoded pixel brighter than3/255, with pixel-corner coverage.
    boundary = []
    for y, row in enumerate(deployed.max(axis=2) > 3):
        xs = np.flatnonzero(row)
        if xs.size:
            first, last = int(xs[0]), int(xs[-1]) + 1
            boundary.extend([(first, y), (last, y), (first, y + 1), (last, y + 1)])
    outline = hull(boundary)
    area = abs(sum(a[0] * b[1] - b[0] * a[1] for a, b in zip(outline, outline[1:] + outline[:1]))) * 0.5
    result = {
        "version": 1,
        "trial_only": True,
        "source": record(SOURCE),
        "generation": record(GENERATION),
        "references": [record(ROOT / "assets/source/style/approved-game-reference.jpg"), record(ROOT / "assets/source/atmosphere/reference-current.png")],
        "texture": dict(record(OUTPUT), size=list(image.size), blend="add"),
        "pivot": pivot,
        "source_envelope": outline,
        "envelope_fraction": round(area / (768 * 768), 5),
        "shafts": [{"world_width": 380.0, "opacity": 0.30}, {"world_width": 440.0, "opacity": 0.25}],
        "z_index": -9,
        "extra_dust_draws": 0,
        "review": "Technical trial only. Two world-anchored generated light textures behind actors and real canopy shade. Embedded dust is static. This provides direction and atmosphere, not reconstructed3D volume, face normals or occlusion. Original source retained; cleanup zeros only <=2RGB background, then uniform resize and WebP packing."
    }
    (ROOT / "assets/data/forest_atmosphere.json").write_text(json.dumps(result, ensure_ascii=False, indent=1) + "\n")
    print(f"Atmosphere trial packed: {image.size}, {len(outline)}-point envelope, {result['envelope_fraction']:.1%} of a full rectangle")


if __name__ == "__main__":
    main()
