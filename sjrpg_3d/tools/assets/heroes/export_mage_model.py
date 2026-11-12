"""Export only the verified mage to a small native-3D comparison GLB in /tmp.

Cloth colour is explicitly baked to plain glTF-compatible image inputs. No Cycles
material graph fidelity is assumed. Source skin/face remain the same materials.
"""
import hashlib
import json
import math
import os
from pathlib import Path

import bmesh
import bpy


OUT = Path("/tmp/sjrpg-mage-model")
OUT.mkdir(exist_ok=True)
TEXTURES = OUT / "textures"
TEXTURES.mkdir(exist_ok=True)
renderer = Path(__file__).with_name("render_mage_pilot.py")
prefix = renderer.read_text().split("for jobIndex, (sheet, kind, d, phase, actionName, norm) in enumerate(jobs):")[0]
scope = {"__file__": str(renderer), "__name__": "preview_mage_constructor"}
exec(compile(prefix, str(renderer), "exec"), scope)
rig, scene = scope["rig"], scope["scene"]
meshes = [obj for obj in scene.objects if obj.type == "MESH" and not obj.hide_render]
world = rig.matrix_world.copy()
rig.parent = None  # Do not export sprite FacingYaw or the sprite camera.
rig.matrix_world = world
rig.data.pose_position = "REST"
rig.animation_data.action = None
bpy.context.view_layer.update()
scene.cycles.samples = 1


def select_only(objects):
    for obj in bpy.context.selected_objects:
        obj.select_set(False)
    for obj in objects:
        obj.select_set(True)
    if objects:
        bpy.context.view_layer.objects.active = objects[0]


cloth = {}
for obj in meshes:
    for index, slot in enumerate(obj.material_slots):
        material = slot.material
        if material and (material.name.startswith("MI_Ranger") or
                         (material.name.startswith("MI_Peasant") and "Feet" not in obj.name) or
                         material.name == "Original navy robe panels"):
            cloth.setdefault(material, (obj, index))

material_bakes = []
for index, (material, (original, slot_index)) in enumerate(cloth.items()):
    target = bpy.data.images.new("PreviewClothColour" + str(index), width=512, height=512, alpha=True)
    target.generated_color = (0, 0, 0, 0)
    material.use_nodes = True
    bsdf = next(node for node in material.node_tree.nodes if node.type == "BSDF_PRINCIPLED")
    roughness = float(bsdf.inputs["Roughness"].default_value)
    bake_node = material.node_tree.nodes.new("ShaderNodeTexImage")
    bake_node.image = target
    material.node_tree.nodes.active = bake_node
    copy = original.copy()
    copy.data = original.data.copy()
    copy.parent = None
    copy.matrix_world = original.matrix_world.copy()
    copy.modifiers.clear()
    scene.collection.objects.link(copy)
    bm = bmesh.new()
    bm.from_mesh(copy.data)
    bmesh.ops.delete(bm, geom=[face for face in bm.faces if face.material_index != slot_index], context="FACES")
    bm.to_mesh(copy.data)
    bm.free()
    copy.data.materials.clear()
    copy.data.materials.append(material)
    for polygon in copy.data.polygons:
        polygon.material_index = 0
    select_only([copy])
    bpy.ops.object.bake(type="DIFFUSE", pass_filter={"COLOR"}, use_clear=True, margin=8)
    target.filepath_raw = str(TEXTURES / ("cloth-" + str(index) + ".png"))
    target.file_format = "PNG"
    target.save()
    bpy.data.objects.remove(copy, do_unlink=True)
    # glTF exports this ordinary BaseColor image without relying on arbitrary
    # Hue/Saturation/Multiply/Bump nodes. Micro-bump is intentionally omitted.
    material.node_tree.nodes.clear()
    output = material.node_tree.nodes.new("ShaderNodeOutputMaterial")
    standard = material.node_tree.nodes.new("ShaderNodeBsdfPrincipled")
    standard.inputs["Roughness"].default_value = roughness
    standard.inputs["Metallic"].default_value = 0
    image = material.node_tree.nodes.new("ShaderNodeTexImage")
    image.image = target
    material.node_tree.links.new(image.outputs["Color"], standard.inputs["Base Color"])
    material.node_tree.links.new(standard.outputs[0], output.inputs[0])
    material.name = "PreviewGeneratedCloth_" + str(index)
    material_bakes.append({"material": material.name, "texture": str(target.filepath_raw),
                           "sha256": hashlib.sha256(Path(target.filepath_raw).read_bytes()).hexdigest(),
                           "size": [512, 512], "roughness": roughness, "microBumpOmitted": True})

