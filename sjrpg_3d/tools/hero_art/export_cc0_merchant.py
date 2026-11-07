"""Export one verified CC0 adult merchant; no runtime refs or gameplay edits.

Run after fetch_sources.py with Blender4.x:
  blender --background --python tools/hero_art/export_cc0_merchant.py
The output directory contains only a self-contained GLB, provenance and licenses.
"""
import hashlib
import json
import math
import os
import re
import struct
from pathlib import Path

import bpy
from mathutils import Matrix, Vector

HERE = Path(__file__).resolve().parent
PROJECT = HERE.parents[1]
CACHE = Path(os.environ.get("SJRPG_CHARACTER_SOURCE_DIR", "/tmp/sjrpg-character-source"))
OUT = Path(os.environ.get("SJRPG_CC0_MERCHANT_OUT", str(PROJECT / "build/cc0-merchant")))
HEIGHT = float(os.environ.get("SJRPG_CC0_MERCHANT_HEIGHT", "1.78"))
if not 1.65 <= HEIGHT <= 1.90:
    raise ValueError("Unexpected adult merchant target")
OUT.mkdir(parents=True, exist_ok=True)
contract_path = HERE / "source-provenance.json"
contract = json.loads(contract_path.read_text())
for relative, record in contract["sourceFiles"].items():
    path = CACHE / relative
    if not path.is_file() or hashlib.sha256(path.read_bytes()).hexdigest() != record["sha256"]:
        raise RuntimeError("Missing/changed reviewed CC0 source: " + relative)

# Reuse the exact existing clean head extraction and official outfit imports.
# Stop before mage animation/material/weapon/robe construction; no sprite render.
os.environ["SJRPG_MATERIAL_PILOT_MODE"] = "clean"
constructor = HERE / "render_mage_pilot.py"
marker = 'bpy.ops.import_scene.gltf(filepath=str(ROOT / "adult-source/UAL1_Standard.glb"))'
prefix, found, _rest = constructor.read_text().partition(marker)
if not found:
    raise RuntimeError("Reviewed mage constructor split point changed")
scope = {"__file__": str(constructor), "__name__": "cc0_merchant_constructor"}
exec(compile(prefix, str(constructor), "exec"), scope)
rig = scope["rig"]
rig.name = "CC0MerchantRig"
head_meshes = [obj for obj in scope["visible"] if not obj.name.startswith(("Male_Peasant", "Male_Ranger"))]
body_meshes = [obj for obj in bpy.data.objects if obj.type == "MESH" and obj.name.startswith("Male_Peasant")]
meshes = body_meshes + head_meshes
if len(body_meshes) < 4 or not any(obj.name.startswith("Eyes") for obj in head_meshes):
    raise RuntimeError("Expected verified Peasant body and extracted base head")
for obj in bpy.data.objects:
    if obj.type == "MESH":
        obj.hide_render = obj not in meshes
        obj.hide_viewport = obj not in meshes
rig.data.pose_position = "REST"
if rig.animation_data:
    rig.animation_data.action = None
bpy.context.view_layer.update()


def select_only(objects):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.hide_set(False)
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]


def rest_bounds(objects):
    graph = bpy.context.evaluated_depsgraph_get()
    points = []
    for obj in objects:
        evaluated = obj.evaluated_get(graph)
        points.extend(evaluated.matrix_world @ Vector(corner) for corner in evaluated.bound_box)
    low = Vector(tuple(min(point[i] for point in points) for i in range(3)))
    high = Vector(tuple(max(point[i] for point in points) for i in range(3)))
    return low, high


before_low, before_high = rest_bounds(meshes)
old_rig_world = rig.matrix_world.copy()
target_rest = {bone.name: {"parent": bone.parent.name if bone.parent else None,
                          "matrix": old_rig_world @ bone.matrix_local}
               for bone in rig.data.bones}
