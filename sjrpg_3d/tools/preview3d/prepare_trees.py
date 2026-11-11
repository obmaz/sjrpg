#!/usr/bin/env python3
"""Reproducible native tree meshes, using generated leaf albedo, never sprite billboards.

Run with system Python. Only one two-thread Blender process is launched. Geometry
is a deliberately authored branching arrangement; this is user-requested native
3D modelling, not code-painted replacement artwork. Leaves retain generated ink.
"""
import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import random
import struct
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets/source/preview3d/trees"
OUTPUT = ROOT / "assets/art/preview3d"


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def prepare_materials():
    from PIL import Image
    OUTPUT.mkdir(parents=True, exist_ok=True)
    leaves = Image.open(SOURCE / "leaves-generated.png").convert("RGBA")
    leaves.thumbnail((1024, 1024), Image.Resampling.LANCZOS)
    leaves.save(OUTPUT / "tree-leaves.webp", "WEBP", quality=92, method=6)
    generation = json.loads((SOURCE / "generation.json").read_text())
    reference_paths = [p["path"] if isinstance(p, dict) else p for p in generation["references"]]
    generation["references"] = [{"path": p, "sha256": sha(ROOT / p)} for p in reference_paths]
    generation["preserved_source"] = {"path": str((SOURCE / "leaves-generated.png").relative_to(ROOT)), "sha256": sha(SOURCE / "leaves-generated.png")}
    generation["runtime_leaf"] = {"path": "assets/art/preview3d/tree-leaves.webp", "sha256": sha(OUTPUT / "tree-leaves.webp"), "operation": "RGBA downsample only, WebP quality 92; no repaint/colour transform", "size": list(leaves.size)}
    generation["bark"] = {"source": "assets/source/preview3d/village-materials.png", "provenance": "assets/art/preview3d/materials.json", "operation": "Use the same generated bark material as the native village family; no independent bark repaint", "path": "assets/art/preview3d/bark.webp", "sha256": sha(OUTPUT / "bark.webp")}
    (SOURCE / "generation.json").write_text(json.dumps(generation, indent=2) + "\n")
    for name in ("tree-leaves.webp",):
        target = OUTPUT / name
        resource = "res://" + str(target.relative_to(ROOT))
        cache = "res://.godot/imported/" + name + "-" + hashlib.md5(resource.encode()).hexdigest() + ".ctex"
        target.with_suffix(".webp.import").write_text(f'''[remap]
importer="texture"
type="CompressedTexture2D"
path="{cache}"
metadata={{"vram_texture": false}}

[deps]
source_file="{resource}"
dest_files=PackedStringArray("{cache}")

[params]
compress/mode=1
compress/lossy_quality=0.92
mipmaps/generate=true
process/fix_alpha_border=true
''')


