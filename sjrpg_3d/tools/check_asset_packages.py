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
    if spec.get('fullFacade', False):
        assert spec['mapping'] == 'facade' and spec['fullFacade'] is True
        assert proof['dimensions'] == list(dimensions)
        layout = json.loads((source / proof['layout']).read_text())
        assert layout['cell_order'] == ['front+Z', 'right+X', 'back-Z', 'left-X']
        assert all(layout[key] > 0 for key in ('width_m', 'depth_m', 'eaves_m', 'gable_rise_m'))
        assert len(proof['references']) == 3
        for reference in proof['references']:
            actual = (ROOT / reference['path']).resolve()
            assert actual.is_relative_to(ROOT) and actual.is_file()
            assert hashlib.sha256(actual.read_bytes()).hexdigest() == reference['sha256']
    if spec['mapping'] == 'facade':
        assert (spec['infillOnly'] is True or spec.get('hybridFacade') is True) and spec['roofCell'] in range(4)
    if folder.name == 'chapel' and spec.get('hybridFacade'):
        for key, count in [('entrance', 5), ('nave', 8)]:
            rows = spec['facadeWarp'][key]
            assert len(rows) == count and all(len(row) == 2 for row in rows)
            assert rows[0] == [0, .018] and rows[-1] == [1, .982]
            assert all(0 <= row[0] <= 1 and .018 <= row[1] <= .982 for row in rows)
            assert all(rows[i][0] < rows[i+1][0] and rows[i][1] < rows[i+1][1] for i in range(count-1))
    if 'roofAlbedo' in spec:
        roof_name = spec['roofAlbedo']
        assert Path(roof_name).name == roof_name and '..' not in roof_name
        roof_proof = json.loads((source / 'roof-provenance.json').read_text())
        roof = folder / roof_name
        assert roof.read_bytes() == (source / roof_proof['source']).read_bytes()
        assert hashlib.sha256(roof.read_bytes()).hexdigest() == roof_proof['sha256']
        with Image.open(roof) as pixels:
            assert pixels.width == pixels.height and pixels.width >= 1254 and pixels.width % 2 == 0
    if 'inputGeneration' in proof:
        input_proof = proof['inputGeneration']
        assert hashlib.sha256((source / input_proof['source']).read_bytes()).hexdigest() == input_proof['sha256']
        assert (source / input_proof['prompt']).read_text().strip()
        for reference in input_proof['references']:
            assert hashlib.sha256((ROOT / reference['path']).read_bytes()).hexdigest() == reference['sha256']
    print(f'ASSET_PACKAGE_PASS {folder.name} {dimensions[0]}x{dimensions[1]} {spec["mapping"]}')


def check_craft():
    folder = ROOT / 'assets/materials/village_craft'
    spec = json.loads((folder / 'asset.json').read_text())
    assert spec['kind'] == 'material_family' and spec['id'] == folder.name
    for role in ('masonry', 'oak', 'roof'):
        runtime = folder / spec[role]['albedo']
        source = ROOT / spec['source'] / role
        proof = json.loads((source / 'provenance.json').read_text())
        assert runtime.read_bytes() == (source / proof['source']).read_bytes()
        assert hashlib.sha256(runtime.read_bytes()).hexdigest() == proof['sha256']
        assert (source / proof['prompt']).read_text().strip()
        with Image.open(runtime) as pixels:
            assert list(pixels.size) == proof['dimensions'] and pixels.width >= 1254
        for reference in proof['references']:
            assert hashlib.sha256((ROOT / reference['path']).read_bytes()).hexdigest() == reference['sha256']
    print('ASSET_PACKAGE_PASS village_craft masonry/oak/roof')


def check_surface_families():
    for family, role, count in [('grass', 'grass', 10), ('water', 'water', 10),
                                 ('cave/floor', 'floor', 6), ('cave/wall', 'wall', 6)]:
        source = ROOT / 'assets/source/materials' / family
        proof = json.loads((source / 'provenance.json').read_text())
        assert len(proof['images']) == count
        unique = set()
        for index, entry in enumerate(proof['images']):
            expected = f'assets/materials/{family}/{role}-{index}.png'
            assert entry['path'] == expected
            runtime = ROOT / expected
            original = (source / entry['original']).resolve()
            prompt = (source / entry['prompt']).resolve()
            assert original.is_relative_to(source) and prompt.is_relative_to(source)
            pixels = runtime.read_bytes()
            digest = hashlib.sha256(pixels).hexdigest()
            assert digest == entry['sha256'] and len(pixels) == entry['bytes']
            assert pixels == original.read_bytes() and prompt.read_text().strip()
            unique.add(digest)
            with Image.open(runtime) as image:
                assert image.size == (1254, 1254) and image.mode == 'RGB'
            assert entry['actual_references']
            for reference in entry['actual_references']:
                path = (ROOT / reference['path']).resolve()
                assert path.is_relative_to(ROOT) and path.is_file()
                assert hashlib.sha256(path.read_bytes()).hexdigest() == reference['sha256']
        assert len(unique) == count
        print(f'ASSET_PACKAGE_PASS {family} {count} unmodified generated originals')


def check_village_ground():
    source = ROOT / 'assets/source/materials/village_ground'
    proof = json.loads((source / 'provenance.json').read_text())
    atlas = ROOT / proof['source']
    assert atlas == ROOT / 'assets/materials/village_ground/albedo.png'
    assert hashlib.sha256(atlas.read_bytes()).hexdigest() == proof['sha256']
    assert hashlib.sha256((source / proof['prompt']).read_bytes()).hexdigest() == proof['prompt_sha256']
    with Image.open(atlas) as image:
        assert image.size == tuple(proof['dimensions']) == (1254, 1254) and image.mode == 'RGB'
    assert len(proof['cells']) == 4 and proof['cell_metres'] == [1.2, 1.3, 2.1, 2.1]
    for reference in proof['references']:
        assert hashlib.sha256((ROOT / reference['path']).read_bytes()).hexdigest() == reference['sha256']
    print('ASSET_PACKAGE_PASS village_ground unmodified generated atlas')


def check_world_sources():
    record = json.loads((ROOT / 'assets/source/environment/world_refinement/provenance.json').read_text())
    for source in record['implementation']:
        path = (ROOT / source['path']).resolve()
        assert path.is_relative_to(ROOT) and path.is_file()
        assert hashlib.sha256(path.read_bytes()).hexdigest() == source['sha256'], source['path']
    print('ASSET_PACKAGE_PASS world_structure implementation hashes')

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
        if json.loads((folder / 'asset.json').read_text()).get('kind') == 'surface':
            check(folder)
    if not args.asset:
        check_craft()
        check_surface_families()
        check_village_ground()
        from check_enemy_assets import check_all
        check_all()
        check_world_sources()

if __name__ == '__main__':
    main()
