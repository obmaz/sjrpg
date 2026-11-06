#!/usr/bin/env python3
"""Pack the reviewed true-isometric tree illustrations without repainting them.

The measured root contacts in tree_art_measure.json anchor every original tree ID.
The PNG stays in assets/source; tree_art.json records the deployed pixels and their
source/render hashes so the organic-art review cannot silently go stale.
"""
import hashlib
import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
MEASURE = ROOT / 'tools/extract/tree_art_measure.json'
CELL = 768
PADDING = 8


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    measure = json.loads(MEASURE.read_text())
    source = ROOT / measure['source']
    image = Image.open(source).convert('RGBA')
    minimum, maximum = image.getchannel('A').getextrema()
    if minimum != 0 or maximum < 250:
        raise ValueError('The reviewed tree sheet must retain its transparent background')
    atlas = Image.new('RGBA', (CELL * 2, CELL * 2))
    frames = {}
    for index, frame in enumerate(measure['frames']):
        roi = frame['roi']
        if not (0 <= roi[0] < roi[2] <= image.width and 0 <= roi[1] < roi[3] <= image.height):
            raise ValueError(f'Tree measurement falls outside the current source: {frame["id"]}')
        crop = image.crop(roi)
        alpha = crop.getchannel('A')
        bounds = alpha.point(lambda value: 255 if value > 8 else 0).getbbox()
        if bounds is None:
            raise ValueError(f'Empty illustration: {frame["id"]}')
        native = [roi[0] + bounds[0], roi[1] + bounds[1]]
        crop = crop.crop(bounds)
        # Premultiplied resampling avoids a dark fringe around fine leaves.
        packing = min(1.0, (CELL - PADDING * 2) / max(crop.size))
        size = (round(crop.width * packing), round(crop.height * packing))
        crop = crop.convert('RGBa').resize(size, Image.Resampling.LANCZOS).convert('RGBA')
        x = (index % 2) * CELL + (CELL - size[0]) // 2
        y = (index // 2) * CELL + CELL - PADDING - size[1]
        atlas.paste(crop, (x, y))
        foot = [x + (frame['foot'][0] - native[0]) * packing,
                y + (frame['foot'][1] - native[1]) * packing]
        if not (x < foot[0] < x + size[0] and y < foot[1] <= y + size[1]):
            raise ValueError(f'Root contact falls outside its illustration: {frame["id"]}')
        frames[frame['id']] = dict(source=[x, y, *size], foot=foot,
                                   height=foot[1] - y, origin=native, packing=packing)
    target = ROOT / 'assets/art/village/trees.webp'
    temporary = target.with_suffix('.tmp')
    atlas.save(temporary, 'WEBP', quality=94, alpha_quality=100, exact=True, method=6)
    temporary.replace(target)
    metadata = dict(source=measure['source'], source_sha256=sha(source),
                    render='assets/art/village/trees.webp', render_sha256=sha(target),
                    camera=measure['camera'], review=measure['review'],
                    frames=frames, variants=measure['variants'])
    if 'references' in measure:
        metadata['references'] = [dict(**reference, sha256=sha(ROOT / reference['path']))
                                  for reference in measure['references']]
    (ROOT / 'assets/data/tree_art.json').write_text(json.dumps(metadata, indent=1) + '\n')
    print('Tree atlas:', atlas.size, 'frames:', len(frames))


if __name__ == '__main__':
    main()
