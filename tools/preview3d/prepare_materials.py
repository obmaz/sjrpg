"""Mechanically rectify existing generated material pixels for the 3D comparison.

These are small sampled albedos, not newly painted artwork or full PBR scans.
The source has its original self-shading; native light/shadows are evaluated
separately in the optional scene. Mirror repeat is used, not a seamlessness claim.
"""
import hashlib
import json
from pathlib import Path

import cv2
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/art/preview3d'
PATCHES = {
    'limestone': ('assets/source/remake/gate-a.png', [[68, 490], [157, 540], [157, 632], [68, 581]], [256, 256]),
    'slate': ('assets/source/remake/house-ne.png', [[340, 110], [660, 290], [520, 460], [210, 290]], [512, 512]),
    'timber': ('assets/source/remake/house-ne.png', [[610, 139], [810, 249], [797, 273], [595, 159]], [512, 128]),
    'door': ('assets/source/remake/house-ne.png', [[617, 637], [711, 692], [710, 836], [617, 782]], [256, 512]),
}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    records = {}
    for key, (source, points, size) in PATCHES.items():
        image = np.array(Image.open(ROOT / source).convert('RGB'))
        width, height = size
        transform = cv2.getPerspectiveTransform(np.float32(points), np.float32([[0, 0], [width - 1, 0], [width - 1, height - 1], [0, height - 1]]))
        patch = cv2.warpPerspective(image, transform, size, flags=cv2.INTER_CUBIC)
        target = OUT / (key + '.webp')
        Image.fromarray(patch).save(target, 'WEBP', quality=94, method=6)
        records[key] = {'source': source, 'source_sha256': sha(ROOT / source), 'source_quad': points,
                        'path': str(target.relative_to(ROOT)), 'sha256': sha(target), 'size': size,
                        'operation': 'Perspective rectification of the recorded source quad; no painting or material synthesis.'}
        path = 'res://' + str(target.relative_to(ROOT))
        imported = 'res://.godot/imported/' + target.name + '-' + hashlib.md5(path.encode()).hexdigest() + '.ctex'
        import_file = target.with_suffix('.webp.import')
        # Preserve editor-generated UIDs and destination metadata on reproducible reruns.
        if import_file.exists():
            continue
        import_file.write_text(f'''[remap]
importer="texture"
type="CompressedTexture2D"
path="{imported}"
metadata={{"vram_texture": false}}

[deps]
source_file="{path}"
dest_files=PackedStringArray("{imported}")

[params]
compress/mode=1
compress/lossy_quality=0.9
compress/normal_map=0
mipmaps/generate=true
process/fix_alpha_border=true
process/premult_alpha=false
''')
    metadata = {'purpose': 'Optional native3D lighting/geometry comparison, not final reference-art reproduction.',
                'authoritative_reference': {'path': 'assets/source/style/approved-game-reference.jpg',
                                            'sha256': sha(ROOT / 'assets/source/style/approved-game-reference.jpg')},
                'materials': records,
                'limitations': 'Rectified albedo patches retain authored source self-shading. No roughness/normal scan or seamless tile certification is claimed.'}
    (OUT / 'materials.json').write_text(json.dumps(metadata, indent=2) + '\n')
    print('Prepared', len(records), 'rectified comparison materials')


if __name__ == '__main__':
    main()
