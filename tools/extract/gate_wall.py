#!/usr/bin/env python3
"""Extract one real gate-wing period; never synthesize replacement masonry."""
import hashlib
import json
import math
from pathlib import Path

import cv2
import numpy as np
from PIL import Image
import gate_projection

ROOT = Path(__file__).resolve().parents[2]


def main():
    measurements = json.loads((ROOT / 'tools/extract/gate_measure.json').read_text())
    gate = measurements['gates']['gate-0']
    image = gate_projection.image(gate['png'], gate['baked_warp'])
    top, base = [gate_projection.point(gate['baked_warp'], point) for point in gate['wing_height_line']]
    gvs, gvk = gate['gvs'], gate['gvk']
    corrected_height = (base[1] - top[1]) * gvs + (base[0] - top[0]) * gvk
    unit_scale = gate.get('unit_scale', measurements['wall']['height'] / corrected_height)
    rgba = np.asarray(image).astype(np.float32) / 255.0
    rgba[..., :3] *= rgba[..., 3:4]
    height = math.ceil(image.height * gvs + abs(gvk) * image.width) + 16
    corrected = cv2.warpAffine(rgba, np.array([[1., 0., 0.], [gvk, gvs, 0.]]), (image.width, height), flags=cv2.INTER_LINEAR)
    # This interval contains one real front/rear battlement period, before the tower.
    left, right = measurements['wall'].get('extraction', {}).get('x_range', [161, 225])
    corrected = corrected[:, left:right].copy()
    front = gate_projection.point(gate['baked_warp'], gate['front_L'])
    datum = front[1] * gvs + front[0] * gvk
    xx = np.arange(left, right)
    floor = datum + math.tan(math.pi / 6) * (xx - front[0])
    ceiling = floor - (measurements['wall']['height'] + measurements['wall']['thick']) / unit_scale
    yy = np.arange(height)[:, None]
    # Clip unrelated hanging banners above the wall; retain original stone pixels and alpha.
    corrected[..., 3][(yy < ceiling[None, :] - 8) | (yy > floor[None, :] + 2)] = 0
    corrected[..., :3] /= np.maximum(corrected[..., 3:4], 1 / 255.)
    result = Image.fromarray(np.clip(np.rint(corrected * 255), 0, 255).astype(np.uint8))
    bounds = result.getchannel('A').point(lambda a: 255 if a > 8 else 0).getbbox()
    crop_top, crop_bottom = max(0, bounds[1] - 4), min(height, bounds[3] + 4)
    result = result.crop((0, crop_top, right - left, crop_bottom))
    output = ROOT / measurements['wall']['segs']['a']['png']
    result.save(output)
    record = dict(parent=gate['png'], parent_sha256=hashlib.sha256((ROOT / gate['png']).read_bytes()).hexdigest(),
                  warp=gate['baked_warp'], parent_mesh={key: gate_projection.mesh(gate['baked_warp'])[key] for key in ['points', 'triangles']},
                  corrected_crop=[left, crop_top, right - left, crop_bottom - crop_top], gvs=gvs, gvk=gvk,
                  world_pixels_per_source_pixel=unit_scale * 0.97,
                  front_baseline=[float(floor[0] - crop_top), float(floor[-1] - crop_top)],
                  output=str(output.relative_to(ROOT)), sha256=hashlib.sha256(output.read_bytes()).hexdigest())
    (ROOT / measurements['wall']['segs']['a']['extracted_scale']).write_text(json.dumps(record, indent=1) + '\n')
    print('Extracted actual gate masonry', result.size, 'world scale', record['world_pixels_per_source_pixel'])


if __name__ == '__main__':
    main()
