"""Pack the helmeted warrior with the existing, validated projected-origin ABI."""

import hashlib
import importlib.util
import json
from pathlib import Path

spec = importlib.util.spec_from_file_location(
    'character_pack_runtime', Path(__file__).with_name('pack-runtime.py'))
pack = importlib.util.module_from_spec(spec)
spec.loader.exec_module(pack)
pack.OUT = pack.ROOT / 'helmet-runtime'
pack.OUT.mkdir(exist_ok=True)
warrior = pack.load('warrior', 'helmet-warrior', 560)
mage_count = len(json.loads(
    (pack.ROOT / 'mage-full/render-metadata.json').read_text())['frames'])
mage = pack.load('mage', 'mage-full', mage_count)
reference = warrior['actorReferenceHeightRaw256'] * .5
anchor = [v * .5 for v in warrior['worldOriginAnchorPx']]
manifest = {}
for role in ['hero', 'hero-attack', 'hero-backhand', 'hero-cleave']:
    frames = [f for f in warrior['frames'] if f['sheet'] == role]
    result = pack.pack(role, frames, reference, anchor,
                       motion=warrior['motion'] if role == 'hero' else None,
                       anchored=True)
    if role != 'hero':
        result['record']['action'] = {
            'directions': 16, 'frames': 8, 'layout': 'phase-major'}
    manifest[role] = result

rolls = [f for f in warrior['frames'] if f['kind'] == 'roll'] + [
    f for f in mage['frames'] if f['kind'] == 'roll']
assert len(rolls) == 64, '32 helmeted warrior + 32 unchanged mage rolls required'
manifest['roll'] = pack.pack('roll', rolls, reference * 43 / 60,
                             anchor, anchored=True)
manifest['roll']['record']['sizes'].append(
    [128, mage['actorReferenceHeightRaw256'] * .5 * 43 / 60])

for role, result in manifest.items():
    (pack.OUT / f'{role}-bounds.json').write_text(
        json.dumps(result['record'], separators=(',', ':')) + '\n')
    result['frames'] = len(result['record']['frames'])
    result['sha256'] = hashlib.sha256(Path(result['image']).read_bytes()).hexdigest()
manifest['_source'] = {
    'warriorFrames': 560, 'unchangedMageRollFrames': 32,
    'directions': 16, 'runPoses': 8, 'attackPoses': 8,
    'rollDirections': 8, 'rollPoses': 4,
    'projectedOrigin': anchor,
    'uniformExportScale': .5,
    'perPoseScaleCorrection': False,
    'reference': 'exec-e021b823-4c7f-43bf-9e50-5d23e0fd4322.png',
    'bakeContract': warrior['bakeContract'],
}
(pack.OUT / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
(pack.OUT / 'alpha-bounds.json').write_text(json.dumps({
    'bakeContract': warrior['bakeContract'],
    'rawCellSize': [256, 256],
    'packedTransparentPadding': 6,
    'minimumRawEdgePadding': min(min(f['sourceEdgePadding'])
                                  for f in warrior['frames']),
    'frames': [{
        'role': f['sheet'], 'kind': f['kind'], 'direction': f['directionIndex'],
        'phase': f['phase'], 'alphaBounds': f['sourceAlphaBounds'],
        'edgePadding': f['sourceEdgePadding'],
    } for f in warrior['frames']],
}, indent=2) + '\n')
print('HELMETED_WARRIOR_560_REAL_POSES_VALIDATED')
for role, result in manifest.items():
    if not role.startswith('_'):
        print(role, result['frames'], result['decodedRGBABytes'], result['compressedBytes'])
