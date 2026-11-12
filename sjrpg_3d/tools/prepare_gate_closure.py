#!/usr/bin/env python3
"""Crop, uniformly scale and pad generated iron pixels; no gate artwork is painted."""
import hashlib
import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'assets/source/town-gates/portcullis.png'
MEASURE = ROOT / 'tools/extract/gate_closure_measure.json'
GENERATION = ROOT / 'tools/extract/gate_closure_generation.json'
OUTPUT = ROOT / 'assets/sprites/village/portcullis.webp'


def record(path):
    return {'path': str(path.relative_to(ROOT)), 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()}


def main():
    measure = json.loads(MEASURE.read_text())
    source = Image.open(SOURCE).convert('RGBA')
    crop = measure['source_crop']
    tile = source.crop((crop[0], crop[1], crop[0] + crop[2], crop[1] + crop[3]))
    scale = 496.0 / max(tile.size)
    size = tuple(round(side * scale) for side in tile.size)
    offset = ((512 - size[0]) // 2, (512 - size[1]) // 2)
    atlas = Image.new('RGBA', (512, 512))
    atlas.alpha_composite(tile.resize(size, Image.Resampling.LANCZOS), offset)
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    atlas.save(OUTPUT, 'WEBP', quality=94, method=6)
    data = dict(version=1, source=record(SOURCE), generation=record(GENERATION), measure=record(MEASURE),
                references=[record(ROOT / p) for p in ['assets/source/remake/gate-a.png',
                            'assets/source/remake/gate-b-v2.png', 'assets/source/style/approved-game-reference.jpg']],
                texture=dict(**record(OUTPUT), size=[512, 512], offset=list(offset),
                             packing=[size[0] / crop[2], size[1] / crop[3]]),
                source_crop=crop, native_bounds=measure['native_bounds'],
                native_segments=measure['native_segments'], gates=measure['gates'])
    (ROOT / 'assets/data/gate_closure_art.json').write_text(json.dumps(data, indent=1) + '\n')
    print('Packed source-backed portcullis', size, 'into transparent512-square')


if __name__ == '__main__':
    main()
