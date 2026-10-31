"""Measure four separated generated grass squares and pack a runtime strip."""
import hashlib
import json
from pathlib import Path
import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[1]
source = ROOT / 'docs/art/meadow-variants-original.png'
image = Image.open(source).convert('RGBA')
alpha = np.asarray(image)[:, :, 3]
labels, _ = ndimage.label(alpha > 240)
areas = np.bincount(labels.ravel())
ids = np.argsort(areas[1:])[-4:] + 1
if min(areas[ids]) < 50000:
    raise ValueError('Expected four independent square materials')
centers = ndimage.center_of_mass(alpha > 240, labels, ids)
ordered = sorted(zip(ids, centers), key=lambda item: (item[1][0] > image.height / 2, item[1][1]))
atlas = Image.new('RGBA', (1024, 256))
rects = []
for index, (ident, _) in enumerate(ordered):
    ys, xs = np.nonzero(labels == ident)
    x0, y0, x1, y1 = int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1
    mask = alpha[y0:y1, x0:x1] > 240
    columns = np.flatnonzero(mask.sum(axis=0) > mask.sum(axis=0).max() * .95)
    rows = np.flatnonzero(mask.sum(axis=1) > mask.sum(axis=1).max() * .95)
    rect = (x0 + int(columns[0]) + 5, y0 + int(rows[0]) + 5,
            x0 + int(columns[-1]) - 4, y0 + int(rows[-1]) - 4)
    tile = image.crop(rect)
    if min(tile.size) < 400 or abs(tile.width - tile.height) > 25:
        raise ValueError(f'Unexpected material bounds: {rect}')
    if np.percentile(np.asarray(tile)[:, :, 3], 1) < 250:
        raise ValueError('The material interior must be opaque')
    atlas.alpha_composite(tile.resize((256, 256), Image.Resampling.LANCZOS), (index * 256, 0))
    rects.append(rect)
atlas.save(ROOT / 'flutter_game/art/field-grass-variants.webp', quality=94, method=6, exact=True)
record = {'generator': 'image_gen', 'processor': 'tools/prepare-meadow-variants.py',
          'source': str(source.relative_to(ROOT)), 'sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
          'reference': 'flutter_game/art/field-ground-meadow.webp',
          'sourceRects': rects, 'variants': ['grass', 'weeds', 'flowers', 'stones'],
          'runtime': 'flutter_game/art/field-grass-variants.webp', 'runtimeSize': [1024, 256],
          'runtimeRects': [[i * 256, 0, 256, 256] for i in range(4)]}
(ROOT / 'docs/art/meadow-variants-provenance.json').write_text(json.dumps(record, indent=4) + '\n')
print(json.dumps({'rects': rects, 'runtimeSize': atlas.size}))
