"""Meaningful geometry-buffer checks; no Blender, Godot or raster generation."""
import importlib.util
import json
import math
import struct
from pathlib import Path
import sys
import unittest

ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('native_props_author',ROOT/'tools/preview3d/build_native_town_props.py')
author=importlib.util.module_from_spec(spec);sys.modules[spec.name]=author;spec.loader.exec_module(author)


class GeometryPlanTests(unittest.TestCase):
    def test_assets_have_real_depth_and_fit_measured_footprints(self):
        measured=json.loads((ROOT/'assets/source/preview3d/native-town-props/footprints.json').read_text())
        for model,foot,limit in zip((author.fountain(),author.portal()),measured,(8000,6000)):
            plan=model.plan();lo=plan['bounds_m']['min'];hi=plan['bounds_m']['max']
            self.assertLess(plan['triangles'],limit)
            self.assertLessEqual(len(model.groups)+(model.role=='warp-gate'),6)
            self.assertGreater(hi[2]-lo[2],.5)
            self.assertLessEqual(hi[0]-lo[0],foot['width_x_m'])
            self.assertLessEqual(hi[2]-lo[2],foot['depth_z_m'])
            self.assertAlmostEqual(lo[1],0)
            self.assertEqual(plan['baked_scale'],[1,1,1])

    def test_triangles_have_actual_area_and_no_invalid_coordinates(self):
        for model in (author.fountain(),author.portal()):
            for name,group in model.groups.items():
                for tri in group.triangles:
                    a,b,c=[group.vertices[i] for i in tri]
                    self.assertTrue(all(math.isfinite(v) for p in (a,b,c) for v in p))
                    normal=author.cross(author.sub(b,a),author.sub(c,a))
                    self.assertGreater(author.dot(normal,normal),1e-16,(model.role,name,tri))

    def test_fountain_has_two_real_water_heights_and_open_basin_void(self):
        model=author.fountain();water=model.groups['water'].vertices
        self.assertTrue(any(abs(p[1]-.690)<1e-6 for p in water))
        self.assertTrue(any(abs(p[1]-3.010)<1e-6 for p in water))
        rim=[p for p in model.groups['limestone'].vertices if abs(p[1]-1.06)<1e-6]
        radii=[math.hypot(p[0],p[2]) for p in rim]
        self.assertTrue(any(abs(r-1.89)<1e-6 for r in radii))
        self.assertTrue(any(abs(r-2.28)<1e-6 for r in radii))
        self.assertFalse(any(math.hypot(p[0],p[2])<1.8 for p in rim))
        for socket in model.sockets.values():
            self.assertAlmostEqual(socket['splash'][1],.690)
            self.assertLess(math.hypot(socket['splash'][0],socket['splash'][2]),1.872)

    def test_closed_bronze_spouts_have_outward_winding(self):
        group=author.fountain().groups['bronze']
        volume=sum(author.dot(group.vertices[a],author.cross(group.vertices[b],group.vertices[c]))/6 for a,b,c in group.triangles)
        self.assertGreater(volume,0)

    def test_gate_has_human_clearance_and_curved_upper_opening(self):
        model=author.portal();opening=model.sockets['portal_opening']
        self.assertGreaterEqual(opening['width'],1.6)
        self.assertGreaterEqual(opening['height'],2.3)
        points=model.groups['portal'].vertices
        self.assertTrue(all(abs(p[0])<=opening['width']/2+1e-6 for p in points))
        self.assertTrue(any(p[1]>opening['spring']+.7 for p in points))
        self.assertTrue(any(p[1]==opening['bottom'] for p in points))

    def test_native_motion_observes_explicit_source_phase(self):
        for path in (ROOT/'scripts').glob('native_prop_*.gdshader'):
            self.assertNotIn('TIME',path.read_text())
        helper=(ROOT/'scripts/native_town_props_3d.gd').read_text()
        self.assertIn('child is PlazaWater',helper)
        self.assertIn('return child.phase',helper)
        self.assertNotIn('StaticBody3D.new',helper)
        self.assertNotIn('CollisionShape3D.new',helper)

    def test_actual_glbs_are_bounded_without_embedded_images_or_scale_fixes(self):
        for name, triangles, surfaces in [('native-fountain',3612,3),('native-warp-gate',1883,4)]:
            data=(ROOT/'assets/art/preview3d'/f'{name}.glb').read_bytes()
            self.assertEqual(data[:4],b'glTF')
            length,kind=struct.unpack_from('<II',data,12)
            self.assertEqual(kind,0x4e4f534a)
            doc=json.loads(data[20:20+length])
            self.assertEqual(doc.get('images',[]),[])
            self.assertEqual(doc.get('textures',[]),[])
            primitives=[p for m in doc['meshes'] for p in m['primitives']]
            self.assertEqual(len(primitives),surfaces)
            self.assertEqual(sum(doc['accessors'][p['indices']]['count']//3 for p in primitives),triangles)
            for node in doc['nodes']:
                self.assertEqual(node.get('scale',[1,1,1]),[1,1,1])
                self.assertNotIn('matrix',node)
            for primitive in primitives:
                self.assertIn('NORMAL',primitive['attributes'])
                self.assertIn('TEXCOORD_0',primitive['attributes'])

if __name__=='__main__':unittest.main()
