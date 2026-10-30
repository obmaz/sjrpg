"""Pack generated buttons from their measured alpha bounds into square cells."""
import json
from pathlib import Path
from PIL import Image

root = Path(__file__).resolve().parents[1]
source = Image.open(root / 'docs/art/reference-battle-buttons-original.png').convert('RGBA')
atlas = Image.new('RGBA', (1024, 256))
rects = []
for index in range(4):
    x0 = index * source.width // 4
    x1 = (index + 1) * source.width // 4
    cell = source.crop((x0, 0, x1, source.height))
    bounds = cell.getchannel('A').point(lambda a: 255 if a > 96 else 0).getbbox()
    if bounds is None:
        raise ValueError(f'Button {index} has no visible pixels')
    rects.append([bounds[0] + x0, bounds[1], bounds[2] + x0, bounds[3]])
    image = cell.crop(bounds)
    image.thumbnail((252, 252), Image.Resampling.LANCZOS)
    atlas.alpha_composite(image, (index * 256 + (256 - image.width) // 2,
                                  (256 - image.height) // 2))
atlas.save(root / 'flutter_game/art/reference-battle-buttons.webp', lossless=True, method=6, exact=True)
(root / 'docs/art/reference-battle-buttons-provenance.json').write_text(json.dumps({
    'source': 'reference-battle-buttons-original.png',
    'method': 'Generated dark fantasy buttons; alpha bounds measured independently and centered in square cells.',
    'buttons': ['sword', 'settings', 'bag', 'journal'],
    'sourceRects': rects,
}, ensure_ascii=False, indent=2) + '\n')
