#!/usr/bin/env python3
"""Pack measured transparent selection trim; illustrations stay in the canonical PNG.
Only threshold-alpha cleanup, crop and placement are used. No interface art is painted.
"""
import hashlib
import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
source_path = ROOT / 'assets/source/ui/selection-trim.png'
source = Image.open(source_path).convert('RGBA')
sheet = Image.new('RGBA', (1024, 768))
rects = {}
measurements = {}
for key, index, target in [('primary', 0, (8, 8)), ('continue', 1, (8, 176)), ('crest', 2, (8, 350)), ('warrior', 3, (540, 350))]:
    x0, y0 = (index % 2) * source.width // 2, (index // 2) * source.height // 2
    x1, y1 = ((index % 2) + 1) * source.width // 2, ((index // 2) + 1) * source.height // 2
    cell = source.crop((x0, y0, x1, y1))
    alpha = cell.getchannel('A')
    bounds = alpha.point(lambda a: 255 if a > 8 else 0).getbbox()
    if bounds is None:
        raise ValueError(f'{key} is empty')
    cell.putalpha(alpha.point(lambda a: 0 if a <= 2 else a))
    tile = cell.crop(bounds)
    sheet.alpha_composite(tile, target)
    rects[key] = [*target, tile.width, tile.height]
    measurements[key] = [bounds[0] + x0, bounds[1] + y0, bounds[2] + x0, bounds[3] + y0]
for alias, original in [('back', 'continue'), ('tab_active', 'primary'), ('tab_inactive', 'continue')]:
    rects[alias] = rects[original]
target = ROOT / 'assets/ui/selection/selection-trim.webp'
temporary = target.with_suffix('.tmp')
sheet.save(temporary, 'WEBP', quality=94, alpha_quality=100, method=6, exact=True)
temporary.replace(target)
manifest = dict(texture='res://assets/ui/selection/selection-trim.webp', regions=rects, nine_slice=22,
                source='assets/source/ui/selection-trim.png', source_rects=measurements,
                source_sha256=hashlib.sha256(source_path.read_bytes()).hexdigest(),
                render_sha256=hashlib.sha256(target.read_bytes()).hexdigest())
(ROOT / 'assets/data/selection_ui.json').write_text(json.dumps(manifest, indent=1) + '\n')
print('selection trim packed:', rects)
