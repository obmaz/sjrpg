#!/usr/bin/env python3
"""Mechanically pack generated, simplified mobile menu art; never paint replacement icons."""
import hashlib
import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
MEASURE = ROOT / 'tools/extract/mobile_menu_measure.json'
GENERATION = ROOT / 'tools/extract/mobile_menu_generation.json'


def record(path):
    path = Path(path)
    return {'path': str(path.relative_to(ROOT)), 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()}


def main():
    measure = json.loads(MEASURE.read_text())
    source_path = ROOT / measure['source']
    source = Image.open(source_path).convert('RGBA')
    if list(source.size) != measure['source_size'] or source.getchannel('A').getextrema() != (0, 255):
        raise ValueError('The reviewed source dimensions and real alpha must be retained')
    cell = int(measure['cell'])
    sheet = Image.new('RGBA', (cell * 4, cell))
    frames = {}
    for column, (key, item) in enumerate(measure['icons'].items()):
        x, y, width, height = item['source_roi']
        if x < 0 or y < 0 or x + width > source.width or y + height > source.height:
            raise ValueError('Measured source crop leaves the actual source: ' + key)
        region = source.crop((x, y, x + width, y + height))
        tile = region.convert('RGBa').resize((cell, cell), Image.Resampling.LANCZOS).convert('RGBA')
        bounds = tile.getchannel('A').point(lambda a: 255 if a > 8 else 0).getbbox()
        if not bounds or min(bounds[0], bounds[1], cell - bounds[2], cell - bounds[3]) < 3:
            raise ValueError('Icon has no transparent safe padding: ' + key)
        half = max(cell / 2 - bounds[0], cell / 2 - bounds[1], bounds[2] - cell / 2, bounds[3] - cell / 2)
        sheet.paste(tile, (column * cell, 0))
        frames[key] = {'source': [column * cell, 0, cell, cell], 'paint_half': half,
                       'source_roi': item['source_roi'], 'paint_bounds': list(bounds)}
    output = ROOT / 'assets/ui/hud/mobile-menu.webp'
    output.parent.mkdir(parents=True, exist_ok=True)
    temporary = output.with_suffix('.tmp')
    sheet.save(temporary, 'WEBP', quality=94, alpha_quality=100, method=6, exact=True)
    temporary.replace(output)
    data = {'version': 1, 'sources': [record(source_path)], 'generation': record(GENERATION),
            'measure': record(MEASURE),
            'atlas': {**record(output), 'size': list(sheet.size), 'cell': cell, 'columns': 4,
                      'rows': 1, 'blend': 'alpha', 'frames': frames},
            'review': 'Simplified front-facing mobile menu family; actual phone legibility must be checked at48/64px and native HUD size. Generation is not user approval.'}
    (ROOT / 'assets/data/mobile_menu.json').write_text(json.dumps(data, ensure_ascii=False, indent=1) + '\n')
    print('Packed simplified mobile menu:', sheet.size, list(frames))


if __name__ == '__main__':
    main()