objects_before = set(bpy.data.objects)
actions_before = set(bpy.data.actions)
bpy.ops.import_scene.gltf(filepath=str(CACHE / "adult-source/UAL1_Standard.glb"))
source_rig = next(obj for obj in bpy.data.objects if obj not in objects_before and obj.type == "ARMATURE")
idle_source = next(action for action in bpy.data.actions if action not in actions_before and action.name.startswith("Idle_Loop_Armature"))
source_world = source_rig.matrix_world.copy()
ual_scale = source_world.to_scale()
if max(ual_scale) - min(ual_scale) > 1e-5 or min(ual_scale) <= 0:
    raise RuntimeError("UAL rig unit transform is not positive uniform")
source_bones = {bone.name: bone for bone in source_rig.data.bones}
if set(source_bones) != set(target_rest):
    raise RuntimeError("UAL/Peasant joint names differ")
position_error = 0.0
orientation_error = 0.0
for name, record in target_rest.items():
    bone = source_bones[name]
    if record["parent"] != (bone.parent.name if bone.parent else None):
        raise RuntimeError("UAL/Peasant joint parent differs: " + name)
    source_matrix = source_world @ bone.matrix_local
    position_error = max(position_error, (source_matrix.translation - record["matrix"].translation).length)
    source_rotation = source_matrix.to_quaternion().to_matrix()
    target_rotation = record["matrix"].to_quaternion().to_matrix()
    orientation_error = max(orientation_error, max(abs(source_rotation[row][col] - target_rotation[row][col]) for row in range(3) for col in range(3)))
action_bones = set()
object_tracks = []
for curve in idle_source.fcurves:
    match = re.match(r'pose\.bones\["([^"]+)"\]\.(location|rotation_quaternion|rotation_euler|scale)$', curve.data_path)
    if not match:
        object_tracks.append(curve.data_path)
    else:
        action_bones.add(match.group(1))
if object_tracks or not action_bones.issubset(target_rest) or len(action_bones) < 5:
    raise RuntimeError("Unreviewed idle action paths: " + str((object_tracks, sorted(action_bones - set(target_rest)))))
bind_proof = {"target_rig": rig.name, "source_rig": source_rig.name, "joints": len(target_rest),
              "parents_equal": True, "max_world_rest_head_error_m": position_error,
              "max_world_rest_rotation_error": orientation_error,
              "target_world_scale": list(old_rig_world.to_scale()), "source_world_scale": list(ual_scale),
              "action_bones": sorted(action_bones), "object_tracks": object_tracks,
              "action": idle_source.name, "translation_unit": "UAL world uniform scale"}
print("CC0_MERCHANT_BIND_PROOF " + json.dumps(bind_proof), flush=True)
# Different official-family rests are expected here, never copied as basis curves.
# Preserve this mismatch in provenance and solve an explicit rest-aware FK bake.
bind_proof["binding_mode"] = "world-rotation-delta FK; target rest offsets; root/pelvis translation deltas"
source_rest = {name: source_world @ bone.matrix_local for name, bone in source_bones.items()}
source_fps = bpy.context.scene.render.fps / bpy.context.scene.render.fps_base

uniform = HEIGHT / (before_high.z - before_low.z)
old_rig_world = rig.matrix_world.copy()
source_scale = old_rig_world.to_scale()
if max(source_scale) - min(source_scale) > 1e-5 or min(source_scale) <= 0:
    raise RuntimeError("Source rig has unreviewed nonuniform or negative scale")
feet = [bone.head_local for bone in rig.data.bones if bone.name.lower() in ("foot_l", "foot_r")]
if len(feet) != 2:
    raise RuntimeError("Expected two verified foot joints")
foot_mid = old_rig_world @ ((feet[0] + feet[1]) * 0.5)
normalizer = Matrix.Translation(Vector((-foot_mid.x * uniform, -foot_mid.y * uniform, -before_low.z * uniform))) @ Matrix.Scale(uniform, 4)

# Bake one uniform metric transform into ALL vertices, edit-bone rest locations,
# rigid head attachments, and action translation channels, not root scale alone.
records = []
for obj in meshes:
    records.append((obj, obj.matrix_world.copy(), obj.parent_bone if obj.parent_type == "BONE" else None))
