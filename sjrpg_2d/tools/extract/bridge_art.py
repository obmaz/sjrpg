#!/usr/bin/env python3
"""Project the remade bridge's native pixels onto its preserved playable model.

    python3 tools/extract/bridge_art.py

The source illustration, actual structural edges and measured foreground
silhouettes live in bridge_art_measure.json. This emits one static WebP, runtime
metadata and separate calibration/mesh/audit fragments for the central merger.
It never edits the shared art_axis/art_warp catalogs or the village extraction.
"""
import hashlib
import json
from pathlib import Path

import cv2
import numpy as np
from PIL import Image

import warp_art
from props_remake import project

ROOT = Path(__file__).resolve().parents[2]
MEASURE = Path(__file__).with_name('bridge_art_measure.json')


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write_json(path, data):
    temporary = path.with_suffix('.tmp')
    temporary.write_text(json.dumps(data, indent=1) + '\n')
    temporary.replace(path)


def bake(source, mesh):
    """Use premultiplied native pixels through the reviewed triangle mapping."""
    width, height = mesh.get('canvas_size', source.size)
    points = np.asarray(mesh['points'])
    yy, xx = np.indices((height, width), dtype=np.float32)
    map_x = np.full((height, width), -10000.0, dtype=np.float32)
    map_y = np.full((height, width), -10000.0, dtype=np.float32)
    for ids in mesh['triangles']:
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
        inside = (u >= -.0001) & (v >= -.0001) & (u + v <= 1.0001)
        raw_a, raw_b, raw_c = points[ids, :2]
        sx = raw_a[0] * (1 - u - v) + raw_b[0] * u + raw_c[0] * v
        sy = raw_a[1] * (1 - u - v) + raw_b[1] * u + raw_c[1] * v
        map_x[top:bottom + 1, left:right + 1][inside] = sx[inside]
        map_y[top:bottom + 1, left:right + 1][inside] = sy[inside]
    rgba = np.asarray(source).astype(np.float32) / 255.0
    rgba[..., :3] *= rgba[..., 3:4]
    output = cv2.remap(rgba, map_x, map_y, cv2.INTER_LINEAR, borderMode=cv2.BORDER_CONSTANT)
    output[..., :3] /= np.maximum(output[..., 3:4], 1 / 255.0)
    return Image.fromarray(np.clip(np.rint(output * 255), 0, 255).astype(np.uint8))


def main():
    measure = json.loads(MEASURE.read_text())
    source = ROOT / measure['source']
    if sha(source) != measure['source_sha256']:
        raise ValueError('The actual bridge source changed; remeasure it before packing')
    image = Image.open(source).convert('RGBA')
    if list(image.size) != measure['source_size'] or image.getchannel('A').getextrema()[0] != 0:
        raise ValueError('The measured bridge must retain its native size and transparent surroundings')
    calibration = dict(png=measure['source'], segments=[
        {field: edge[field] for field in ('name', 'a', 'b', 'axis', 'level')}
        for edge in measure['edges']], **measure['projection'])
    mesh = warp_art.build(calibration)
    rendered = bake(image, mesh)
    target = ROOT / measure['render']
    temporary = target.with_suffix('.tmp')
    rendered.save(temporary, 'WEBP', quality=94, alpha_quality=100, method=6, exact=True)
    temporary.replace(target)
    coping = []
    names = set(measure['foreground']['coping_segments'])
    for edge in measure['edges']:
        if edge['name'] in names:
            coping.extend(project(mesh, edge[field]) for field in ('a', 'b'))
    coping.sort(key=lambda p: p[0])
    posts = [[project(mesh, p) for p in polygon] for polygon in measure['foreground']['posts']]
    p = np.asarray(mesh['points'])
    ratios = []
    for ids in mesh['triangles']:
        a, b, c = p[ids, :2]
        d, e, f = p[ids, 2:]
        ratios.append(float(warp_art.cross(e - d, f - d) / warp_art.cross(b - a, c - a)))
    metadata = dict(source=measure['source'], source_sha256=sha(source),
                    render=measure['render'], render_sha256=sha(target),
                    source_size=list(image.size), texture_size=list(rendered.size),
                    warp_key=measure['warp_key'], texture_reference=measure['texture_reference'],
                    model_reference=measure['model_reference'],
                    source_geometry=measure['source_geometry'],
                    foreground=dict(coping=coping, posts=posts),
                    calibration=dict(points=len(p), triangles=len(mesh['triangles']),
                                     max_native_displacement=float(np.linalg.norm(p[:, 2:] - p[:, :2], axis=1).max()),
                                     minimum_area_ratio=min(ratios)),
                    alpha_review=measure['alpha_review'], placement_review=measure['placement_review'],
                    references=[dict(**reference, sha256=sha(ROOT / reference['path']))
                                for reference in measure['references']])
    write_json(ROOT / 'assets/data/bridge_art.json', metadata)
    key = measure['warp_key']
    write_json(MEASURE.with_name('bridge_remake_warps.json'), {key: mesh})
    write_json(MEASURE.with_name('bridge_remake_calibrations.json'), {key: calibration})
    record = dict(id='bridge', kind='bridge', key='bridge', source_file=measure['source'],
                  source_rect=None, source_size=list(image.size), render_file=measure['render'],
                  source_sha256=sha(source), render_sha256=sha(target), space='native',
                  edges=calibration['segments'],
                  measurement_note=measure['measurement_method'])
    write_json(MEASURE.with_name('bridge_remake_axes.json'), dict(records=[record]))
    print('Remade bridge:', len(calibration['segments']), 'actual edges;', len(p),
          'vertices;', len(mesh['triangles']), 'unfolded triangles;', target.stat().st_size, 'bytes')


if __name__ == '__main__':
    main()
