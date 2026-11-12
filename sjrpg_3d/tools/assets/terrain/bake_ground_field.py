#!/usr/bin/env python3
"""실제 길 합집합의 부호 거리/법선 데이터. 원화에 그림을 덧그리지 않는다."""
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
SOURCE = ROOT / 'assets/source/terrain/ground_field'
DATA = ROOT / 'assets/data'
RANGE = 2.0

def sdf(polygons, wx, wz):
    distance = np.full(wx.shape, np.inf)
    inside_union = np.zeros(wx.shape, dtype=bool)
    for points in polygons:
        inside = np.zeros(wx.shape, dtype=bool)
        for a, b in zip(points, np.roll(points, -1, axis=0)):
            delta = b - a
            t = np.clip(((wx-a[0])*delta[0] + (wz-a[1])*delta[1]) / np.dot(delta, delta), 0, 1)
            distance = np.minimum(distance, np.hypot(wx-a[0]-t*delta[0], wz-a[1]-t*delta[1]))
            if abs(delta[1]) > 1e-12:
                inside ^= ((a[1] > wz) != (b[1] > wz)) & (wx < (b[0]-a[0])*(wz-a[1])/(b[1]-a[1])+a[0])
        inside_union |= inside
    return distance * np.where(inside_union, -1, 1)

def smooth(a, b, x):
    t = np.clip((x-a)/(b-a), 0, 1)
    return t*t*(3-2*t)

def terminals(roads):
    result = []
    for road in roads:
        points = np.asarray(road)
        if len(points) != 4:
            continue
        center = points.mean(axis=0)
        lengths = np.linalg.norm(np.roll(points,-1,axis=0)-points,axis=1)
        if max(lengths) < min(lengths)*1.8:
            continue
        for i, length in enumerate(lengths):
            if length > min(lengths)*1.1:
                continue
            midpoint = (points[i]+points[(i+1)%4])*.5
            inward = center-midpoint; inward /= np.linalg.norm(inward)
            outside = midpoint-inward*.30
            if sdf([np.asarray(r) for r in roads], np.array([outside[0]]), np.array([outside[1]]))[0] < 0:
                continue
            result.append({'center':midpoint.tolist(),'inward':inward.tolist(),'width':float(length)})
    return result


def main():
    source = json.loads((SOURCE / 'roads.json').read_text())
    polygons = [np.array(p, dtype=np.float64) for p in source['union']]
    river = np.asarray(source['river'])
    all_points = np.concatenate(polygons + [river])
    origin = np.floor(all_points.min(axis=0) - RANGE - 1.0)
    extent = np.ceil(all_points.max(axis=0) + RANGE + 1.0) - origin
    # 약 10cm/픽셀, 긴 축만 최대 1536으로 제한한다.
    size = np.ceil(extent / max(.10, extent.max() / 1536)).astype(int)
    y, x = np.mgrid[:size[1], :size[0]]
    wx = origin[0] + (x + .5) / size[0] * extent[0]
    wz = origin[1] + (y + .5) / size[1] * extent[1]
    distance = sdf(polygons, wx, wz)
    gz, gx = np.gradient(distance, extent[1]/size[1], extent[0]/size[0])
    norm = np.maximum(np.hypot(gx, gz), 1e-7)
    rgb = np.stack([np.clip(distance/RANGE, -1, 1)*.5+.5, gx/norm*.5+.5, gz/norm*.5+.5], axis=-1)
    ends = terminals(source['roads'])
    fade = np.zeros(wx.shape)
    for end in ends:
        center = np.array(end['center']); axis = np.array(end['inward'])
        along = (wx-center[0])*axis[0]+(wz-center[1])*axis[1]
        across = abs((wx-center[0])*axis[1]-(wz-center[1])*axis[0])
        mask = smooth(-2.0,-.4,along)*(1-smooth(.3,2.6,along))*(1-smooth(end['width']*.42,end['width']*.5+.45,across))
        fade = np.maximum(fade, mask)
    target = DATA / 'native_ground_field.png'
    Image.fromarray(np.rint(np.dstack([rgb,fade])*255).astype('uint8')).save(target)
    shore_distance = sdf([river], wx, wz)
    gz, gx = np.gradient(shore_distance, extent[1]/size[1], extent[0]/size[0])
    norm = np.maximum(np.hypot(gx,gz),1e-7)
    shore = np.stack([np.clip(shore_distance/2,-1,1)*.5+.5,gx/norm*.5+.5,gz/norm*.5+.5],axis=-1)
    shore_target = DATA/'native_shore_field.png'
    Image.fromarray(np.rint(shore*255).astype('uint8')).save(shore_target)
    record = {'generator': 'tools/assets/terrain/bake_ground_field.py',
              'generator_sha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
              'source': 'assets/source/terrain/ground_field/roads.json',
              'source_sha256': hashlib.sha256((SOURCE/'roads.json').read_bytes()).hexdigest(),
              'origin': origin.tolist(), 'extent': extent.tolist(), 'size': size.tolist(),
              'distance_range': RANGE, 'encoding': 'R=signed distance / 4 + .5; GB=outward XZ normal / 2 + .5; A=terminal dirt fade; linear data, not artwork',
              'field': str(target.relative_to(ROOT)), 'sha256': hashlib.sha256(target.read_bytes()).hexdigest(),
              'roads': source['roads'], 'union': source['union'], 'terminals': ends,
              'shore_field':str(shore_target.relative_to(ROOT)), 'shore_sha256':hashlib.sha256(shore_target.read_bytes()).hexdigest(),
              'river': source['river']}
    (DATA/'native_ground_field.json').write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps({k:record[k] for k in ['origin','extent','size','sha256']}))


if __name__ == '__main__':
    main()
