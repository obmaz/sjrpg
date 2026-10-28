"""Isolate generated VFX frames and add transparent gutters for game sampling."""

import argparse
import hashlib
import json
import math
import shutil
from pathlib import Path

from PIL import Image, ImageChops


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, required=True)
    source = parser.parse_args().source
    root = Path(__file__).resolve().parents[1]
    with Image.open(source) as raw:
        image = raw.convert('RGBA')
    atlas = Image.new('RGBA', (1024, 1024))
    frames = []
    for row in range(4):
        for column in range(4):
            bounds = (
                round(column * image.width / 4),
                round(row * image.height / 4),
                round((column + 1) * image.width / 4),
                round((row + 1) * image.height / 4),
            )
            tile = image.crop(bounds)
            width, height = tile.size
            # Fade along an ellipse rather than a square cut. The ellipse stays
            # inside the slicing boundary, excluding neighbouring generated glow.
            mask = Image.new('L', tile.size)
            mask.putdata([
                round(255 * max(0, min(1, (1 - math.hypot(
                    (x + .5 - width / 2) / (width * .44),
                    (y + .5 - height / 2) / (height * .44),
                )) / .18)))
                for y in range(height) for x in range(width)
            ])
            tile.putalpha(ImageChops.multiply(tile.getchannel('A'), mask))
            tile = tile.convert('RGBa').resize(
                (192, 192), Image.Resampling.LANCZOS,
            ).convert('RGBA')
            atlas.alpha_composite(tile, (column * 256 + 32, row * 256 + 32))
            frames.append({
                'index': row * 4 + column,
                'sourceRect': bounds,
                'outputRect': [column * 256, row * 256, 256, 256],
            })
    output = root / 'flutter_game/art/combat-illustrations.webp'
    atlas.save(output, format='WEBP', lossless=True, method=6, exact=True)
    original = root / 'docs/art/combat-illustrations-original.png'
    if source.resolve() != original.resolve():
        shutil.copyfile(source, original)
    provenance = {
        'version': 1,
        'generator': 'image_gen',
        'packer': 'tools/prepare-combat-illustrations.py',
        'generatedSource': source.name,
        'original': 'docs/art/combat-illustrations-original.png',
        'originalSha256': hashlib.sha256(source.read_bytes()).hexdigest(),
        'runtime': 'flutter_game/art/combat-illustrations.webp',
        'runtimeSha256': hashlib.sha256(output.read_bytes()).hexdigest(),
        'imageSize': [1024, 1024],
        'decodedRGBABytes': 4194304,
        'columns': 4,
        'rows': 4,
        'transparentPadding': 32,
        'method': (
            'Uniform cell slicing; elliptical edge-alpha isolation; '
            'premultiplied-alpha downsample to192px;32px transparent gutters; '
            'lossless WebP. No repainting.'
        ),
        'animationRows': ['fire-crescent4', 'ice-impact4', 'lightning-impact4'],
        'symbols': ['armored-running-boots', 'silver-crescent',
                    'gold-contact-star', 'teleport-flare'],
        'frames': frames,
    }
    (root / 'docs/art/combat-illustrations-provenance.json').write_text(
        json.dumps(provenance, indent=4) + '\n'
    )
    print(f'Prepared16 isolated sprites: {output.stat().st_size} bytes,4MiB RGBA')


if __name__ == '__main__':
    main()
