#!/usr/bin/env python3
"""Register generated town props from measured pixels; never write shared catalogs.

Run this helper to emit coordinate-calibrated WebPs, definitions, and axis/warp
fragments. The central extraction pipeline calls merge() after town_art.merge().
Only packing/projection changes generated pixels; no replacement geometry is drawn.
"""
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image
import warp_art

ROOT = Path(__file__).resolve().parents[2]
MEASURE = Path(__file__).with_name('props_remake_measure.json')
CATALOG = ROOT / 'assets/data/props_remake.json'
ISO_SCALE = 0.97


def write_json(path, value):
    temporary = path.with_suffix('.tmp')
    temporary.write_text(json.dumps(value, indent=1) + '\n')
    temporary.replace(path)


def project(mesh, point, inverse=False):
    points = np.asarray(mesh['points'])
    source = points[:, 2:] if inverse else points[:, :2]
    target = points[:, :2] if inverse else points[:, 2:]
    for ids in mesh['triangles']:
        a, b, c = source[ids]
        matrix = np.array([b - a, c - a]).T
        if abs(np.linalg.det(matrix)) < 1e-8:
            continue
        u, v = np.linalg.solve(matrix, np.asarray(point) - a)
        if u >= -.001 and v >= -.001 and u + v <= 1.001:
            return (target[ids[0]] * (1 - u - v) + target[ids[1]] * u + target[ids[2]] * v).tolist()
    raise ValueError('Measurement lies outside the projection mesh')


def merge(data):
    catalog = json.loads(CATALOG.read_text())
    for key, record in catalog['records'].items():
        data['sprites'][key] = record['sprite']
        if 'frame' in record:
            data['frames'][key] = record['frame']
    return data


def prepare(encode=True):
    measured = json.loads(MEASURE.read_text())
    catalog = dict(records={})
    meshes, calibrations, axes = {}, {}, []
    for key, config in measured['records'].items():
        if not config.get('enabled', True):
            continue
        source = ROOT / config['source']
        if hashlib.sha256(source.read_bytes()).hexdigest() != config['source_sha256']:
            raise ValueError('Source changed; remeasure ' + key)
        if 'source_sheet' in config:
            sheet = ROOT / config['source_sheet']
            if hashlib.sha256(sheet.read_bytes()).hexdigest() != config['source_sheet_sha256']:
                raise ValueError('Raw source sheet changed; remeasure ' + key)
            cropped = Image.open(sheet).convert('RGBA').crop(config['source_crop'])
            if cropped.tobytes() != Image.open(source).convert('RGBA').tobytes():
                raise ValueError('Derived source crop differs from its exact raw sheet cell: ' + key)
        image = Image.open(source).convert('RGBA')
        width, height = image.size
        # Tiny subpixel upright offsets already satisfy the audit. Preserve X
        # rather than constrain an almost-vertical LSD line to become exactly vertical.
        calibration = dict(png=config['source'], segments=[edge for edge in config['edges'] if edge['axis'] != 90], **config['projection'])
        mesh = warp_art.build(calibration) if config['edges'] else None
        mesh_key = 'remake-' + key
        if mesh is not None:
            calibrations[mesh_key], meshes[mesh_key] = calibration, mesh
        packing = float(config.get('packing', 1))
        packed_size = (round(width * packing), round(height * packing))
        packed = image.convert('RGBa').resize(packed_size, Image.Resampling.LANCZOS).convert('RGBA')
        target = ROOT / config['render']
        temporary = target.with_suffix('.tmp')
        if encode:
            packed.save(temporary, 'WEBP', quality=95, alpha_quality=100, method=6, exact=True)
            temporary.replace(target)
        elif Image.open(target).size != packed_size:
            raise ValueError('Existing packed texture size does not match profile')
        foot = config['foot']
        body = config.get('body')
        packed_body = [value * packing for value in body] if body is not None else None
        packed_foot = [value * packing for value in foot]
        if key == 'pool':
            # Preserve the current enlarged plaza width; Village still applies 2.4.
            world_height = config['world_width'] / width * foot[1] / ISO_SCALE / config['plaza_multiplier']
        else:
            world_height = config.get('world_height', 0)
        sprite = dict(sheet='res://' + config['render'], source=[0, 0, *packed_size],
                      foot=packed_foot, height=config.get('height', foot[1]) * packing, origin=[0, 0], packing=packing,
                      world_height=world_height, body=packed_body, gvs=1, gvk=0,
                      fluid_profile=config.get('fluid', {}))
        if mesh is not None:
            sprite['warp'] = mesh_key
        record = dict(sprite=sprite, source=config['source'], source_sha256=config['source_sha256'],
                      render=config['render'], render_sha256=hashlib.sha256(target.read_bytes()).hexdigest(),
                      alpha_review=config['alpha_review'])
        if 'ground' in config:
            ground = config['ground']
            if config.get('derive_hidden_back_corner', False):
                # The invisible rear footprint is a collision model completed from
                # the three measured visible corners, never an artwork audit sample.
                left, front, right = [np.asarray(project(mesh, p)) for p in ground[:3]]
                ground = ground[:3] + [project(mesh, left + right - front, inverse=True)]
            record['frame'] = dict(ground=[[value * packing for value in point] for point in ground], height=foot[1] * packing, foot=packed_foot)
            if config.get('base_ground', False):
                sprite['base_ground'] = ground
        catalog['records'][key] = record
        if mesh is None:
            print(key, width, height, 'organic silhouette, no rigid projection')
            continue
        axes.append(dict(id=key, kind='sprite', key=key, source_file=config['source'],
                         source_rect=None, source_size=list(image.size), render_file=config['render'],
                         space='native', edges=config['edges'],
                         measurement_note='Actual native upper/middle/lower structural pixels on both visible faces; runtime remap only, natural bowl curves/roof pitches excluded.'))
        points = np.asarray(mesh['points'])
        shift = points[:, 2:] - points[:, :2]
        shift[:, 1] -= config['projection'].get('pad_y', 0)
        maximum = float(np.linalg.norm(shift, axis=1).max())
        print(key, width, height, len(mesh['points']), 'vertices; local max shift', round(maximum, 2))
    write_json(CATALOG, catalog)
    write_json(MEASURE.with_name('props_remake_warps.json'), meshes)
    write_json(MEASURE.with_name('props_remake_calibrations.json'), calibrations)
    write_json(MEASURE.with_name('props_remake_axes.json'), dict(records=axes))


if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--data-only', action='store_true', help='Rebuild geometry fragments for unchanged packed textures')
    args = parser.parse_args()
    prepare(encode=not args.data_only)
