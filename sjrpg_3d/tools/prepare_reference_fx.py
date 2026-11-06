#!/usr/bin/env python3
"""Mechanically register generated skill keyframes; no replacement effects are painted."""
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
MEASURE = ROOT / 'tools/extract/reference_fx_measure.json'
GENERATION = ROOT / 'tools/extract/reference_fx_generation.json'
CELL = 384


def record(path):
    return {'path': str(path.relative_to(ROOT)), 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()}


def pack_frames(item, default_source):
    source = Image.open(ROOT / item.get('source', default_source)).convert('RGB')
    pivot = item['packed_pivot']
    scale = item.get('packing_scale', 1.0)
    stretch = item.get('vertical_projection_scale', 1.0)
    strip = Image.new('RGB', (CELL * 4, CELL))
    energy, frame_bounds = [], []
    for column, frame in enumerate(item['source_frames']):
        x, y, w, h = frame['roi']
        contact = frame['contact']
        tile = source.crop((x, y, x + w, y + h))
        tile = tile.resize((round(w * scale), round(h * stretch * scale)), Image.Resampling.LANCZOS)
        offset = (round(pivot[0] - (contact[0] - x) * scale), round(pivot[1] - (contact[1] - y) * stretch * scale))
        packed = Image.new('RGB', (CELL, CELL))
        packed.paste(tile, offset)
        array = np.asarray(packed)
        ys, xs = np.where(array.max(axis=2) > 32)
        bounds = [int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1]
        if min(bounds[0], bounds[1], CELL - bounds[2], CELL - bounds[3]) < 8:
            raise ValueError(f'Generated ink crosses safe black padding: {column}: {bounds}')
        frame_bounds.append(bounds)
        energy.append(round(float((array @ np.array([.2126, .7152, .0722])).sum()), 2))
        strip.paste(packed, (column * CELL, 0))
    if energy[3] >= energy[1]:
        raise ValueError('Tail is not dimmer than peak')
    return strip, dict(pivot=pivot, paint_width=frame_bounds[1][2] - frame_bounds[1][0],
                      source_frames=item['source_frames'], source=item.get('source', default_source),
                      packing_scale=scale, vertical_projection_scale=stretch,
                      frame_bounds=frame_bounds, frame_energy=energy)


def main():
    measure = json.loads(MEASURE.read_text())
    source_path = ROOT / measure['source']
    atlas = Image.new('RGB', (CELL * 4, CELL * 6))
    effects = {}
    for row, (key, item) in enumerate(measure['effects'].items()):
        # The legacy row is retained so the other five lossy WebP rows are byte-identical.
        base_strip, base_definition = pack_frames(item.get('legacy_base', item), measure['source'])
        atlas.paste(base_strip, (0, row * CELL))
        effects[key] = dict(row=row, **base_definition)
        if 'override_path' in item:
            strip, definition = pack_frames(item, measure['source'])
            target = ROOT / item['override_path']
            strip.save(target, 'WEBP', quality=94, method=6)
            effects[key] = dict(row=row, **definition, override=dict(**record(target), cell=CELL,
                                row=0, columns=4, size=list(strip.size), blend='add'),
                                legacy_base_row_retained=True)
    output = ROOT / 'assets/art/effects/reference-skills.webp'
    output.parent.mkdir(parents=True, exist_ok=True)
    temp = output.with_suffix('.tmp')
    atlas.save(temp, 'WEBP', quality=94, method=6)
    if output.exists() and output.read_bytes() != temp.read_bytes():
        raise ValueError('Base atlas changed while adding an independent frost override')
    temp.replace(output)
    sources = [ROOT / 'assets/source/reference-fx/family-concept.png', source_path]
    sources += [ROOT / item['source'] for item in measure['effects'].values() if 'source' in item]
    data = dict(version=1,
                sources=[record(path) for path in dict.fromkeys(sources)],
                reference=record(ROOT / 'assets/source/style/approved-game-reference.jpg'),
                family_reference=record(ROOT / 'assets/source/impact-atlas.png'),
                generation=record(GENERATION), measure=record(MEASURE),
                atlas=dict(**record(output), size=list(atlas.size), cell=CELL, columns=4, rows=6,
                           blend='add', phases=['onset', 'peak', 'fragments', 'tail']),
                effects=effects)
    (ROOT / 'assets/data/reference_fx.json').write_text(json.dumps(data, ensure_ascii=False, indent=1) + '\n')
    print('Registered reference skill effects: 6 motifs, 24 phases, black ADD atlas', atlas.size)


if __name__ == '__main__':
    main()
