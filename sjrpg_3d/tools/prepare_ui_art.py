#!/usr/bin/env python3
"""Resize/pack canonical UI art without repainting it. Requires Pillow.
Generated originals live in assets/source; source reference buttons come from the Flutter art sheet.
"""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]


def save(image, name):
    target = ROOT / 'assets/ui/hud' / (name + '.webp')
    temporary = target.with_suffix('.tmp')
    image.save(temporary, 'WEBP', quality=93, alpha_quality=100, method=6, exact=True)
    temporary.replace(target)


def prepare_level_badge():
    # Reuse sjrpg's generated, number-free medallion; runtime text shows the real level.
    image = Image.open(ROOT / 'assets/source/ui/level-badge.png').convert('RGBA')
    if image.getchannel('A').getextrema() != (0, 255):
        raise ValueError('The level badge must retain its transparent background')
    image = image.crop(image.getchannel('A').getbbox())
    image.thumbnail((160, 160), Image.Resampling.LANCZOS)
    save(image, 'level-badge')


def main():
    prepare_level_badge()
    for name in ['portrait-mage', 'panel-leather']:
        image = Image.open(ROOT / 'assets/source' / (name + '.png'))
        save(image.resize((512, 512), Image.Resampling.LANCZOS), name)
    # Keep the two generated vials at their natural aspect ratio; align their bases in equal 256px cells.
    image = Image.open(ROOT / 'assets/source/ui/potions.png').convert('RGBA')
    sheet = Image.new('RGBA', (512, 256))
    for i in range(2):
        cell = image.crop((i * image.width // 2, 0, (i + 1) * image.width // 2, image.height))
        bounds = cell.getchannel('A').point(lambda a: 255 if a > 8 else 0).getbbox()
        vial = cell.crop(bounds)
        factor = min(210 / vial.width, 244 / vial.height)
        size = (round(vial.width * factor), round(vial.height * factor))
        vial = vial.convert('RGBa').resize(size, Image.Resampling.LANCZOS).convert('RGBA')
        sheet.paste(vial, (i * 256 + (256 - size[0]) // 2, 251 - size[1]))
    save(sheet, 'potions')


if __name__ == '__main__':
    main()
