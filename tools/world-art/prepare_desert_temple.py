"""Fit four original generated temple props into isolated, grounded atlas cells."""
import argparse
import hashlib
import json
import shutil
from pathlib import Path
from PIL import Image

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--source', required=True, type=Path)
source = parser.parse_args().source
root = Path(__file__).resolve().parents[2]
with Image.open(source) as raw:
    original = raw.convert('RGBA')
atlas = Image.new('RGBA', (1024, 1024))
frames = []
for i in range(4):
    box = (round((i % 2) * original.width / 2), round((i // 2) * original.height / 2),
           round((i % 2 + 1) * original.width / 2), round((i // 2 + 1) * original.height / 2))
    tile = original.crop(box)
    bounds = tile.getchannel('A').point(lambda a: 255 if a > 12 else 0).getbbox()
    if bounds is None:
        raise ValueError('Generated prop cell is empty')
    tile = tile.crop(bounds)
    scale = min(448 / tile.width, 448 / tile.height)
    size = (round(tile.width * scale), round(tile.height * scale))
    tile = tile.convert('RGBa').resize(size, Image.Resampling.LANCZOS).convert('RGBA')
    at = (i % 2 * 512 + (512 - size[0]) // 2, i // 2 * 512 + 480 - size[1])
    atlas.alpha_composite(tile, at)
    frames.append({'index': i, 'sourceCell': box, 'contentCrop': bounds,
                   'outputContent': [*at, *size], 'footY': 480})
output = root / 'flutter_game/art/desert-temple.webp'
atlas.save(output, format='WEBP', lossless=True, method=6, exact=True)
archive = root / 'docs/art/desert-temple-original.png'
if source.resolve() != archive.resolve():
    shutil.copyfile(source, archive)
metadata = {'generator': 'image_gen', 'packer': 'tools/world-art/prepare_desert_temple.py',
            'original': str(archive.relative_to(root)),
            'originalSha256': hashlib.sha256(archive.read_bytes()).hexdigest(),
            'runtime': str(output.relative_to(root)),
            'runtimeSha256': hashlib.sha256(output.read_bytes()).hexdigest(),
            'size': [1024, 1024], 'decodedRGBABytes': 4194304,
            'columns': 2, 'rows': 2, 'transparentPadding': 32, 'frames': frames}
(root / 'docs/art/desert-temple-provenance.json').write_text(json.dumps(metadata, indent=2) + '\n')
