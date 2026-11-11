#!/usr/bin/env python3
"""에셋별 독립 표면 패키지 검사. 파일을 수정하거나 다른 에셋을 등록하지 않는다."""
import argparse
import hashlib
import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]

def check(folder):
    spec = json.loads((folder / 'asset.json').read_text())
    assert spec['schemaVersion'] == 1 and spec['id'] == folder.name
    assert spec['kind'] == 'surface' and spec['mapping'] in ('facade', 'tile')
    assert spec['atlasGrid'] == [2, 2]
    assert 0 <= spec['roughness'] <= 1 and spec['tileMetres'] > 0
    name = spec['albedo']
    assert Path(name).name == name and '..' not in name
    image = folder / name
    with Image.open(image) as pixels:
        assert pixels.width == pixels.height and pixels.width >= 1254
        assert pixels.width % 2 == 0 and pixels.mode in ('RGB', 'RGBA')
        dimensions = pixels.size
    source = ROOT / 'assets/source/architecture' / folder.name
    proof = json.loads((source / 'provenance.json').read_text())
    assert (source / 'prompt.txt').read_text().strip()
    original = source / 'original.png'
    assert hashlib.sha256(original.read_bytes()).hexdigest() == proof['sha256']
    assert image.read_bytes() == original.read_bytes(), 'Runtime atlas must preserve the adopted source'
    if 'roofAlbedo' in spec:
        roof_name = spec['roofAlbedo']
        assert Path(roof_name).name == roof_name and '..' not in roof_name
        roof = folder / roof_name
        proof = json.loads((source / 'roof-provenance.json').read_text())
        assert roof.read_bytes() == (source / 'roof-original.png').read_bytes()
        assert hashlib.sha256(roof.read_bytes()).hexdigest() == proof['sha256']
        with Image.open(roof) as pixels:
            assert pixels.width == pixels.height and pixels.width >= 1254
    print(f'ASSET_PACKAGE_PASS {folder.name} {dimensions[0]}x{dimensions[1]} {spec["mapping"]}')

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--asset', help='검사할 에셋 폴더명; 생략하면 전체')
    args = parser.parse_args()
    base = ROOT / 'assets/models/architecture'
    if args.asset:
        assert args.asset.isidentifier(), 'Invalid asset ID'
        folders = [base / args.asset]
    else:
        folders = sorted(p.parent for p in base.glob('*/asset.json'))
    assert folders
    for folder in folders:
        check(folder)

if __name__ == '__main__':
    main()