# Keep source face/skin/boot colour/alpha, with only a smaller texture copy for
# this deliberately small comparison asset. Never overwrite original images.
small_images = {}
for obj in meshes:
    for slot in obj.material_slots:
        material = slot.material
        if not material or not material.use_nodes or material in cloth:
            continue
        for node in material.node_tree.nodes:
            if node.type != "TEX_IMAGE" or node.image is None or max(node.image.size) <= 1024:
                continue
            original = node.image
            if original not in small_images:
                copy = original.copy()
                scale = 1024.0 / max(copy.size)
                copy.scale(round(copy.size[0] * scale), round(copy.size[1] * scale))
                copy.filepath_raw = str(TEXTURES / ("source-" + str(len(small_images)) + ".png"))
                copy.file_format = "PNG"
                copy.save()
                # Imported images can retain packed original bytes after scale/
                # save. Reload the actual smaller file so glTF cannot embed the
                # old multi-megabyte packed image while reporting its new name.
                fresh = bpy.data.images.load(copy.filepath_raw, check_existing=False)
                small_images[original] = fresh
            node.image = small_images[original]

# Keep exactly two original in-place loops and an eight-pose skeletal cast using
# the same native samples as the 2D animation. No facing yaw/camera is animated.
rig.data.pose_position = "POSE"
idle = next(action for action in bpy.data.actions if action.name.startswith("Idle_Loop_Armature"))
run = next(action for action in bpy.data.actions if action.name.startswith("Sprint_Loop_Armature"))
samples = [("Spell_Simple_Enter_Armature", value) for value in (.05, .38, .78)] + \
          [("Spell_Simple_Shoot_Armature", value) for value in (.12, .48, .82)] + \
          [("Spell_Simple_Exit_Armature", value) for value in (.42, .88)]
poses = []
for name, fraction in samples:
    action = next(action for action in bpy.data.actions if action.name.startswith(name))
    rig.animation_data.action = action
    start, end = action.frame_range
    frame = start + (end - start) * fraction
    scene.frame_set(int(frame), subframe=frame - int(frame))
    bpy.context.view_layer.update()
    poses.append({bone.name: bone.matrix_basis.copy() for bone in rig.pose.bones})
cast = bpy.data.actions.new("cast")
rig.animation_data.action = cast
for phase, pose in enumerate(poses):
    for bone in rig.pose.bones:
        bone.rotation_mode = "QUATERNION"
        bone.location, bone.rotation_quaternion, bone.scale = pose[bone.name].decompose()
        for channel in ("location", "rotation_quaternion", "scale"):
            bone.keyframe_insert(data_path=channel, frame=1 + phase * 2, group=bone.name)
for curve in cast.fcurves:
    for key in curve.keyframe_points:
        key.interpolation = "LINEAR"
idle.name, run.name = "idle", "run"
for track in list(rig.animation_data.nla_tracks):
    rig.animation_data.nla_tracks.remove(track)
rig.animation_data.action = None
for name, action in (("idle", idle), ("run", run), ("cast", cast)):
    track = rig.animation_data.nla_tracks.new()
    track.name = name
    strip = track.strips.new(name, 1, action)
    strip.action_frame_start, strip.action_frame_end = action.frame_range
    track.mute = False
keep = {idle, run, cast}
for action in list(bpy.data.actions):
    if action not in keep:
        bpy.data.actions.remove(action, do_unlink=True)
scene.frame_set(1)
scene.render.fps = 30

grip = bpy.data.objects.get("OriginalWandGrip")
selected = [rig] + meshes + ([grip] if grip else [])
select_only(selected)
temporary = OUT / "mage.pending.glb"
options = dict(filepath=str(temporary), export_format="GLB", use_selection=True,
               export_apply=True, export_yup=True, export_materials="EXPORT",
               export_animations=True, export_animation_mode="NLA_TRACKS",
               export_frame_range=False, export_force_sampling=True,
               export_skins=True, export_cameras=False, export_lights=False)
supported = {property.identifier for property in bpy.ops.export_scene.gltf.get_rna_type().properties}
options = {name: value for name, value in options.items() if name in supported}
bpy.ops.export_scene.gltf(**options)
temporary.replace(OUT / "mage.glb")
manifest = {"source": "verified clean/E licensed mage + generated navy cloth",
            "nativeUnits": "metres", "up": "+Y", "forward": "+Z",
            "spriteCameraOrYawExported": False,
            "expectedClips": ["idle", "run", "cast"],
            "castSeconds": 14.0 / 30.0,
            "loopInPresenter": ["idle", "run"],
            "cloth": material_bakes,
            "materialLimitation": "Base colour explicitly baked to512px, roughness preserved. Cycles micro-bump omitted in this small standard-PBR prototype.",
            "selectedMeshObjects": [obj.name for obj in meshes],
            "selectedArmature": rig.name,
            "sha256": hashlib.sha256((OUT / "mage.glb").read_bytes()).hexdigest(),
            "bytes": (OUT / "mage.glb").stat().st_size,
            "exportOptions": options}
(OUT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
print("PREVIEW_GLB_READY", OUT / "mage.glb", manifest["bytes"], flush=True)
