#!/usr/bin/env python3
"""Rebuild the measured Stage 1 town family, then merge shared projection catalogs.

    python3 tools/prepare_town_remake.py /path/to/sjrpg

Source PNGs and actual pixel measurements are the inputs. Family helpers emit
isolated fragments; this serial integration step owns the shared catalogs and
the Dart-derived village data. It does not run Godot or approve visual fidelity.
"""
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
EXTRACT = ROOT / 'tools/extract'
sys.path.insert(0, str(EXTRACT))
import warp_art


def read(path):
    return json.loads(path.read_text())


def write(path, data, compact=False):
    temporary = path.with_suffix('.tmp')
    options = dict(separators=(',', ':')) if compact else dict(indent=1)
    temporary.write_text(json.dumps(data, **options) + '\n')
    temporary.replace(path)


def run(*args):
    subprocess.run([sys.executable, *args], cwd=ROOT, check=True)


def main(upstream):
    # Separate interpreters avoid global image/mesh caches leaking across families.
    run('tools/extract/remake_gate_family.py', '--pack')
    run('tools/extract/bridge_art.py')
    run('tools/extract/props_remake.py')
    gate = read(EXTRACT / 'remake_gate_family_fragment.json')
    calibration = read(EXTRACT / 'art_warp_measure.json')
    calibration.update(read(EXTRACT / 'remake_architecture_warp_measure.json'))
    for name in ['bridge_remake_calibrations.json', 'props_remake_calibrations.json']:
        calibration.update(read(EXTRACT / name))
    calibration.update(gate['warp_measure'])
    write(EXTRACT / 'art_warp_measure.json', calibration)
    meshes = read(ROOT / 'assets/data/art_warps.json')
    changed = set(read(EXTRACT / 'remake_architecture_warp_measure.json'))
    changed.update(read(EXTRACT / 'bridge_remake_calibrations.json'))
    changed.update(read(EXTRACT / 'props_remake_calibrations.json'))
    changed.update(gate['warp_measure'])
    for key in sorted(changed):
        meshes[key] = warp_art.build(calibration[key])
    write(ROOT / 'assets/data/art_warps.json', meshes, compact=True)
    axes = read(EXTRACT / 'art_axis_measure.json')
    replacements = {}
    for name in ['remake_architecture_axis_measure.json', 'bridge_remake_axes.json', 'props_remake_axes.json']:
        for record in read(EXTRACT / name)['records']:
            replacements[record['id']] = record
    for record in gate['axis_measure']['records']:
        replacements[record['id']] = record
    existing = {record['id'] for record in axes['records']}
    if set(replacements) - existing:
        raise ValueError('Unexpected new audit family; review coverage explicitly')
    axes['records'] = [replacements.get(record['id'], record) for record in axes['records']]
    write(EXTRACT / 'art_axis_measure.json', axes)
    write(EXTRACT / 'gate_join_measure.json', gate['gate_join_measure'])
    run('tools/extract/gate.py')
    run('tools/extract/town_art.py')
    run('tools/prepare_forest_art.py')
    run('tools/prepare_tree_art.py')
    run('tools/prepare_river_art.py')
    run('tools/extract/extract_data.py', str(upstream), '--only=village')
    run('tools/extract/art_audit_catalog.py')
    print('Town remake catalogs, textures and village data rebuilt; engine/browser review still required')


if __name__ == '__main__':
    if len(sys.argv) != 2:
        raise SystemExit(__doc__)
    main(Path(sys.argv[1]).resolve())
