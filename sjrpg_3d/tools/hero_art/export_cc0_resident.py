"""Build Mira from the exact CC0 female Ranger and female base-head sources.

The existing merchant/mage GLBs are read-only. The verified merchant's existing
rest-aware FK, metric bake and CPU deformation gates are reused, with an explicit
female outfit/head constructor and tighter 512px/8-surface candidate budgets.
"""
import ast
import hashlib
import json
import math
import os
import re
import struct
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector

HERE = Path(__file__).resolve().parent
PROJECT = HERE.parents[1]
CACHE = Path(os.environ.get("SJRPG_CHARACTER_SOURCE_DIR", "/tmp/sjrpg-cc0-merchant-source"))
OUT = Path(os.environ.get("SJRPG_CC0_RESIDENT_OUT", str(PROJECT / "build/cc0-resident")))
OUT.mkdir(parents=True, exist_ok=True)
contract = json.loads((OUT / "resident-source-provenance.json").read_text())
plan = json.loads((HERE / "resident-source-plan.json").read_text())
identity = plan["identity"]
if identity != "mira" or plan != contract["plan"]:
    raise RuntimeError("Only the reviewed Mira pilot is supported")
HEIGHT = float(plan["height_m"])
if not 1.70 <= HEIGHT <= 1.80:
    raise RuntimeError("Mira must retain an adult native-metre height")
for name, expected in contract["sourceFiles"].items():
    data = (CACHE / name).read_bytes()
    if len(data) != expected["bytes"] or hashlib.sha256(data).hexdigest() != expected["sha256"]:
        raise RuntimeError("Source bytes changed before modelling: " + name)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.scene.render.fps = 30
body_path = CACHE / "adult-source/residents/mira/body/Female_Ranger-matte.gltf"
head_path = CACHE / "adult-source/residents/mira/head/Superhero_Female_FullBody-matte.gltf"
bpy.ops.import_scene.gltf(filepath=str(body_path))
rig = next(obj for obj in bpy.data.objects if obj.type == "ARMATURE")
rig.name = "CC0MiraRig"
body_meshes = [obj for obj in bpy.data.objects if obj.type == "MESH" and obj.name.startswith("Female_Ranger")]
if len(body_meshes) != 9 or len(rig.data.bones) != 65:
    raise RuntimeError("Actual reviewed female Ranger components changed")
rig.data.pose_position = "REST"

before = set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=str(head_path))
base_rig = next(obj for obj in bpy.data.objects if obj not in before and obj.type == "ARMATURE")
source_head = base_rig.data.bones["Head"]
target_head = rig.data.bones["Head"]
head_map = target_head.matrix_local @ source_head.matrix_local.inverted()
head_cut = source_head.head_local.z - 0.08
head_meshes = []
head_audit = []
for obj in list(bpy.data.objects):
    if obj in before or obj.type != "MESH":
        continue
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.verts.ensure_lookup_table()
    anatomical = {group.index for group in obj.vertex_groups if group.name in ("Head", "neck_01")}
    remove = []
    audit = {"sourceObject": obj.name, "source_vertices": len(bm.verts),
        "removed_body": 0, "retained_head_neck": 0, "max_removed_head_neck_weight": 0.0}
    for vertex in bm.verts:
        original = obj.data.vertices[vertex.index]
        at = obj.matrix_world @ vertex.co
        weight = sum(group.weight for group in original.groups if group.group in anatomical)
        if at.z < head_cut or weight <= 0.10:
            remove.append(vertex)
            audit["removed_body"] += 1
            audit["max_removed_head_neck_weight"] = max(audit["max_removed_head_neck_weight"], weight if at.z >= head_cut else 0.0)
        else:
            audit["retained_head_neck"] += 1
    bmesh.ops.delete(bm, geom=remove, context="VERTS")
    if not bm.verts:
        bm.free()
        obj.hide_render = True
        obj.hide_viewport = True
        head_audit.append(audit)
        continue
    for vertex in bm.verts:
        vertex.co = head_map @ (obj.matrix_world @ vertex.co)
    bm.to_mesh(obj.data)
    bm.free()
    for modifier in list(obj.modifiers):
        obj.modifiers.remove(modifier)
    obj.parent = rig
    obj.parent_type = "BONE"
    obj.parent_bone = "Head"
    obj.matrix_parent_inverse = (rig.matrix_world @ target_head.matrix_local @ Matrix.Translation((0, target_head.length, 0))).inverted()
    obj.matrix_basis = Matrix.Identity(4)
    head_meshes.append(obj)
    head_audit.append(audit)
if not any(obj.name.startswith("Eyes") for obj in head_meshes) or not any(obj.name.startswith("Superhero_Female") for obj in head_meshes):
    raise RuntimeError("Actual female face, eyes and textured skin are required")

def triangles_of(obj):
    obj.data.calc_loop_triangles()
    return len(obj.data.loop_triangles)

# Facial geometry and the actual exposed hands are kept. Only outfit surfaces
# are collapsed offline; original UVs and skin vertex groups remain attached.
head_triangles = sum(triangles_of(obj) for obj in head_meshes)
protected = [obj for obj in body_meshes if obj.name == "Female_Ranger_Arms"]
reducible = [obj for obj in body_meshes if obj not in protected]
protected_triangles = sum(triangles_of(obj) for obj in protected)
source_triangles = sum(triangles_of(obj) for obj in body_meshes)
available = 17600 - head_triangles - protected_triangles
reducible_triangles = sum(triangles_of(obj) for obj in reducible)
if available < 3000 or reducible_triangles <= 0:
    raise RuntimeError("Cannot retain the protected female face/hands within budget")
