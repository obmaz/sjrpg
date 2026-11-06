#!/usr/bin/env python3
"""Reuse only the upstream forest encounter-stone pixels, calibrate and pack.

    python3 tools/prepare_encounter_art.py
    python3 tools/prepare_encounter_art.py --upstream /path/to/sjrpg

The optional upstream argument restores the lossless first-forest crop after
checking the original sheet hash. No image is generated, painted, recolored or
alpha-cleaned. The reviewed structural mesh is baked into one static WebP.
"""
import argparse
import hashlib
import json
from pathlib import Path
import sys

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools/extract'))
import art_audit_catalog
import gate_projection
import warp_art

MEASURE = ROOT / 'tools/extract/encounter_art_measure.json'
PAD = 4


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write_json(path, data, compact=False):
    temporary = path.with_suffix('.tmp')
    temporary.write_text(json.dumps(data, **({'separators': (',', ':')} if compact else {'indent': 1})) + '\n')
    temporary.replace(path)


def main(upstream=None):
    measure = json.loads(MEASURE.read_text())
    key = measure['id']
    source = ROOT / measure['source']
    if upstream is not None:
        original = Path(upstream) / measure['provenance']['source_path']
        if sha(original) != measure['provenance']['source_sha256']:
            raise ValueError('The reviewed upstream beacon sheet changed; do not reuse its old measurements')
        Image.open(original).crop(measure['provenance']['exact_original_crop']).save(source)
    if sha(source) != measure['source_sha256']:
        raise ValueError('Forest-source hash changed; measure the actual source again')
    native = Image.open(source).convert('RGBA')
    if native.getchannel('A').getextrema()[0] != 0:
        raise ValueError('The isolated forest source must retain a transparent background')

    record = dict(png=measure['source'], segments=[
        {field: edge[field] for field in ('name', 'a', 'b', 'axis', 'level')}
        for edge in measure['edges']], **measure['projection'])
    mesh = warp_art.build(record)
    points = np.asarray(mesh['points'])
    area_ratios = []
    for ids in mesh['triangles']:
        a, b, c = points[ids, :2]
        d, e, f = points[ids, 2:]
        area_ratios.append(float(warp_art.cross(e - d, f - d) / warp_art.cross(b - a, c - a)))
    if min(area_ratios) <= 0:
        raise ValueError('The encounter-stone mesh folds a texture triangle')
    for path, value in [(ROOT / 'tools/extract/art_warp_measure.json', record),
                        (ROOT / 'assets/data/art_warps.json', mesh)]:
        catalog = json.loads(path.read_text())
        catalog[key] = value
        write_json(path, catalog, compact=path.name == 'art_warps.json')

    # Reuse the existing premultiplied remapper. It samples the original pixels
    # through precisely the same source->target mesh exposed to native_point().
    gate_projection.mesh.cache_clear()
    gate_projection.image.cache_clear()
    calibrated = gate_projection.image(measure['source'], key)
    opaque = calibrated.getchannel('A').point(lambda value: 255 if value > 128 else 0).getbbox()
    if opaque is None:
        raise ValueError('The calibrated forest stone is empty')
    full_height = opaque[3] - opaque[1]
    foot = gate_projection.point(key, measure['foot'])
    front_toe = gate_projection.point(key, measure['front_toe'])
    atlas = Image.new('RGBA', (calibrated.width + PAD * 2, calibrated.height + PAD * 2))
    atlas.paste(calibrated, (PAD, PAD))
    target = ROOT / measure['render']
    temporary = target.with_suffix('.tmp')
    atlas.save(temporary, 'WEBP', quality=95, alpha_quality=100, method=6, exact=True)
    temporary.replace(target)
    sprite = dict(sheet='res://' + measure['render'],
                  source=[PAD, PAD, calibrated.width, calibrated.height],
                  foot=(foot + PAD).tolist(), height=full_height,
                  origin=[0, 0], packing=1, gvs=1, gvk=0,
                  world_height=measure['world_height'], body=None, baked_warp=key)
    ground = measure['body_ground']
    x, y = ground['origin']
    width, depth = ground['size']
    body = dict(**ground, polygon=[[x, y], [x + width, y], [x + width, y + depth], [x, y + depth]])
    metadata = dict(id=key, source=measure['source'], source_sha256=sha(source),
                    render=measure['render'], render_sha256=sha(target),
                    sprite=sprite, body_ground=body,
                    contacts=dict(center_native=measure['foot'], center_atlas=(foot + PAD).tolist(),
                                  front_toe_native=measure['front_toe'], front_toe_atlas=(front_toe + PAD).tolist()),
                    opaque_bounds=list(opaque), total_world_height=measure['world_height'],
                    camera=dict(projection='orthographic', ground_axes=[-30, 30], vertical_axis=90),
                    calibration=dict(key=key, points=len(points), triangles=len(mesh['triangles']),
                                     minimum_area_ratio=min(area_ratios),
                                     max_native_displacement=float(np.linalg.norm(points[:, 2:] - points[:, :2], axis=1).max())),
                    alpha_review=measure['alpha_review'], height_method=measure['height_method'],
                    provenance='tools/extract/encounter_art_provenance.json')
    write_json(ROOT / 'assets/data/encounter_stone.json', metadata)
    provenance = dict(**measure['provenance'], extracted_source=measure['source'],
                      extracted_source_sha256=sha(source), measure='tools/extract/encounter_art_measure.json',
                      measure_sha256=sha(MEASURE), runtime=measure['render'], runtime_sha256=sha(target),
                      preparation='tools/prepare_encounter_art.py', alpha_review=measure['alpha_review'],
                      excluded_geometry=measure['excluded_geometry'])
    write_json(ROOT / 'tools/extract/encounter_art_provenance.json', provenance)
    axis_path = ROOT / 'tools/extract/art_axis_measure.json'
    axes = json.loads(axis_path.read_text())
    audit = dict(id=key, kind='sprite', key=key, definition_file='assets/data/encounter_stone.json',
                 definition_key='sprite', source_file=measure['source'], source_rect=None,
                 source_size=list(native.size), render_file=measure['render'], space='native',
                 edges=[{field: edge[field] for field in ('name', 'a', 'b', 'axis', 'level')}
                        for edge in measure['edges']],
                 measurement_note='Actual forest source pixels at post-cap bases, shaft frieze, opposite plinth courses and upright edges. Sloping pyramid roofs/organic ivy are excluded.')
    axes['records'] = [old for old in axes['records'] if old['id'] != key] + [audit]
    write_json(axis_path, axes)
    art_audit_catalog.main()
    print('Forest encounter stone:', atlas.size, 'total height:', full_height,
          'world height:', measure['world_height'], 'edges:', len(audit['edges']),
          'bytes:', target.stat().st_size)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--upstream', type=Path)
    args = parser.parse_args()
    main(args.upstream)
