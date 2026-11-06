#!/usr/bin/env python3
"""Pack the generated river/shore materials without repainting source pixels."""
import hashlib
import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'assets/source/remake/river-materials.png'
OUTPUT = ROOT / 'assets/art/village'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    image = Image.open(SOURCE).convert('RGB')
    width, height = image.size
    if width != height * 2:
        raise ValueError('Expected exactly two square source material panels')
    textures = {}
    for index, name in enumerate(['water', 'rock']):
        roi = [index * height + 1, 1, (index + 1) * height - 1, height - 1]
        tile = image.crop(roi).resize((512, 512), Image.Resampling.LANCZOS)
        target = OUTPUT / (name + '.webp')
        temporary = target.with_suffix('.tmp')
        tile.save(temporary, 'WEBP', quality=94, method=6)
        temporary.replace(target)
        textures[name] = dict(path=str(target.relative_to(ROOT)), sha256=sha(target),
                              source_roi=roi, size=[512, 512])
    # Reuse the newly generated forest-earth material for the shore's soft edge.
    earth = ROOT / 'assets/art/forest/earth.webp'
    dirt = OUTPUT / 'dirt.webp'
    dirt.write_bytes(earth.read_bytes())
    textures['dirt'] = dict(path=str(dirt.relative_to(ROOT)), sha256=sha(dirt),
                            reused_from=str(earth.relative_to(ROOT)))
    metadata = dict(source=str(SOURCE.relative_to(ROOT)), source_sha256=sha(SOURCE),
                    camera='top-down material; runtime Iso ground transform',
                    no_baked_cast_shadows=True, textures=textures)
    (ROOT / 'assets/data/river_art.json').write_text(json.dumps(metadata, indent=1) + '\n')
    print('River materials packed:', len(textures))


if __name__ == '__main__':
    main()
