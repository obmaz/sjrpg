"""Pack the measured quarter-view gate at the runtime ground anchor."""
from pathlib import Path
from PIL import Image

root = Path(__file__).resolve().parents[1]
source = Image.open(root / 'docs/art/quarter-view-warp-original.png').convert('RGBA')
bounds = source.getchannel('A').getbbox()
if bounds is None:
    raise ValueError('Warp gate artwork is empty')
gate = source.crop(bounds)
gate.thumbnail((280, 280), Image.Resampling.LANCZOS)
tile = Image.new('RGBA', (313, 313))
tile.alpha_composite(gate, (158 - gate.width // 2, 299 - gate.height))
atlas = Image.new('RGBA', (1252, 1252))
for frame in range(16):
    atlas.alpha_composite(tile, (frame % 4 * 313, frame // 4 * 313))
atlas.save(root / 'flutter_game/art/well-portal.webp', lossless=True, method=6, exact=True)
