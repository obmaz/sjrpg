#!/usr/bin/env python3
"""Mechanically register eight generated villagers at measured feet; no new pixels are painted."""
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'assets/source/npcs/identities.png'
GENERATION = ROOT / 'tools/extract/npc_generation.json'
MEASURE = ROOT / 'tools/extract/npc_measure.json'
CELL = (224, 320)
PEOPLE = [
    ('merchant', '상인'), ('smith', '대장장이'), ('stable', '탈것 상인'), ('elder', '촌장'),
    ('mira', '보급원 미라'), ('elin', '수녀 엘린'), ('noah', '약초사 노아'), ('rowen', '조사관 로웬'),
]


def record(path):
    return dict(path=str(path.relative_to(ROOT)), sha256=hashlib.sha256(path.read_bytes()).hexdigest())


def main():
    measure = json.loads(MEASURE.read_text())
    image = Image.open(SOURCE).convert('RGBA')
    atlas = Image.new('RGBA', (CELL[0] * 4, CELL[1] * 2))
    entries, labels = {}, {}
    for index, (key, label) in enumerate(PEOPLE):
        item = measure['people'][key]
        crop = image.crop(tuple(item['roi']))
        foot = np.array(item['foot']) - np.array(item['roi'][:2])
        height = float(item['visible_height'])
        factor = 280.0 / height
        resized = crop.convert('RGBa').resize((round(crop.width * factor), round(crop.height * factor)), Image.Resampling.LANCZOS).convert('RGBA')
        contact = (CELL[0] / 2, 302.0)
        offset = (round(contact[0] - foot[0] * factor), round(contact[1] - foot[1] * factor))
        tile = Image.new('RGBA', CELL)
        tile.paste(resized, offset)
        bounds = tile.getbbox()
        if bounds is None or bounds[0] < 3 or bounds[1] < 3 or bounds[2] > CELL[0] - 3 or bounds[3] > CELL[1] - 3:
            raise ValueError(f'NPC is clipped or lacks transparent safe padding: {key}: {bounds}')
        x, y = index % 4 * CELL[0], index // 4 * CELL[1]
        atlas.paste(tile, (x, y))
        entries[key] = dict(source=[x, y, *CELL], foot=list(contact), ref_height=280.0,
                            visible_bounds=list(bounds), body_height=112.0,
                            pixels_sha256=hashlib.sha256(tile.tobytes()).hexdigest(), source_roi=item['roi'])
        labels[label] = key
    output = ROOT / 'assets/art/actors/npcs.webp'
    temporary = output.with_suffix('.tmp')
    atlas.save(temporary, 'WEBP', quality=94, alpha_quality=100, method=6, exact=True)
    temporary.replace(output)
    manifest = dict(version=1, source=record(SOURCE), generation=record(GENERATION), measure=record(MEASURE),
                    references=[record(ROOT / path) for path in measure['references']],
                    atlas=dict(**record(output), size=list(atlas.size), cell=list(CELL), blend='alpha'),
                    labels=labels, people=entries)
    (ROOT / 'assets/data/npc_art.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=1) + '\n')
    print('Registered eight distinct human NPC identities at common112-world-pixel visible human height.')


if __name__ == '__main__':
    main()
