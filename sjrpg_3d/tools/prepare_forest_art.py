#!/usr/bin/env python3
"""Pack the reviewed forest ground and low flora without repainting their pixels.

Ground ROIs and native stem/ground contacts are measured in forest_art_measure.json.
The runtime manifest records reviewed source/render hashes and uses the same
source/foot/origin/packing coordinate contract as IsoSprite.
"""
import hashlib
import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
MEASURE = ROOT / 'tools/extract/forest_art_measure.json'
OUTPUT = ROOT / 'assets/sprites/forest'
CELL = 512
PADDING = 8


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def save(image, name):
    target = OUTPUT / (name + '.webp')
    temporary = target.with_suffix('.tmp')
    image.save(temporary, 'WEBP', quality=94, alpha_quality=100, exact=True, method=6)
    temporary.replace(target)
    return dict(path=str(target.relative_to(ROOT)), sha256=sha(target), size=list(image.size))


def main():
    measure = json.loads(MEASURE.read_text())
    OUTPUT.mkdir(parents=True, exist_ok=True)
    images = {key: Image.open(ROOT / path).convert('RGBA')
              for key, path in measure['sources'].items()}
    textures = {}
    for key, tile in measure['tiles'].items():
        # The measured inner square excludes any atlas gutter. Ground remains
        # opaque; its perspective comes from the actual game ground transform.
        tile_image = images[tile['source']].crop(tile['roi'])
        if tile_image.getchannel('A').getextrema()[0] < 250:
            raise ValueError(f'Ground material must be opaque throughout its measured square: {key}')
        tile_image = tile_image.convert('RGB')
        textures[key] = save(tile_image.resize((CELL, CELL), Image.Resampling.LANCZOS), key)
    atlas = Image.new('RGBA', (CELL * 2, CELL * 2))
    frames = {}
    for key, frame in measure['frames'].items():
        roi = frame['roi']
        crop = images[frame['source']].crop(roi)
        minimum, maximum = crop.getchannel('A').getextrema()
        if minimum != 0 or maximum < 250:
            raise ValueError(f'Flora must retain transparent surroundings and opaque leaves: {key}')
        bounds = crop.getchannel('A').point(lambda value: 255 if value > 8 else 0).getbbox()
        if bounds is None:
            raise ValueError(f'Empty flora illustration: {key}')
        native = [roi[0] + bounds[0], roi[1] + bounds[1]]
        crop = crop.crop(bounds)
        packing = min(1.0, (CELL - PADDING * 2) / max(crop.size))
        size = (round(crop.width * packing), round(crop.height * packing))
        crop = crop.convert('RGBa').resize(size, Image.Resampling.LANCZOS).convert('RGBA')
        x = frame['cell'][0] * CELL + (CELL - size[0]) // 2
        y = frame['cell'][1] * CELL + CELL - PADDING - size[1]
        if x < 0 or y < 0 or x + size[0] > atlas.width or y + size[1] > atlas.height:
            raise ValueError(f'Flora illustration falls outside the atlas: {key}')
        atlas.paste(crop, (x, y))
        foot = [x + (frame['foot'][0] - native[0]) * packing,
                y + (frame['foot'][1] - native[1]) * packing]
        if not (x < foot[0] < x + size[0] and y < foot[1] < y + size[1]):
            raise ValueError(f'Flora ground contact falls outside the illustration: {key}')
        result = dict(sheet='res://assets/sprites/forest/flora.webp',
                      source=[x, y, *size], foot=foot, height=foot[1] - y,
                      origin=native, packing=packing, gvs=1, gvk=0,
                      world_height=frame['world_height'], body=None)
        if 'review' in frame:
            result['review'] = frame['review']
        frames[key] = result
    textures['flora'] = save(atlas, 'flora')
    metadata = dict(sources=[dict(path=path, sha256=sha(ROOT / path))
                             for path in measure['sources'].values()],
                    camera=measure['camera'], review=measure['review'],
                    textures=textures, frames=frames)
    if 'references' in measure:
        metadata['references'] = [dict(**reference, sha256=sha(ROOT / reference['path']))
                                  for reference in measure['references']]
    target = ROOT / 'assets/data/forest_art.json'
    temporary = target.with_suffix('.tmp')
    temporary.write_text(json.dumps(metadata, indent=1) + '\n')
    temporary.replace(target)
    print('Forest art:', len(textures), 'textures;', len(frames), 'reviewed flora illustrations')


if __name__ == '__main__':
    main()