for obj, world, bone_name in records:
    obj.parent = None
    obj.matrix_world = Matrix.Identity(4)
    obj.data.transform(normalizer @ world)
rig.parent = None
rig.matrix_world = Matrix.Identity(4)
select_only([rig])
bpy.ops.object.mode_set(mode="EDIT")
for bone in rig.data.edit_bones:
    bone.use_connect = False
for bone in rig.data.edit_bones:
    bone.transform(normalizer @ old_rig_world)
bpy.ops.object.mode_set(mode="OBJECT")
for obj, world, bone_name in records:
    obj.parent = rig
    obj.matrix_basis = Matrix.Identity(4)
    if bone_name:
        obj.parent_type = "BONE"
        obj.parent_bone = bone_name
        bone = rig.data.bones[bone_name]
        obj.matrix_parent_inverse = (rig.matrix_world @ bone.matrix_local @ Matrix.Translation((0, bone.length, 0))).inverted()
    else:
        obj.parent_type = "OBJECT"
        obj.matrix_parent_inverse = Matrix.Identity(4)
        for modifier in obj.modifiers:
            if modifier.type == "ARMATURE":
                modifier.object = rig
bpy.context.view_layer.update()
after_low, after_high = rest_bounds(meshes)
if abs(after_low.z) > 0.005 or abs((after_high.z - after_low.z) - HEIGHT) > 0.005:
    raise RuntimeError("Metric bake did not preserve a grounded adult body: " + str((after_low, after_high)))

# Keep source UVs and authored source texture color blocks. Downsample the actual
# color image, never a Cycles-only graph; keep matte standard PBR for Compatibility.
small = {}
for obj in meshes:
    for slot in obj.material_slots:
        material = slot.material
        if not material or not material.use_nodes:
            continue
        for node in material.node_tree.nodes:
            if node.type == "BSDF_PRINCIPLED":
                node.inputs["Roughness"].default_value = 0.95
                node.inputs["Metallic"].default_value = 0.0
            if node.type != "TEX_IMAGE" or node.image is None:
                continue
            source = node.image
            if source not in small:
                copy = source.copy()
                if max(copy.size) > 1024:
                    factor = 1024.0 / max(copy.size)
                    copy.scale(round(copy.size[0] * factor), round(copy.size[1] * factor))
                file = OUT / ("merchant-texture-" + str(len(small)) + ".png")
                copy.filepath_raw = str(file)
                copy.file_format = "PNG"
                copy.save()
                small[source] = bpy.data.images.load(str(file), check_existing=False)
            node.image = small[source]

# Explicit retarget: source world rotation delta relative to its own rest is
# applied to the target rest rotation. Joint heads are reconstructed from TARGET
# rest offsets under the newly solved parent, so source proportions cannot stretch
# the Peasant limbs. Only root/pelvis may transfer animated translation deltas.
source_rig.animation_data_create()
source_rig.animation_data.action = idle_source
for other in source_rig.animation_data.nla_tracks:
    other.mute = True
source_rig.data.pose_position = "POSE"
rig.data.pose_position = "POSE"
rig.animation_data_create()
for other in rig.animation_data.nla_tracks:
    other.mute = True
