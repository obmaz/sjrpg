"""Keep the original generated roll icon and prepare its compact runtime image."""
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
original = root / 'docs/art/dodge-roll-original.png'
if source.resolve() != original.resolve():
    shutil.copyfile(source, original)
with Image.open(source) as image:
    output = image.convert('RGBa').resize((256, 256), Image.Resampling.LANCZOS).convert('RGBA')
runtime = root / 'flutter_game/art/dodge-icon.png'
output.save(runtime, optimize=True)
(root / 'docs/art/dodge-roll-provenance.json').write_text(json.dumps({
    'generator': 'image_gen', 'packer': 'tools/prepare-dodge-roll.py',
    'original': str(original.relative_to(root)),
    'originalSha256': hashlib.sha256(original.read_bytes()).hexdigest(),
    'runtime': str(runtime.relative_to(root)),
    'runtimeSha256': hashlib.sha256(runtime.read_bytes()).hexdigest(),
    'size': [256, 256], 'decodedRGBABytes': 262144,
}, indent=2) + '\n')
