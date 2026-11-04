#!/usr/bin/env python3
"""Pack the five generated fallen-body illustrations, preserving their painted ground view."""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]


def main():
    image = Image.open(ROOT / 'assets/source/corpses.png').convert('RGBA')
    atlas = Image.new('RGBA', (1280, 256))
    for index in range(5):
        cell = image.crop((index * image.width // 5, 0,
                           (index + 1) * image.width // 5, image.height))
        box = cell.getchannel('A').point(lambda value: 255 if value > 32 else 0).getbbox()
        if box is None:
            raise ValueError(f'Empty corpse illustration: {index}')
        # Transparent gutters are not anatomy; keep consistent body length within each cell.
        body = cell.crop(box).convert('RGBa')
        body.thumbnail((232, 210), Image.Resampling.LANCZOS)
        atlas.paste(body.convert('RGBA'), (index * 256 + (256 - body.width) // 2,
                                        (256 - body.height) // 2))
    target = ROOT / 'assets/art/actors/corpses.webp'
    temporary = target.with_suffix('.tmp')
    atlas.save(temporary, 'WEBP', quality=94, alpha_quality=100, exact=True)
    temporary.replace(target)
    print('Corpse atlas:', atlas.size)


if __name__ == '__main__':
    main()