idle = bpy.data.actions.new("idle")
rig.animation_data.action = idle
translation_scale = uniform
scene = bpy.context.scene
source_first, source_last = idle_source.frame_range
duration_seconds = (source_last - source_first) / source_fps
bake_count = max(2, round(duration_seconds * 30) + 1)
ordered = sorted(rig.data.bones, key=lambda bone: len(bone.parent_recursive))
previous_quaternions = {}
max_discarded_translation = 0.0
max_pose_length_error = 0.0
max_source_scale_error = 0.0
for sample in range(bake_count):
    source_frame = source_first + (source_last - source_first) * sample / (bake_count - 1)
    scene.frame_set(math.floor(source_frame), subframe=source_frame - math.floor(source_frame))
    bpy.context.view_layer.update()
    source_pose = {name: source_world @ source_rig.pose.bones[name].matrix for name in source_bones}
    desired = {}
    for bone in ordered:
        name = bone.name
        rest = bone.matrix_local
        source_now = source_pose[name]
        source_bind = source_rest[name]
        delta_rotation = source_now.to_quaternion() @ source_bind.to_quaternion().inverted()
        rotation = delta_rotation @ rest.to_quaternion()
        relative_scale = source_now.to_scale() - source_bind.to_scale()
        max_source_scale_error = max(max_source_scale_error, max(abs(value) for value in relative_scale))
        if bone.parent:
            parent_name = bone.parent.name
            target_offset = (bone.parent.matrix_local.inverted() @ rest).translation
            source_local = source_pose[parent_name].inverted() @ source_now
            source_local_rest = source_rest[parent_name].inverted() @ source_bind
            animated_translation = source_local.translation - source_local_rest.translation
            if name == "pelvis":
                # Parent-frame source metres -> target rest parent frame -> posed parent.
                source_parent_rotation = source_rest[parent_name].to_quaternion()
                target_parent_rotation = bone.parent.matrix_local.to_quaternion()
                target_offset += (target_parent_rotation.inverted() @ source_parent_rotation @ animated_translation) * uniform
            else:
                max_discarded_translation = max(max_discarded_translation, animated_translation.length * uniform)
            position = desired[parent_name] @ target_offset
        else:
            position = rest.translation + (source_now.translation - source_bind.translation) * uniform
        matrix = Matrix.Translation(position) @ rotation.to_matrix().to_4x4()
        desired[name] = matrix
        pose = rig.pose.bones[name]
        pose.rotation_mode = "QUATERNION"
        if bone.parent:
            basis = bone.convert_local_to_pose(matrix, rest,
                parent_matrix=desired[bone.parent.name],
                parent_matrix_local=bone.parent.matrix_local, invert=True)
        else:
            basis = bone.convert_local_to_pose(matrix, rest, invert=True)
        pose.matrix_basis = basis
        quaternion = pose.rotation_quaternion.copy()
        if name in previous_quaternions and quaternion.dot(previous_quaternions[name]) < 0:
            quaternion.negate()
            pose.rotation_quaternion = quaternion
        previous_quaternions[name] = quaternion.copy()
        pose.keyframe_insert("location", frame=sample + 1, group=name)
        pose.keyframe_insert("rotation_quaternion", frame=sample + 1, group=name)
        pose.keyframe_insert("scale", frame=sample + 1, group=name)
    bpy.context.view_layer.update()
    for bone in ordered:
        pose = rig.pose.bones[bone.name]
        max_pose_length_error = max(max_pose_length_error, abs((pose.tail - pose.head).length - bone.length))
if max_discarded_translation > 0.002 or max_source_scale_error > 0.0005 or max_pose_length_error > 0.0005:
    raise RuntimeError("Retarget contains nonrigid/unapproved joint channels: " +
        str((max_discarded_translation, max_source_scale_error, max_pose_length_error)))
for curve in idle.fcurves:
    for key in curve.keyframe_points:
        key.interpolation = "LINEAR"
scene.render.fps = 30
scene.render.fps_base = 1.0
bind_proof["retarget"] = {"fps": 30, "baked_frames": bake_count,
    "source_fps": source_fps, "duration_seconds": duration_seconds,
    "max_discarded_nonpelvis_translation_m": max_discarded_translation,
    "max_source_scale_error": max_source_scale_error,
    "max_posed_bone_length_error_m": max_pose_length_error,
    "translated_bones": ["root", "pelvis"], "quaternion_sign_continuity": True,
    "rest_mismatch_handled_explicitly": position_error > 0.0005 or orientation_error > 0.0005}
print("CC0_MERCHANT_RETARGET_PROOF " + json.dumps(bind_proof["retarget"]), flush=True)
# Sample actual CPU-deformed Blender meshes across the complete idle.
rig.animation_data_create()
rig.animation_data.action = idle
for other in rig.animation_data.nla_tracks:
    other.mute = True