def build_blender():
    import bpy
    from mathutils import Vector
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    materials = []
    for name, image_name, masked in (("Bark", "bark.webp", False), ("LeafSprays", "tree-leaves.webp", True)):
        mat = bpy.data.materials.new(name)
        mat.use_nodes = True
        mat.diffuse_color = (1, 1, 1, 1)
        nodes = mat.node_tree.nodes
        bsdf = nodes.get("Principled BSDF")
        bsdf.inputs["Roughness"].default_value = 0.94
        tex = nodes.new("ShaderNodeTexImage")
        tex.image = bpy.data.images.load(str(OUTPUT / image_name))
        mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
        if masked:
            mat.node_tree.links.new(tex.outputs["Alpha"], bsdf.inputs["Alpha"])
            mat.surface_render_method = "DITHERED"
            mat.use_backface_culling = False
        materials.append(mat)

    variants = []
    for variant in range(2):
        rng = random.Random(17329 + variant * 53)
        vertices, faces, uvs, mat_ids = [], [], [], []
        branch_count, spray_count = 0, 0

        def vertex(point, uv):
            vertices.append(tuple(point))
            uvs.append(uv)
            return len(vertices) - 1

        def branch(points, radii, sides=7):
            nonlocal branch_count
            branch_count += 1
            rings = []
            lengths = [0.0]
            for i in range(1, len(points)):
                lengths.append(lengths[-1] + (points[i] - points[i - 1]).length)
            for i, (point, radius) in enumerate(zip(points, radii)):
                tangent = (points[min(i + 1, len(points) - 1)] - points[max(i - 1, 0)]).normalized()
                across = tangent.cross(Vector((0, 0, 1))).normalized()
                if across.length < .5:
                    across = tangent.cross(Vector((1, 0, 0))).normalized()
                other = tangent.cross(across).normalized()
                ring = []
                for j in range(sides + 1):
                    angle = j / sides * math.tau
                    wobble = 1 + .07 * math.sin(j * 2.4 + i * .9)
                    ring.append(vertex(point + radius * wobble * (across * math.cos(angle) + other * math.sin(angle)), (j / sides, lengths[i] * 1.3)))
                rings.append(ring)
            for i in range(len(rings) - 1):
                for j in range(sides):
                    faces.append((rings[i][j], rings[i][j + 1], rings[i + 1][j + 1], rings[i + 1][j]))
                    mat_ids.append(0)
            faces.append(tuple(reversed(rings[0][:-1])))
            mat_ids.append(0)
            faces.append(tuple(rings[-1][:-1]))
            mat_ids.append(0)

        def spray(center, span, direction, roll):
            nonlocal spray_count
            spray_count += 1
            # Two triangles bent along the twig centre: fixed 3D normals, not billboards.
            normal = direction.normalized()
            across = normal.cross(Vector((0, 1, 0))).normalized()
            if across.length < .5:
                across = Vector((1, 0, 0))
            up = across.cross(normal).normalized()
            x = across * math.cos(roll) + up * math.sin(roll)
            y = -across * math.sin(roll) + up * math.cos(roll)
            # Eight triangles form a gently curved 3x3 leaf sheet, unlike a flat crossed quad.
            grid = []
            for row in range(3):
                ring = []
                for col in range(3):
                    bend = .10 * span * (1 - abs(col - 1))
                    ring.append(vertex(center + x * ((col - 1) * span * .5) + y * ((row - 1) * span * .5) + normal * bend, (col / 2, row / 2)))
                grid.append(ring)
            for row in range(2):
                for col in range(2):
                    faces.append((grid[row][col], grid[row][col + 1], grid[row + 1][col + 1], grid[row + 1][col]))
                    mat_ids.append(1)

        # Native coordinates: Y up, rooted exactly at Y=0.
        branch([Vector((0, 0, 0)), Vector((-.04, .55, .02)), Vector((.08, 1.3, -.04)), Vector((.02, 2.1, .03)), Vector((.12, 3.1, -.08)), Vector((.03, 4.1, .03))], [.26, .22, .18, .135, .09, .025], 10)
        for i in range(6):
            a = i * math.tau / 6 + .2
            end = Vector((math.cos(a) * .68, .025, math.sin(a) * .68))
            branch([Vector((.0, .28, .0)), end * .65 + Vector((0, .04, 0)), end], [.16, .09, .012], 6)
        # Broad, staggered crown: no volume sphere/cone; independently branched tiers.
        for i in range(11):
            a = i * 2.399963 + rng.uniform(-.17, .17) + variant * .6
            level = 1.65 + (i % 4) * .46 + rng.uniform(-.13, .13)
            radius = (1.55 if i < 8 else 1.12) * rng.uniform(.83, 1.08)
            tip = Vector((math.cos(a) * radius, level + .9 + rng.uniform(-.15, .25), math.sin(a) * radius))
            base = Vector((.06, level - .2, -.02))
            middle = base.lerp(tip, .5) + Vector((0, .12, 0))
            branch([base, middle, tip], [.105 if i < 6 else .075, .052, .011])
            # Fill the actual bough volume as well as its tips. Staggered heights,
            # nonuniform azimuths and independently curved sprays preserve gaps
            # without exposing the entire radial scaffold like a pollarded tree.
            for j in range(12):
                center = base.lerp(tip, .23 + (j % 5) * .15)
                center += Vector((rng.uniform(-.28, .28), rng.uniform(-.08, .42), rng.uniform(-.28, .28)))
                angle = a + j * 1.73 + rng.uniform(-.4, .4)
                normal = Vector((math.cos(angle), rng.uniform(.45, 1.2), math.sin(angle)))
                spray(center, rng.uniform(.86, 1.14), normal, rng.uniform(-math.pi, math.pi))
            for j in range(4):
                fork_angle = a + (j - 1.5) * .47 + rng.uniform(-.15, .15)
                fork = tip + Vector((math.cos(fork_angle) * rng.uniform(.25, .55), rng.uniform(-.1, .38), math.sin(fork_angle) * rng.uniform(.25, .55)))
                start = middle.lerp(tip, .43 + j * .1)
                branch([start, start.lerp(fork, .55) + Vector((0, .1, 0)), fork], [.032, .019, .004], 5)
                for k in range(5):
                    center = fork + Vector((rng.uniform(-.24, .24), rng.uniform(-.22, .22), rng.uniform(-.24, .24)))
                    # Crown normals vary in both axes; leaf fronts retain a mild upward tendency.
                    normal = Vector((math.cos(fork_angle + k * 1.7), rng.uniform(.35, 1.0), math.sin(fork_angle + k * 1.7)))
                    spray(center, rng.uniform(.72, 1.01), normal, rng.uniform(-math.pi, math.pi))
        for j in range(9):
            a = j * 2.399963
            center = Vector((math.cos(a) * rng.uniform(.1, .65), 4.0 + rng.uniform(-.14, .34), math.sin(a) * rng.uniform(.1, .65)))
            spray(center, rng.uniform(.76, .94), Vector((math.cos(a), .7, math.sin(a))), a)
        for j in range(16):
            a = j * 2.399963 + .37
            center = Vector((math.cos(a) * rng.uniform(.25, 1.05), rng.uniform(3.45, 4.08), math.sin(a) * rng.uniform(.25, 1.05)))
            spray(center, rng.uniform(.82, 1.12), Vector((math.cos(a), rng.uniform(.6, 1.2), math.sin(a))), a + .5)

        # The root collars have tilted ring cross-sections. Trim the few mm of
        # below-ground wood to the contact plane instead of burying the origin.
        vertices = [(x, max(0.0, y), z) for x, y, z in vertices]

        mesh = bpy.data.meshes.new("OakMesh%d" % variant)
        mesh.from_pydata(vertices, [], faces)
        mesh.update()
        for mat in materials:
            mesh.materials.append(mat)
        uv = mesh.uv_layers.new(name="UVMap")
        for poly in mesh.polygons:
            poly.material_index = mat_ids[poly.index]
            poly.use_smooth = mat_ids[poly.index] == 0
            for loop in poly.loop_indices:
                uv.data[loop].uv = uvs[mesh.loops[loop].vertex_index]
        obj = bpy.data.objects.new("Oak%d" % variant, mesh)
        bpy.context.collection.objects.link(obj)
        # Blender Z-up -> glTF Y-up exporter conversion is cancelled here.
        for v in mesh.vertices:
            p = v.co.copy()
            v.co = (p.x, -p.z, p.y)
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        path = OUTPUT / ("town-oak-%d.glb" % variant)
        temp = path.with_name(path.stem + ".tmp.glb")
        bpy.ops.export_scene.gltf(filepath=str(temp), export_format="GLB", use_selection=True, export_yup=True, export_animations=False, export_cameras=False, export_lights=False, export_materials="EXPORT", export_image_format="NONE", export_texcoords=True)
        os.replace(temp, path)
        mesh.calc_loop_triangles()
        variants.append({"path": str(path.relative_to(ROOT)), "sha256": sha(path), "bytes": path.stat().st_size, "branches": branch_count, "leaf_sprays": spray_count, "triangles": len(mesh.loop_triangles), "vertices": len(mesh.vertices), "leaf_material": "LeafSprays", "native_root": [0, 0, 0], "native_up": "+Y", "crown_kind": "staggered asymmetric broadleaf tiers with real branches, curved alpha-card sprays in varying fixed 3D orientations", "billboard": False})
    manifest = {"generator": "tools/preview3d/prepare_trees.py", "generator_sha256": sha(__file__), "geometry_license": "Original geometry authored for this project under the repository license; no external model downloaded", "source_material_provenance": "assets/source/preview3d/trees/generation.json", "camera": {"projection": "orthographic", "azimuth_deg": 45, "elevation_deg": 35.2643896828, "ground_axes_deg": [-30, 30]}, "variants": variants, "limitations": ["Alpha-cutout leaf sprays have finite surface thickness and require double-sided alpha-scissor material in Godot; they are not camera-facing billboards", "Generated bark/leaf albedo supplies surface variation; no claim of PBR scan", "Runtime portrait/landscape, two-axis orbit and shadow appearance remain to be inspected in Godot/browser by root"]}
    manifest["packaging"] = {"embedded_images": False, "export_image_format": "NONE", "export_texcoords": True, "material_binding": "Ortho3DTrees assigns shared bark.webp and tree-leaves.webp by preserved Bark/LeafSprays material names; both primitives retain TEXCOORD_0"}
    (OUTPUT / "town-trees.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(json.dumps(manifest, indent=2))


if __name__ == "__main__":
    if "--blender-phase" in sys.argv:
        build_blender()
    else:
        prepare_materials()
        subprocess.run(["blender", "--background", "--threads", "2", "--python", str(Path(__file__).resolve()), "--", "--blender-phase"], check=True)
