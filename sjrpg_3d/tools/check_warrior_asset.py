#!/usr/bin/env python3
"""전사의 실제 GLB 스킨·동작·예산·제작 입력을 확인한다."""
import hashlib
import io
import json
import struct
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def accessor_rows(gltf, data, binary_start, index):
    accessor = gltf['accessors'][index]
    assert not accessor.get('sparse')
    view = gltf['bufferViews'][accessor['bufferView']]
    code, byte_size = {5121: ('B', 1), 5123: ('H', 2), 5125: ('I', 4), 5126: ('f', 4)}[accessor['componentType']]
    width = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4, 'MAT4': 16}[accessor['type']]
    offset = binary_start + view.get('byteOffset', 0) + accessor.get('byteOffset', 0)
    stride = view.get('byteStride', width * byte_size)
    return [struct.unpack_from('<' + code * width, data, offset + row * stride) for row in range(accessor['count'])]


def check():
    folder = ROOT / 'assets/models/heroes/warrior'
    spec = json.loads((folder / 'asset.json').read_text())
    data = (folder / 'model.glb').read_bytes()
    assert struct.unpack_from('<III', data) == (0x46546C67, 2, len(data))
    length = struct.unpack_from('<I', data, 12)[0]
    gltf = json.loads(data[20:20 + length])
    assert digest(folder / 'model.glb') == spec['modelSha256']
    assert digest(ROOT / 'tools/assets/heroes/export_warrior.py') == spec['generatorSha256']
    assert digest(ROOT / spec['sourceLock']) == spec['sourceLockSha256']
    assert digest(ROOT / 'assets/materials/actors/surface_atlas.bin') == spec['actorAtlasSha256']
    assert digest(ROOT / spec['designReference']) == spec['designReferenceSha256']
    assert spec['units'] == 'metres' and spec['forward'] == '+Z' and spec['rootScale'] == [1, 1, 1]
    assert len(gltf['skins']) == 1 and len(gltf['skins'][0]['joints']) == 65
    assert {a['name'] for a in gltf['animations']} == {'idle', 'run', 'cast', 'death'}
    assert all('bufferView' in image and 'uri' not in image for image in gltf['images'])
    source_names = {
        'T_Ranger_BaseColor', 'T_Regular_Male_Dark_BaseColor',
        'T_Hair_1_BaseColor', 'T_Eye_Brown', 'T_Superhero_Male_Dark',
    }
    image_names = [image['name'] for image in gltf['images']]
    assert set(spec['sourceImageNames']) == source_names
    assert len(image_names) == len(set(image_names))
    assert set(image_names) == source_names | {'DarkHair', 'DarkLeather', 'ForestCloak', 'ForgedSteel'}
    expected_textures = {'model_' + name + '.png' for name in image_names}
    assert {path.name for path in folder.glob('model_*.png')} == expected_textures, 'Stale/renamed warrior textures remain'
    binary_start = 20 + length + 8
    for image in gltf['images']:
        view = gltf['bufferViews'][image['bufferView']]
        start = binary_start + view.get('byteOffset', 0)
        with Image.open(io.BytesIO(data[start:start + view['byteLength']])) as pixels:
            assert max(pixels.size) <= 1024, image['name']
            with Image.open(folder / ('model_' + image['name'] + '.png')) as runtime:
                assert runtime.size == pixels.size
                assert runtime.convert('RGBA').tobytes() == pixels.convert('RGBA').tobytes(), image['name']
    assert not gltf.get('cameras') and len(gltf['meshes']) == 2
    triangles = sum(gltf['accessors'][p['indices']]['count'] // 3 for m in gltf['meshes'] for p in m['primitives'])
    surfaces = sum(len(m['primitives']) for m in gltf['meshes'])
    assert triangles == spec['triangles'] < 24000 and surfaces == spec['surfaces'] <= 12
    expected_normals = {'hair_cap': 73, 'vambrace_l': 36, 'vambrace_r': 36}
    expected_normals.update({f'pauldron_{side}_{tier}': 8 for side in ['l', 'r'] for tier in range(3)})
    assert set(spec['authoredNormalAudit']) == set(expected_normals)
    for name, faces in expected_normals.items():
        audit = spec['authoredNormalAudit'][name]
        assert audit['faces'] == faces and audit['minimumOutwardDot'] > .001, name
    for mesh in gltf['meshes']:
        for primitive in mesh['primitives']:
            assert {'POSITION', 'NORMAL', 'JOINTS_0', 'WEIGHTS_0'} <= primitive['attributes'].keys()
    sword = next(node for node in gltf['nodes'] if node['name'] == 'Sword')
    skin = gltf['skins'][sword['skin']]
    hand_index = next(index for index, node_index in enumerate(skin['joints']) if gltf['nodes'][node_index]['name'] == 'hand_r')
    for primitive in gltf['meshes'][sword['mesh']]['primitives']:
        attributes = primitive['attributes']
        joints = accessor_rows(gltf, data, binary_start, attributes['JOINTS_0'])
        weights = accessor_rows(gltf, data, binary_start, attributes['WEIGHTS_0'])
        assert len(joints) == len(weights)
        for joint_row, weight_row in zip(joints, weights):
            assert sum(weight for joint, weight in zip(joint_row, weight_row) if joint == hand_index) > .999, 'Weapon contains a body-bound part'
    for key in ['idle', 'run', 'cast']:
        samples = spec['posedGeometry'][key]
        assert len(samples) == 5 and all(abs(x) < 1e-5 for sample in samples for x in sample['rootXY'])
    assert all(-.035 < p['footMinZ'] < .04 for p in spec['posedGeometry']['idle'])
    source = ROOT / 'assets/source/heroes/warrior'
    assert (source / 'warrior.blend').stat().st_size > 0
    assert digest(source / 'warrior.blend') == spec['sourceBlendSha256']
    source_pose = spec['sourcePose']
    assert source_pose['track'] == 'idle' and source_pose['frame'] == 1
    assert source_pose['availableTracks'] == ['cast', 'death', 'idle', 'run']
    assert source_pose['unmutedTracks'] == ['idle']
    for name in ['LICENSE-Outfits.txt', 'LICENSE-Base.txt', 'LICENSE-Animations.txt']:
        assert 'CC0' in (source / name).read_text()
    print(f'WARRIOR_ASSET_PASS triangles={triangles} surfaces={surfaces} joints=65 clips=4')


if __name__ == '__main__':
    check()