ratio = min(1.0, available / reducible_triangles)
for obj in reducible:
    if ratio >= 1.0:
        continue
    bpy.context.view_layer.objects.active = obj
    modifier = obj.modifiers.new("OfflineOutfitBudget", "DECIMATE")
    modifier.ratio = ratio
    modifier.use_collapse_triangulate = True
    bpy.ops.object.modifier_apply(modifier=modifier.name)
actual_after = sum(triangles_of(obj) for obj in body_meshes)
decimation = {"source_outfit_triangles": source_triangles, "source_head_triangles": head_triangles,
    "protected_hand_triangles": protected_triangles, "outfit_ratio": ratio,
    "final_outfit_triangles": actual_after, "face_and_hands_decimated": False}

# Join the skinned outfit components so equal original materials share one
# primitive. Rigid head/eyes remain separate Head-bone attachments.
bpy.ops.object.select_all(action="DESELECT")
for obj in body_meshes:
    obj.select_set(True)
bpy.context.view_layer.objects.active = next(obj for obj in body_meshes if obj.name == "Female_Ranger_Body")
bpy.ops.object.join()
outfit = bpy.context.view_layer.objects.active
outfit.name = "MiraRangerOutfit"
slots = [slot.material for slot in outfit.material_slots]
unique = []
remap = {}
for index, material in enumerate(slots):
    if material not in unique:
        unique.append(material)
    remap[index] = unique.index(material)
for polygon in outfit.data.polygons:
    polygon.material_index = remap[polygon.material_index]
outfit.data.materials.clear()
for material in unique:
    outfit.data.materials.append(material)
# Keep a separately named feet mesh for the shared CPU deformation contact gate.
# Separate only the source foot-weighted islands would lose surfaces/weights;
# the entire outfit is used here and still includes both physical soles.
outfit.name = "MiraRangerOutfitFeet"
body_meshes = [outfit]
meshes = body_meshes + head_meshes
for obj in bpy.data.objects:
    if obj.type == "MESH":
        obj.hide_render = obj not in meshes
        obj.hide_viewport = obj not in meshes
rig.data.pose_position = "REST"
if rig.animation_data:
    rig.animation_data.action = None
bpy.context.view_layer.update()

# Reuse the reviewed converter's actual metric/FK/pose gates rather than
# introducing a second animation solver. This split is checked structurally.
template_path = HERE / "export_cc0_merchant.py"
template = template_path.read_text()
tree = ast.parse(template)
helper_nodes = [node for node in tree.body if isinstance(node, ast.FunctionDef) and node.name in ("select_only", "rest_bounds")]
if len(helper_nodes) != 2:
    raise RuntimeError("Reviewed merchant helper contract changed")
exec(compile(ast.Module(body=helper_nodes, type_ignores=[]), str(template_path), "exec"), globals())
marker = "before_low, before_high = rest_bounds(meshes)"
if template.count(marker) != 1:
    raise RuntimeError("Reviewed merchant conversion boundary changed")
tail = template[template.index(marker):]
replacements = {
    'OUT / "merchant.glb"': 'OUT / (identity + ".glb")',
    '("merchant-texture-"': '(identity + "-texture-"',
    '"asset": "merchant"': '"asset": identity',
    '"runtime_path": "assets/art/native_residents/merchant.glb"': '"runtime_path": "assets/art/native_residents/" + identity + ".glb"',
    '"path": "tools/hero_art/export_cc0_merchant.py"': '"path": "tools/hero_art/export_cc0_resident.py"',
    '"path": "tools/hero_art/render_mage_pilot.py"': '"path": "tools/hero_art/export_cc0_resident.py"',
    '"scope": "clean imported outfit/base-head constructor only; no mage weapon/robe/render"': '"scope": "exact female Ranger plus head/eyes extracted from female base by Head+neck weights; offline outfit simplification only"',
    'if max(copy.size) > 1024:': 'limit = 256 if "eye" in source.name.lower() else 512\n                if max(copy.size) > limit:',
    'factor = 1024.0 / max(copy.size)': 'factor = float(limit) / max(copy.size)',
    'surfaces > 12': 'surfaces > 8',
    'max1024': 'max512',
}
for source, target in replacements.items():
    if source not in tail:
        raise RuntimeError("Reviewed converter token changed: " + source)
    tail = tail.replace(source, target)
tail = tail.replace("CC0_MERCHANT_", "CC0_RESIDENT_")
constructor = Path(__file__).resolve()
exec(compile(tail, str(template_path), "exec"), globals())
proof = json.loads((OUT / "provenance.json").read_text())
proof["shared_converter"] = {"path": "tools/hero_art/export_cc0_merchant.py", "sha256": hashlib.sha256(template.encode()).hexdigest(),
    "reuse": "existing metric bake, rest-aware world-rotation FK, 30fps idle, bone-length and five CPU-deformed ground-contact samples"}
proof["female_head_extraction"] = head_audit
proof["offline_outfit_budget"] = decimation
proof["material_policy"] = "Own original CC0 UV/basecolor, maximum512px (eyes<=256), matte lit PBR roughness0.95; no normal/ORM acquisitions"
proof["runtime_ownership"] = "Villager clock, foot, facing, flash, interaction and collision remain authoritative; no autoplay or new collision"
(OUT / "provenance.json").write_text(json.dumps(proof, indent=2) + "\n")
print("CC0_RESIDENT_CONVERSION " + json.dumps({"identity": identity, "head_extraction": head_audit, "decimation": decimation}), flush=True)
