"""Bake reviewed geometric projections for gate/wall texture strips.

This remaps the generated pixels through the same ArtWarp triangles used by the
measurement API. It paints no replacement stones or edges. Baking keeps the
existing independently depth-sorted gate/wall strips and their alpha silhouettes.
"""
from functools import lru_cache
import json
from pathlib import Path

import cv2
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]


@lru_cache(None)
def mesh(key):
    return json.loads((ROOT / 'assets/data/art_warps.json').read_text())[key]


def point(key, native):
    if not key:
        return np.asarray(native, float)
    data = mesh(key)
    points = np.asarray(data['points'], float)
    q = np.asarray(native, float)
    for ids in data['triangles']:
        a, b, c = points[ids, :2]
        matrix = np.array([b - a, c - a]).T
        if abs(np.linalg.det(matrix)) < 1e-8:
            continue
        u, v = np.linalg.solve(matrix, q - a)
        if u >= -0.001 and v >= -0.001 and u + v <= 1.001:
            return points[ids[0], 2:] * (1 - u - v) + points[ids[1], 2:] * u + points[ids[2], 2:] * v
    return q


@lru_cache(None)
def image(path, key=''):
    source = Image.open(ROOT / path).convert('RGBA')
    if not key:
        return source
    data = mesh(key)
    points = np.asarray(data['points'], float)
    width, height = data.get('canvas_size', source.size)
    yy, xx = np.indices((height, width), dtype=np.float32)
    map_x = np.full((height, width), -10000.0, dtype=np.float32)
    map_y = np.full((height, width), -10000.0, dtype=np.float32)
    for ids in data['triangles']:
        a, b, c = points[ids, 2:]
        matrix = np.array([b - a, c - a]).T
        if abs(np.linalg.det(matrix)) < 1e-8:
            continue
        left, top = np.maximum(0, np.floor(np.min([a, b, c], axis=0)).astype(int))
        right, bottom = np.minimum([width - 1, height - 1], np.ceil(np.max([a, b, c], axis=0)).astype(int))
        if right < left or bottom < top:
            continue
        x = xx[top:bottom + 1, left:right + 1]
        y = yy[top:bottom + 1, left:right + 1]
        inverse = np.linalg.inv(matrix)
        u = inverse[0, 0] * (x - a[0]) + inverse[0, 1] * (y - a[1])
        v = inverse[1, 0] * (x - a[0]) + inverse[1, 1] * (y - a[1])
        inside = (u >= -0.0001) & (v >= -0.0001) & (u + v <= 1.0001)
        raw_a, raw_b, raw_c = points[ids, :2]
        sx = raw_a[0] * (1 - u - v) + raw_b[0] * u + raw_c[0] * v
        sy = raw_a[1] * (1 - u - v) + raw_b[1] * u + raw_c[1] * v
        map_x[top:bottom + 1, left:right + 1][inside] = sx[inside]
        map_y[top:bottom + 1, left:right + 1][inside] = sy[inside]
    # Premultiplied interpolation preserves leaf/stone alpha without dark fringes.
    rgba = np.asarray(source).astype(np.float32) / 255.0
    rgba[..., :3] *= rgba[..., 3:4]
    result = cv2.remap(rgba, map_x, map_y, cv2.INTER_LINEAR, borderMode=cv2.BORDER_CONSTANT)
    result[..., :3] /= np.maximum(result[..., 3:4], 1 / 255.0)
    return Image.fromarray(np.clip(np.rint(result * 255), 0, 255).astype(np.uint8))


def main():
    import argparse
    import warp_art
    parser = argparse.ArgumentParser()
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument('--gates-only', action='store_true')
    mode.add_argument('--wall-only', action='store_true')
    args = parser.parse_args()
    measures = json.loads((ROOT / 'tools/extract/art_warp_measure.json').read_text())
    target = ROOT / 'assets/data/art_warps.json'
    catalog = json.loads(target.read_text())
    keys = ['wall-a'] if args.wall_only else ['gate-0', 'gate-2'] if args.gates_only else ['gate-0', 'gate-2', 'wall-a']
    for key in keys:
        record = measures[key]
        if record.get('derived_identity'):
            # A crop of the calibrated gate already has the camera transform baked in.
            # Retain those exact shared pixels; reject a crop whose measured axes do not fit.
            import math, hashlib
            for edge in record['segments']:
                a, b = np.asarray(edge['a']), np.asarray(edge['b'])
                angle = (math.degrees(math.atan2(*(b - a)[::-1])) + 90) % 180 - 90
                if abs(angle - edge['axis']) > 2.5:
                    raise ValueError('extracted wall axis needs remeasurement: ' + edge['name'])
            width, height = Image.open(ROOT / record['png']).size
            catalog[key] = dict(source=record['png'], source_sha256=hashlib.sha256((ROOT / record['png']).read_bytes()).hexdigest(),
                                points=[[0, 0, 0, 0], [width-1, 0, width-1, 0], [width-1, height-1, width-1, height-1], [0, height-1, 0, height-1]],
                                triangles=[[0,1,2],[0,2,3]], calibration=record['segments'], canvas_size=[width,height])
        else:
            catalog[key] = warp_art.build(record)
        print('gate projection', key, len(catalog[key]['points']), 'vertices')
    target.write_text(json.dumps(catalog, separators=(',', ':')) + '\n')


if __name__ == '__main__':
    main()
