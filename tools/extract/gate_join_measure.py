#!/usr/bin/env python3
"""Read-only native-pixel / runtime joint profile report.

    python3 tools/extract/gate_join_measure.py
    python3 tools/extract/gate_join_measure.py --targets

This never writes an atlas, mesh or village data. Its optional point targets are
authoring proposals in projected native pixels, evaluated at the CURRENT scale
and pivot. They require scale/pivot landmarks to stay fixed when applied.
World units omit the final Iso.S screen factor, as gate.model_reference does.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path

import numpy as np

import gate_projection

ROOT = Path(__file__).resolve().parents[2]
MEASURE = Path(__file__).with_suffix('.json')


def _rounded(value):
    if isinstance(value, np.ndarray):
        return np.round(value, 5).tolist()
    return round(float(value), 5)


def _line_y(line, x):
    a, b = np.asarray(line, float)
    if abs(b[0] - a[0]) < 1e-8:
        raise ValueError('A front profile reference must have horizontal span')
    return a[1] + (x - a[0]) * (b[1] - a[1]) / (b[0] - a[0])


def _angle(line):
    delta = np.asarray(line[1]) - line[0]
    return math.degrees(math.atan2(delta[1], delta[0]))


class Pose:
    def __init__(self, sprite):
        self.sprite = sprite
        self.key = sprite.get('baked_warp', '')
        self.ratio = sprite['world_height'] / sprite['height']
        self.packing = sprite['packing']
        self.gvs = sprite.get('gvs', 1)
        self.gvk = sprite.get('gvk', 0)

    def projected(self, native):
        return gate_projection.point(self.key, native)

    def world_projected(self, projected):
        sp = self.sprite
        delta = ((np.asarray(projected) - sp['origin']) * self.packing
                 + np.asarray(sp['source'][:2]) - sp['foot'])
        return np.array([delta[0], delta[1] * self.gvs + delta[0] * self.gvk]) * self.ratio

    def world(self, native):
        return self.world_projected(self.projected(native))

    def height_target(self, native, base, desired_height):
        projected = self.projected(native)
        world = self.world_projected(projected)
        target_world_y = _line_y(base, world[0]) - desired_height
        target = projected.copy()
        target[1] += (target_world_y - world[1]) / (self.ratio * self.packing * self.gvs)
        return dict(source=_rounded(np.asarray(native)), target=_rounded(target),
                    current_projected=_rounded(projected),
                    delta_world_y=_rounded(target_world_y - world[1]))


def report(include_targets=False, reference='global'):
    measure = json.loads(MEASURE.read_text())
    village = json.loads((ROOT / 'assets/data/village.json').read_text())
    gates = json.loads((ROOT / 'tools/extract/gate_measure.json').read_text())
    result = dict(units='world units before Iso.S; targets in projected native pixels',
                  canonical=measure['canonical'], target_reference=reference,
                  sources={}, wings={}, gates={})
    for key, source in measure['sources'].items():
        digest = hashlib.sha256((ROOT / source['path']).read_bytes()).hexdigest()
        if digest != source['sha256']:
            raise ValueError(f'{key}: measured source hash changed; remeasure the actual artwork')
        result['sources'][key] = dict(path=source['path'], sha256=digest)

    poses = {key: Pose(village['sprites'][key]) for key in measure['sources']}
    for name, wing in measure['wings'].items():
        key = wing['gate']
        pose = poses[key]
        base = np.array([pose.world(p) for p in wing['base']])
        g = gates['gates'][key]
        global_base = np.array([pose.world(g['front_L']), pose.world(g['front_R'])])
        out = dict(axis=wing['axis'], base_world=_rounded(base),
                   base_angle=_rounded(_angle(base)), features={})
        for feature in ('coping', 'cap'):
            line = np.array([pose.world(p) for p in wing[feature]])
            local_heights = np.array([_line_y(base, p[0]) - p[1] for p in line])
            global_heights = np.array([_line_y(global_base, p[0]) - p[1] for p in line])
            out['features'][feature] = dict(
                raw_native=wing[feature], raw_angle=_rounded(_angle(wing[feature])),
                world_line=_rounded(line), world_angle=_rounded(_angle(line)),
                height_above_own_base=_rounded(local_heights.mean()),
                endpoint_height_spread=_rounded(np.ptp(local_heights)),
                height_above_global_front=_rounded(global_heights.mean()))
        result['wings'][name] = out

    canonical = result['wings'][measure['canonical']]['features']
    height_field = 'height_above_global_front' if reference == 'global' else 'height_above_own_base'
    for name, wing in measure['wings'].items():
        pose = poses[wing['gate']]
        base = np.array([pose.world(p) for p in wing['base']])
        if reference == 'global':
            g = gates['gates'][wing['gate']]
            base = np.array([pose.world(g['front_L']), pose.world(g['front_R'])])
        features = result['wings'][name]['features']
        for feature in ('coping', 'cap'):
            desired = canonical[feature][height_field]
            features[feature]['deviation_from_canonical'] = _rounded(
                features[feature][height_field] - desired)
            if include_targets:
                features[feature]['candidate_targets'] = [
                    pose.height_target(point, base, desired) for point in wing[feature]]

    for key, pose in poses.items():
        g = gates['gates'][key]
        front = [pose.world(g['front_L']), pose.world(g['front_R'])]
        back_at = np.asarray(g[g.get('back_at', 'front_R')], float)
        front_depth = pose.world(back_at)
        back = pose.world(back_at + g['back'])
        delta = back - front_depth
        thick = abs(delta[1]) / 0.5
        # Visual wall front is half a wall-normal in front of the run center.
        # These are the same +/-30 ground normals used by Village._build_walls.
        sign_x = -1 if front[1][1] > front[0][1] else 1
        half = gates['wall']['thick'] / 2
        wall_offset = np.array([sign_x * math.cos(math.pi / 6) * half, half * 0.5])
        model_ends = np.array(g['model_reference']['ends'])
        legacy_wall_front = model_ends + wall_offset
        gap = np.asarray(front) - legacy_wall_front
        out = dict(front_world=_rounded(np.asarray(front)),
                   painted_front_minus_legacy_wall_front=_rounded(gap),
                   actual_depth_world=_rounded(delta),
                   actual_depth_length=_rounded(np.linalg.norm(delta)),
                   inferred_ground_thickness=_rounded(thick),
                   wall_thickness=gates['wall']['thick'])
        if include_targets:
            ratio = gates['wall']['thick'] / thick
            qa = pose.projected(back_at)
            qb = pose.projected(back_at + g['back'])
            target = qa + (qb - qa) * ratio
            out['depth_bottom_candidate'] = dict(
                source=_rounded(back_at + g['back']), target=_rounded(target),
                front_fixed_at=_rounded(qa),
                note='Also constrain matching upper depth corners; x and y movement required')
            if key == 'gate-2':
                # Actual upper side-face coping edge, independently measured on
                # the generated PNG. Its front endpoint meets left-wing coping.
                raw_back = np.array(measure['depth_upper']['back'])
                raw_front = np.array(measure['depth_upper']['front'])
                front_base = np.asarray(front)
                upper_front = pose.height_target(
                    raw_front, front_base, canonical['coping']['height_above_global_front'])
                target_front = np.array(upper_front['target'])
                world_delta = np.array([-math.cos(math.pi / 6) * gates['wall']['thick'],
                                        -0.5 * gates['wall']['thick']])
                dx = world_delta[0] / (pose.ratio * pose.packing)
                dy = (world_delta[1] / (pose.ratio * pose.packing) - dx * pose.gvk) / pose.gvs
                out['depth_upper_candidates'] = [
                    upper_front,
                    dict(source=_rounded(raw_back), target=_rounded(target_front + [dx, dy]),
                         current_projected=_rounded(pose.projected(raw_back)))]
        result['gates'][key] = out
    if include_targets:
        result['constraint_notes'] = measure['constraint_notes']
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--targets', action='store_true', help='include candidate position targets; never apply')
    parser.add_argument('--reference', choices=['global', 'own'], default='global',
                        help='candidate profile datum; global matches front_L/R wall-run attachments')
    args = parser.parse_args()
    print(json.dumps(report(args.targets, args.reference), indent=1))
