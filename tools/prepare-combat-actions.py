"""Pack two generated action medallions into equal, isolated runtime cells."""
import argparse
import hashlib
import json
import shutil
from pathlib import Path
from PIL import Image

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--source', required=True, type=Path)
source = parser.parse_args().source
root = Path(__file__).resolve().parents[1]
with Image.open(source) as raw:
    image = raw.convert('RGBA')
atlas = Image.new('RGBA', (512, 256))
for column in range(2):
    cell = image.crop((round(column * image.width / 2), 0,
                       round((column + 1) * image.width / 2), image.height))
    cell = cell.convert('RGBa').resize((256, 256), Image.Resampling.LANCZOS).convert('RGBA')
    atlas.alpha_composite(cell, (column * 256, 0))
output = root / 'flutter_game/art/combat-actions.webp'
atlas.save(output, format='WEBP', lossless=True, method=6, exact=True)
original = root / 'docs/art/combat-actions-original.png'
if source.resolve() != original.resolve():
    shutil.copyfile(source, original)
provenance = {
    'generator': 'image_gen', 'packer': 'tools/prepare-combat-actions.py',
    'original': str(original.relative_to(root)),
    'originalSha256': hashlib.sha256(original.read_bytes()).hexdigest(),
    'runtime': str(output.relative_to(root)),
    'runtimeSha256': hashlib.sha256(output.read_bytes()).hexdigest(),
    'size': [512, 256], 'decodedRGBABytes': 524288,
    'columns': 2, 'rows': 1, 'icons': ['armoredSprintBoot', 'armoredUnarmedFist'],
}
(root / 'docs/art/combat-actions-provenance.json').write_text(json.dumps(provenance, indent=2) + '\n')
