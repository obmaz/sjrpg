#!/usr/bin/env python3
"""Pack measured cave production artwork without painting replacement geometry.

Keep the approved design and production PNGs in assets/source. Explicit native
ROIs, ground contacts and wall end contacts live in cave_art_measure.json. Runtime
metadata preserves both provenance hashes and the IsoSprite coordinate contract:
source/foot/baseline use packed atlas pixels before gvs/gvk correction.
"""
import hashlib
import json
import math
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
MEASURE = ROOT / 'tools/extract/cave_art_measure.json'
OUTPUT = ROOT / 'assets/art/cave'
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
    images = {name: Image.open(ROOT / path).convert('RGBA')
              for name, path in measure['sources'].items()}
    textures = {}
    for name, tile in measure['tiles'].items():
        image = images[tile['source']].crop(tile['roi'])
        if tile.get('opaque', False):
            image = image.convert('RGB').resize((512, 512), Image.Resampling.LANCZOS)
        else:
            image = image.convert('RGBa').resize((512, 512), Image.Resampling.LANCZOS).convert('RGBA')
        textures[name] = save(image, name)
    atlases = {name: Image.new('RGBA', config['size'])
               for name, config in measure['atlases'].items()}
    frames = {}
    for key, frame in measure['frames'].items():
        roi = frame['roi']
        crop = images[frame['source']].crop(roi)
        bounds = crop.getchannel('A').point(lambda value: 255 if value > 8 else 0).getbbox()
        if bounds is None:
            raise ValueError(f'Empty illustration: {key}')
        native = [roi[0] + bounds[0], roi[1] + bounds[1]]
        crop = crop.crop(bounds)
        atlas_name = frame['atlas']
        cell = measure['atlases'][atlas_name]['cell']
        packing = min(1.0, (cell[0] - PADDING * 2) / crop.width,
                      (cell[1] - PADDING * 2) / crop.height)
        size = (round(crop.width * packing), round(crop.height * packing))
        crop = crop.convert('RGBa').resize(size, Image.Resampling.LANCZOS).convert('RGBA')
        x = frame['cell'][0] * cell[0] + (cell[0] - size[0]) // 2
        y = frame['cell'][1] * cell[1] + cell[1] - PADDING - size[1]
        atlas = atlases[atlas_name]
        if x < 0 or y < 0 or x + size[0] > atlas.width or y + size[1] > atlas.height:
            raise ValueError(f'Illustration falls outside its atlas: {key}')
        atlas.paste(crop, (x, y))

        def packed(point):
            return [x + (point[0] - native[0]) * packing,
                    y + (point[1] - native[1]) * packing]

        foot = packed(frame['foot'])
        if not (x < foot[0] < x + size[0] and y < foot[1] < y + size[1]):
            raise ValueError(f'Ground contact falls outside the illustration: {key}')
        gvs, gvk = frame.get('gvs', 1), frame.get('gvk', 0)
        result = dict(sheet='res://assets/art/cave/' + atlas_name + '.webp',
                      source=[x, y, *size], foot=foot, height=foot[1] - y,
                      origin=native, packing=packing, gvs=gvs, gvk=gvk,
                      world_height=frame['world_height'], body=None)
        if 'relief_samples' in frame:
            samples = frame['relief_samples']
            for sample in samples:
                if sample['native_top'][0] != sample['native_base'][0]:
                    raise ValueError(f'Vertical relief must use the same native x: {key}')
            relief = sum(sample['native_base'][1] - sample['native_top'][1]
                         for sample in samples) / len(samples) * packing * gvs
            if relief <= 0:
                raise ValueError(f'Vertical relief must be positive: {key}')
            result['relief'] = relief
            result['target_relief'] = frame['target_relief']
            result['relief_samples'] = [dict(top=packed(sample['native_top']),
                                             base=packed(sample['native_base']))
                                        for sample in samples]
            # The diagonal wall run contributes to source height. Calibrate the
            # vertical rock face separately so a long ledge does not become tiny.
            result['world_height'] = frame['target_relief'] * result['height'] / relief
        if 'opening' in frame:
            result['opening'] = [packed(point) for point in frame['opening']]
        if 'baseline' in frame:
            result['baseline'] = [packed(point) for point in frame['baseline']]
            a, b = result['baseline']
            dx, dy = b[0] - a[0], b[1] - a[1]
            result['baseline_degrees'] = math.degrees(math.atan2(dy * gvs + dx * gvk, dx))
            result['target_axis_degrees'] = frame['target_axis_degrees']
        if 'review' in frame:
            result['review'] = frame['review']
        frames[key] = result
    for name, atlas in atlases.items():
        textures[name] = save(atlas, name)
    concept = ROOT / measure['concept']
    metadata = dict(concept=dict(path=measure['concept'], sha256=sha(concept)),
                    sources=[dict(path=path, sha256=sha(ROOT / path))
                             for path in measure['sources'].values()],
                    camera=measure['camera'], review=measure['review'],
                    textures=textures, frames=frames)
    target = ROOT / 'assets/data/cave_art.json'
    temporary = target.with_suffix('.tmp')
    temporary.write_text(json.dumps(metadata, indent=1) + '\n')
    temporary.replace(target)
    print('Cave art:', len(textures), 'textures;', len(frames), 'reviewed illustrations')


if __name__ == '__main__':
    main()
