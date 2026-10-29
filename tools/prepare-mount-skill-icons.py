"""Pack the four generated mount skill faces with measured transparent bounds."""
from pathlib import Path
from PIL import Image

root = Path(__file__).resolve().parents[1]
source = Image.open(root / 'docs/art/mount-skill-icons-original.png').convert('RGBA')
atlas = Image.new('RGBA', (512, 512))
for row in range(2):
    for column in range(2):
        x0, y0 = column * source.width // 2, row * source.height // 2
        x1, y1 = (column + 1) * source.width // 2, (row + 1) * source.height // 2
        crop = source.crop((x0, y0, x1, y1))
        bounds = crop.getchannel('A').point(lambda a: 255 if a > 96 else 0).getbbox()
        if bounds is None:
            raise ValueError('Missing mount skill artwork')
        crop = crop.crop(bounds)
        crop.thumbnail((244, 244), Image.Resampling.LANCZOS)
        atlas.alpha_composite(crop, (column * 256 + (256 - crop.width) // 2,
                                     row * 256 + (256 - crop.height) // 2))
atlas.save(root / 'flutter_game/art/mount-skill-icons.webp', lossless=True, method=6, exact=True)