source_rig.animation_data_create()
source_rig.animation_data.action = idle_source
for other in source_rig.animation_data.nla_tracks:
    other.mute = True
source_rig.data.pose_position = "POSE"
rig.data.pose_position = "POSE"
scene = bpy.context.scene
pose_samples = []
feet_meshes = [obj for obj in meshes if "Feet" in obj.name]
for fraction in (0.0, 0.25, 0.5, 0.75, 1.0):
    # Evaluate source and target at matching time, despite the 30fps resample.
    source_frame = source_first + (source_last - source_first) * fraction
    scene.frame_set(math.floor(source_frame), subframe=source_frame - math.floor(source_frame))
    bpy.context.view_layer.update()
    source_root = source_rig.matrix_world @ source_rig.pose.bones["root"].matrix.translation
    first, last = idle.frame_range
    frame = first + (last - first) * fraction
    scene.frame_set(int(frame), subframe=frame - int(frame))
    bpy.context.view_layer.update()
    graph = bpy.context.evaluated_depsgraph_get()
    points = []
    foot_points = []
    for obj in meshes:
        evaluated = obj.evaluated_get(graph)
        data = evaluated.to_mesh()
        transformed = [evaluated.matrix_world @ vertex.co for vertex in data.vertices]
        points.extend(transformed)
        if obj in feet_meshes:
            foot_points.extend(transformed)
        evaluated.to_mesh_clear()
    target_root = rig.matrix_world @ rig.pose.bones["root"].matrix.translation
    pose_samples.append({"phase": fraction, "mesh_min_z": min(point.z for point in points),
                    "mesh_max_z": max(point.z for point in points),
                    "feet_min_z": min(point.z for point in foot_points),
                    "root_xy": [target_root.x, target_root.y],
                    "source_root_xy": [source_root.x, source_root.y],
                    "head_z": (rig.matrix_world @ rig.pose.bones["Head"].head).z,
                    "foot_bones_z": [(rig.matrix_world @ rig.pose.bones[name].head).z for name in ("foot_l", "foot_r")]})
root_drift = max(math.dist(item["root_xy"], pose_samples[0]["root_xy"]) for item in pose_samples)
source_drift = max(math.dist(item["source_root_xy"], pose_samples[0]["source_root_xy"]) for item in pose_samples)
foot_drift = max(item["feet_min_z"] for item in pose_samples) - min(item["feet_min_z"] for item in pose_samples)
pose_proof = {"samples": pose_samples, "target_root_planar_drift_m": root_drift, "source_root_planar_drift_m": source_drift,
              "feet_vertical_drift_m": foot_drift}
print("CC0_MERCHANT_POSE_PROOF " + json.dumps(pose_proof), flush=True)
if root_drift > 0.002 or source_drift > 0.002 or foot_drift > 0.035:
    raise RuntimeError("Idle root/feet are not a stable in-place adult pose")
if min(item["feet_min_z"] for item in pose_samples) < -0.03 or max(item["feet_min_z"] for item in pose_samples) > 0.04:
    raise RuntimeError("Posed merchant feet leave the actual native ground")
source_rig.animation_data.action = None

rig.animation_data_create()
for track in list(rig.animation_data.nla_tracks):
    rig.animation_data.nla_tracks.remove(track)
rig.animation_data.action = None
track = rig.animation_data.nla_tracks.new()
track.name = "idle"
strip = track.strips.new("idle", 1, idle)
strip.action_frame_start, strip.action_frame_end = idle.frame_range
strip.blend_type = "REPLACE"
track.mute = False
keep = {idle}
for action in list(bpy.data.actions):
    if action not in keep:
        bpy.data.actions.remove(action, do_unlink=True)
rig.data.pose_position = "POSE"
scene = bpy.context.scene
scene.render.fps = 30
scene.frame_set(1)
bpy.context.view_layer.update()
select_only([rig] + meshes)
output = OUT / "merchant.glb"
options = dict(filepath=str(output), export_format="GLB", use_selection=True,
               export_apply=True, export_yup=True, export_materials="EXPORT",
               export_animations=True, export_animation_mode="NLA_TRACKS",
               export_frame_range=False, export_force_sampling=True,
               export_skins=True, export_cameras=False, export_lights=False)
