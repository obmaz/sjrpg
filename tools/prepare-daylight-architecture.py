"""Measure independent alpha silhouettes and pack daylight architecture assets.

Requires Pillow, NumPy and SciPy. Does not modify either generated original.
"""
import hashlib
import json
from pathlib import Path
import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / 'flutter_game/art'
DOC = ROOT / 'docs/art/daylight-architecture'
source = DOC / 'buildings-original.png'
im = Image.open(source).convert('RGBA')
rgba = np.asarray(im).copy()
labels, _ = ndimage.label(rgba[:, :, 3] > 20)
areas = np.bincount(labels.ravel())
ids = np.argsort(areas[1:])[-4:] + 1
if min(areas[ids]) < 150000:
    raise ValueError('Expected four complete independent buildings')
centers = ndimage.center_of_mass(rgba[:, :, 3] > 20, labels, ids)
ordered = sorted(zip(ids, centers), key=lambda item: (item[1][0] > im.height / 2, item[1][1]))
keys = ['forest-quest-chapel', 'forest-quest-cottage', 'village-cottage', 'blacksmith-forge']
frames = {}
for (ident, _), key in zip(ordered, keys):
    ys, xs = np.nonzero(labels == ident)
    bounds = (max(0, int(xs.min()) - 3), max(0, int(ys.min()) - 3),
              min(im.width, int(xs.max()) + 4), min(im.height, int(ys.max()) + 4))
    pixels = rgba.copy()
    own = ndimage.binary_dilation(labels == ident, iterations=2)
    pixels[~own, 3] = 0
    # Remove saturated red matte contamination only at the exterior alpha fringe.
    r, g, b = [pixels[:, :, i].astype(float) for i in range(3)]
    exterior = ndimage.binary_dilation(pixels[:, :, 3] <= 20, iterations=3)
    matte = (r > 130) & (r > g * 1.7) & (r > b * 1.7) & exterior
    pixels[matte, 3] = 0
    cropped = Image.fromarray(pixels).crop(bounds)
    target = ART / f'{key}.webp'
    cropped.save(target, quality=95, method=6, exact=True)
    frames[key] = {'sourceRect': bounds, 'size': cropped.size,
                   'sha256': hashlib.sha256(target.read_bytes()).hexdigest()}
texture = Image.open(DOC / 'paving-original.png').convert('RGB')
texture.resize((768, 768), Image.Resampling.LANCZOS).save(ART / 'field-paving.webp', quality=95, method=6)
record = {'generator': 'image_gen', 'processor': 'tools/prepare-daylight-architecture.py',
          'buildingSource': str(source.relative_to(ROOT)), 'sourceSha256': hashlib.sha256(source.read_bytes()).hexdigest(),
          'frames': frames, 'paving': {'source': 'docs/art/daylight-architecture/paving-original.png',
          'runtime': 'flutter_game/art/field-paving.webp', 'size': [768, 768], 'worldTileSize': 384}}
(DOC / 'provenance.json').write_text(json.dumps(record, indent=4) + '\n')
print(json.dumps(frames))
