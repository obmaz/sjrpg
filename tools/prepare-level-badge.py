"""Crop the generated transparent HUD badge to its measured alpha bounds."""
import hashlib
import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
source = ROOT / 'docs/art/level-badge-original.png'
image = Image.open(source).convert('RGBA')
if image.getchannel('A').getextrema() != (0, 255):
    raise ValueError('The badge must retain its transparent background')
bounds = image.getchannel('A').getbbox()
image = image.crop(bounds)
image.thumbnail((160, 160), Image.Resampling.LANCZOS)
image.save(ROOT / 'flutter_game/art/level-badge.webp', quality=94, exact=True)
(ROOT / 'docs/art/level-badge-provenance.json').write_text(json.dumps({
    'generator': 'image_gen',
    'processor': 'tools/prepare-level-badge.py',
    'source': 'docs/art/level-badge-original.png',
    'sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
    'alphaBounds': bounds,
    'runtime': 'flutter_game/art/level-badge.webp',
    'runtimeSize': image.size,
    'purpose': '26px circular HUD level badge, runtime number centered over empty enamel',
}, indent=4) + '\n')