supported = {prop.identifier for prop in bpy.ops.export_scene.gltf.get_rna_type().properties}
bpy.ops.export_scene.gltf(**{key: value for key, value in options.items() if key in supported})
raw = output.read_bytes()
if raw[:4] != b"glTF":
    raise RuntimeError("Exporter did not create an actual GLB")
size, chunk_type = struct.unpack_from("<II", raw, 12)
if chunk_type != 0x4E4F534A:
    raise RuntimeError("GLB JSON chunk missing")
gltf = json.loads(raw[20:20 + size])
triangles = sum(gltf["accessors"][primitive["indices"]]["count"] // 3 for mesh in gltf.get("meshes", []) for primitive in mesh["primitives"])
surfaces = sum(len(mesh["primitives"]) for mesh in gltf.get("meshes", []))
clips = [item.get("name", "") for item in gltf.get("animations", [])]
joints = [len(skin["joints"]) for skin in gltf.get("skins", [])]
if not any("idle" in name.lower() for name in clips) or len(joints) != 1 or joints[0] != 65:
    raise RuntimeError("Expected one65-joint skin and actual idle clip: " + str((clips, joints)))
if triangles > 22000 or surfaces > 12 or len(raw) > 6 * 1024 * 1024:
    raise RuntimeError("Merchant pilot exceeds measured geometry/material/download budget")
if any(node.get("camera") is not None for node in gltf.get("nodes", [])) or gltf.get("cameras"):
    raise RuntimeError("Unexpected source camera export")
licenses = {
    "LICENSE-Outfits.txt": "adult-source/License_Standard.txt",
    "LICENSE-Base.txt": "adult-source/base/License_Standard.txt",
    "LICENSE-Animations.txt": "adult-source/Animation-License.txt",
}
for name, relative in licenses.items():
    (OUT / name).write_bytes((CACHE / relative).read_bytes())
manifest = {
    "bind_proof": bind_proof, "pose_proof": pose_proof,
    "asset": "merchant", "runtime_path": "assets/art/native_residents/merchant.glb",
    "creator": "Quaternius", "license": "CC0-1.0",
    "license_records": {name: contract["sourceFiles"][relative] for name, relative in licenses.items()},
    "sources": contract["sources"][:3], "verified_source_files": contract["sourceFiles"],
    "generator": {"path": "tools/hero_art/export_cc0_merchant.py", "sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(), "blender": bpy.app.version_string},
    "constructor": {"path": "tools/hero_art/render_mage_pilot.py", "sha256": hashlib.sha256(constructor.read_bytes()).hexdigest(), "scope": "clean imported outfit/base-head constructor only; no mage weapon/robe/render"},
    "selected_meshes": [obj.name for obj in meshes], "skin_joints": joints[0], "clips": clips,
    "triangles": triangles, "surfaces": surfaces, "up": "+Y", "forward": "+Z",
    "rest_height_m": after_high.z - after_low.z,
    "rest_bounds_min": [after_low.x, after_low.z, -after_high.y],
    "rest_bounds_max": [after_high.x, after_high.z, -after_low.y],
    "root_scale": [1, 1, 1], "uniform_bake_factor": uniform,
    "action_translation_bake_factor": translation_scale,
    "material_policy": "original CC0 UV/color images at max1024; roughness.95, metal0, plain glTF PBR",
    "sha256": hashlib.sha256(raw).hexdigest(), "bytes": len(raw),
    "validation": "Actual GLB inspected for one65-joint skin, idle, triangle/surface/byte budgets and no camera. Godot import, actual posed feet, flash and four-face/mobile visual review still required.",
}
(OUT / "provenance.json").write_text(json.dumps(manifest, indent=2) + "\n")
print("CC0_MERCHANT_READY " + json.dumps({key: manifest[key] for key in ("bytes", "sha256", "triangles", "surfaces", "skin_joints", "clips", "rest_height_m", "root_scale")}), flush=True)
