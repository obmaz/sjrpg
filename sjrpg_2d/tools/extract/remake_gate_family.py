#!/usr/bin/env python3
"""Build the measured town-remake gate family without mutating shared catalogs.

The original generated PNGs stay unchanged. This performs only measured
projection and extraction. The root integration step merges the
emitted fragments before ordinary extract_data/art-audit/engine validation.
"""
import hashlib
import argparse
import json
import math
from pathlib import Path

import cv2
import numpy as np
from PIL import Image

import gate_projection
import warp_art

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent


def write(path, value):
    path.write_text(json.dumps(value, indent=1) + '\n')


def extract_wall(gate, mesh, left=119, right=182):
    """Reuse one actual front/rear parapet period before the left tower."""
    image = gate_projection.image(gate['png'], gate['baked_warp'])
    rgba = np.asarray(image).astype(np.float32) / 255.0
    rgba[..., :3] *= rgba[..., 3:4]
    gvs, gvk, scale = gate['gvs'], gate['gvk'], gate['unit_scale']
    height = math.ceil(image.height * gvs + abs(gvk) * image.width) + 16
    corrected = cv2.warpAffine(rgba, np.array([[1., 0., 0.], [gvk, gvs, 0.]]),
                               (image.width, height), flags=cv2.INTER_LINEAR)
    corrected = corrected[:, left:right].copy()
    front = gate_projection.point(gate['baked_warp'], gate['front_L'])
    datum = front[1] * gvs + front[0] * gvk
    floor = datum + math.tan(math.pi / 6) * (np.arange(left, right) - front[0])
    ceiling = floor - 264.0 / scale
    yy = np.arange(height)[:, None]
    corrected[..., 3][(yy < ceiling[None, :] - 8) | (yy > floor[None, :] + 2)] = 0
    corrected[..., :3] /= np.maximum(corrected[..., 3:4], 1 / 255.)
    result = Image.fromarray(np.clip(np.rint(corrected * 255), 0, 255).astype(np.uint8))
    bounds = result.getchannel('A').point(lambda a: 255 if a > 8 else 0).getbbox()
    if bounds is None:
        raise ValueError('Measured gate wing extraction is empty')
    top, bottom = max(0, bounds[1] - 4), min(height, bounds[3] + 4)
    result = result.crop((0, top, right - left, bottom))
    output = ROOT / 'assets/source/remake/wall-from-gate.png'
    result.save(output)
    # IsoSprite applies Iso.S; WallPiece consumes an already projected world scale.
    metadata = dict(parent=gate['png'],
                    parent_sha256=hashlib.sha256((ROOT / gate['png']).read_bytes()).hexdigest(),
                    warp=gate['baked_warp'],
                    parent_mesh={key: mesh[key] for key in ('points', 'triangles')},
                    corrected_crop=[left, top, right - left, bottom - top], gvs=gvs, gvk=gvk,
                    world_pixels_per_source_pixel=scale * .97,
                    front_baseline=[float(floor[0] - top), float(floor[-1] - top)],
                    output=str(output.relative_to(ROOT)),
                    sha256=hashlib.sha256(output.read_bytes()).hexdigest())
    write(HERE / 'remake_wall_from_gate.json', metadata)
    return metadata


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--pack', action='store_true', help='Write only the gate/wall runtime atlases; shared JSON stays unchanged')
    args = parser.parse_args()
    records = {}
    for name, key in [('a', 'gate-0'), ('b', 'gate-2')]:
        path = HERE / f'remake_gate_{name}_measure.json'
        if path.exists():
            records[key] = json.loads(path.read_text())
    meshes = {key: warp_art.build(record['warp_measure']) for key, record in records.items()}
    # Inject only the isolated authoring fragments; never overwrite art_warps.json.
    gate_projection.mesh = lambda key: meshes[key]
    gate_projection.image.cache_clear()
    for key, mesh in meshes.items():
        name = 'a' if key == 'gate-0' else 'b'
        write(HERE / f'remake_gate_{name}_warp_fragment.json', {key: mesh})
    wall = extract_wall(records['gate-0']['gate'], meshes['gate-0'])
    wall_measure = json.loads((HERE / 'remake_wall_measure.json').read_text())
    if wall['sha256'] != wall_measure['source_sha256']:
        raise ValueError('Extracted wall pixels changed: independently remeasure before updating the source hash')
    parallel = {}
    for edge in wall_measure['segments']:
        expected = edge.get('render_axis', edge['axis'])
        delta = np.asarray(edge['b']) - edge['a']
        actual = math.degrees(math.atan2(delta[1], delta[0]))
        error = (actual - expected + 90.0) % 180.0 - 90.0
        if abs(error) > 2.5:
            raise ValueError('Already projected wall axis exceeds tolerance: ' + edge['name'])
        parallel.setdefault(expected, []).append(error)
    if any(max(values) - min(values) > 2.5 for values in parallel.values()):
        raise ValueError('Already projected wall parallel edges exceed tolerance')
    width, height = Image.open(ROOT / wall['output']).size
    if wall_measure.get('derived_identity', False):
        meshes['wall-a'] = dict(source=wall['output'], source_sha256=wall['sha256'],
                                points=[[0, 0, 0, 0], [width-1, 0, width-1, 0],
                                        [width-1, height-1, width-1, height-1], [0, height-1, 0, height-1]],
                                triangles=[[0, 1, 2], [0, 2, 3]],
                                calibration=wall_measure['segments'], canvas_size=[width, height])
    else:
        meshes['wall-a'] = warp_art.build(wall_measure)
    axis_records = []
    for key, record in records.items():
        edges = [{**edge, 'axis': edge['render_axis']} for edge in record['actual_source_segments']]
        axis_records.append(dict(id=key, kind='sprite', key=key, source_file=record['gate']['png'],
                                 source_rect=None, source_size=record['source_size'],
                                 render_file='assets/art/village/gates.webp', space='native',
                                 edges=edges, baked_warp=key))
    for direction in ('a', 'b'):
        edges = []
        for edge in wall_measure['segments']:
            expected = edge.get('render_axis', edge['axis'])
            edges.append({**edge, 'axis': -expected if direction == 'b' and expected != 90 else expected})
        axis_records.append(dict(id='wall-' + direction, kind='wall', key=direction,
                                 source_file=wall['output'], source_rect=None, source_size=[width, height],
                                 render_file='assets/art/village/walls.webp', space='native', edges=edges,
                                 baked_warp='wall-a', mirror_x=direction == 'b'))
    join = dict(_doc='Independent new-source wing base/coping/front lower bevel measurements. '
                    'Collision/passages are preserved separately; opposite cap planes are distinct.',
                sources={key: dict(path=record['gate']['png'], sha256=record['source_sha256'])
                         for key, record in records.items()}, canonical='gate-0.left', wings={},
                wall_profiles={feature: [edge['a'], edge['b']]
                               for feature, name in [('coping', 'front coping boundary'), ('cap', 'front cap lower bevel')]
                               for edge in wall_measure['segments'] if edge['name'] == name})
    for key, record in records.items():
        measured = {edge['name']: edge for edge in record['actual_source_segments']}
        for side in ('left', 'right'):
            def line(name):
                edge = measured[name]
                return [edge['a'], edge['b']]
            cap = 'first cap front lower bevel' if key == 'gate-0' and side == 'left' else side + ' cap bevel'
            join['wings'][key + '.' + side] = dict(gate=key, side=side,
                axis=30 if key == 'gate-0' else -30, base=line(side + ' base'),
                coping=line(side + ' coping'), cap=line(cap))
    depth = records.get('gate-2', {}).get('actual_source_segments', [])
    if depth:
        measured = {edge['name']: edge for edge in depth}
        join['depth_upper'] = dict(back=measured['opposite coping']['a'], front=records['gate-2'].get('depth_upper_front', measured['left coping']['a']),
                                   method='New source opposite/front coping lines; review shared painted corner independently of solids')
    import gate
    gate.M = json.loads((HERE / 'gate_measure.json').read_text())
    layout = gate._layout()
    segments = gate.wall_data()
    village = dict(sprites={}, frames={}, gates={},
                   gate_model_reference={key: record['gate']['model_reference'] for key, record in records.items()},
                   wall=dict(height=200, thick=64, slice_px=24, segs=segments))
    for key, record in records.items():
        sprite, frame, info, report = gate.derive(key, record['gate'], layout)
        village['sprites'][key], village['frames'][key], village['gates'][key] = sprite, frame, info
        print(key, report)
    if args.pack:
        gate.pack()
        gate.wall_sheet()
        gate.family_manifest(village)
    write(HERE / 'remake_gate_family_fragment.json', dict(
        status='authoring_candidate_not_browser_validated',
        gates={key: record['gate'] for key, record in records.items()},
        warp_measure={**{key: record['warp_measure'] for key, record in records.items()}, 'wall-a': wall_measure},
        warps=meshes, axis_measure=dict(records=axis_records), gate_join_measure=join,
        village=village, wall_extraction=wall,
        wall_config=dict(height=200, thick=64, packing=1.0, slice_px=24,
                         segs={direction: dict(png=wall['output'], baked_warp='wall-a',
                                               mirror_x=direction == 'b', gvs=1,
                                               extracted_scale='tools/extract/remake_wall_from_gate.json')
                               for direction in ('a', 'b')})))
    print('Measured gate candidates:', ', '.join(records), '; actual wall crop', wall['corrected_crop'])


if __name__ == '__main__':
    main()
