"""Measure and pack four isolated VFX originals without neighboring artwork."""

import hashlib
import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
GENERATED_SOURCES = {
    'blade': 'exec-3c790bab-e127-45cb-b45f-a0353ef43eca.png',
    'cold': 'exec-461fec54-b5e2-4ec1-9044-51e5c811d221.png',
    'lightning': 'exec-b8486ed5-b1cb-44a4-91aa-9e9871aa86e9.png',
    'fire': 'exec-746f80f0-c67b-42f0-93d0-7915b7e4dbd0.png',
}
CELL_SIZE = 512
MAX_EFFECT_SIZE = 464


def main():
    atlas = Image.new('RGBA', (1024, 1024))
    frames = []
    for index, family in enumerate(GENERATED_SOURCES):
        source = ROOT / f'docs/art/cinematic-combat-{family}-original.png'
        with Image.open(source) as original:
            image = original.convert('RGBA')
        alpha = image.getchannel('A')
        edges = (
            (0, 0, image.width, 1),
            (0, image.height - 1, image.width, image.height),
            (0, 0, 1, image.height),
            (image.width - 1, 0, image.width, image.height),
        )
        # Reject a clipped effect. Sub-visible glow at an outer pixel is OK.
        if any(alpha.crop(edge).getextrema()[1] > 8 for edge in edges):
            raise ValueError(f'{family}: effect reaches the original edge')
        bounds = alpha.point(lambda value: 255 if value > 2 else 0).getbbox()
        if bounds is None:
            raise ValueError(f'{family}: missing effect')
        crop = image.crop(bounds)
        crop.thumbnail((MAX_EFFECT_SIZE, MAX_EFFECT_SIZE), Image.Resampling.LANCZOS)
        position = (
            index % 2 * CELL_SIZE + (CELL_SIZE - crop.width) // 2,
            index // 2 * CELL_SIZE + (CELL_SIZE - crop.height) // 2,
        )
        atlas.alpha_composite(crop, position)
        frames.append({
            'family': family,
            'generatedSource': GENERATED_SOURCES[family],
            'source': source.name,
            'sourceSha256': hashlib.sha256(source.read_bytes()).hexdigest(),
            'sourceRect': list(bounds),
            'packedRect': [*position, crop.width, crop.height],
        })
    output = ROOT / 'flutter_game/art/combat-illustrations.webp'
    atlas.save(output, lossless=True, method=6, exact=True)
    provenance = {
        'generator': 'image_gen',
        'packer': 'tools/prepare-cinematic-combat-vfx.py',
        'runtime': str(output.relative_to(ROOT)),
        'imageSize': [1024, 1024],
        'decodedRGBABytes': 4194304,
        'columns': 2,
        'rows': 2,
        'minimumTransparentPadding': (CELL_SIZE - MAX_EFFECT_SIZE) // 2,
        'camera': 'elevated quarter-view ground ellipses; upper-left light',
        'animation': 'live expansion, short afterimage and fade with existing particles and directional trails',
        'atlasSha256': hashlib.sha256(output.read_bytes()).hexdigest(),
        'frames': frames,
    }
    (ROOT / 'docs/art/cinematic-combat-vfx-provenance.json').write_text(
        json.dumps(provenance, indent=2) + '\n',
    )


if __name__ == '__main__':
    main()
