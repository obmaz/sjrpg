import json
import math
import os
from pathlib import Path

import bmesh
import bpy
from bpy_extras.object_utils import world_to_camera_view
from mathutils import Matrix, Vector

ROOT = Path(os.environ.get("SJRPG_CHARACTER_SOURCE_DIR", "/tmp/sjrpg-character-source"))
OUT = ROOT / "warrior-final"
OUT.mkdir(exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.scene.render.fps = 30
bpy.ops.import_scene.gltf(filepath=str(ROOT / "adult-source/Male_Ranger-matte.gltf"))
rig = [o for o in bpy.data.objects if o.type == "ARMATURE"][0]
rig.name = "RangerRig"
visible = set(
    o for o in bpy.data.objects if o.type == "MESH" and o.name.startswith("Male_Ranger")
)
# Outfit packs deliberately omit the face: attach the official male base head.
# Trim once in rest coordinates and rigidly bind to Head; no per-pose corrections.
beforeBase = set(bpy.data.objects)
bpy.ops.import_scene.gltf(
    filepath=str(ROOT / "adult-source/base/Superhero_Male-matte.gltf")
)
baseRig = next(
    o for o in bpy.data.objects if o not in beforeBase and o.type == "ARMATURE"
)
sourceHead = baseRig.data.bones["Head"]
targetHead = rig.data.bones["Head"]
headMap = targetHead.matrix_local @ sourceHead.matrix_local.inverted()
headCut = sourceHead.head_local.z - 0.08

for o in list(bpy.data.objects):
    if o in beforeBase or o.type != "MESH" or o.name.startswith("Icosphere"):
        continue
    bm = bmesh.new()
    bm.from_mesh(o.data)
    remove = [v for v in bm.verts if (o.matrix_world @ v.co).z < headCut]
    bmesh.ops.delete(bm, geom=remove, context="VERTS")
    if not bm.verts:
        bm.free()
        o.hide_render = True
        continue
    for v in bm.verts:
        v.co = headMap @ (o.matrix_world @ v.co)
    bm.to_mesh(o.data)
    bm.free()
    for modifier in list(o.modifiers):
        o.modifiers.remove(modifier)
    o.parent = rig
    o.parent_type = "BONE"
    o.parent_bone = "Head"
    o.matrix_parent_inverse = (
        rig.matrix_world
        @ targetHead.matrix_local
        @ Matrix.Translation((0, targetHead.length, 0))
    ).inverted()
    o.matrix_basis = Matrix.Identity(4)
    visible.add(o)
bpy.ops.import_scene.gltf(filepath=str(ROOT / "adult-source/UAL1_Standard.glb"))
bpy.ops.import_scene.gltf(filepath=str(ROOT / "adult-source/UAL2_Standard.glb"))
for o in bpy.data.objects:
    if o.type == "MESH":
        o.hide_render = o not in visible
    if o.animation_data:
        for t in o.animation_data.nla_tracks:
            t.mute = True
rig.animation_data_create()
yaw = bpy.data.objects.new("FacingYaw", None)
bpy.context.scene.collection.objects.link(yaw)
rig.parent = yaw
# One global material treatment, retained across every direction/frame.
# Keep source skin texture and leather detail; hood gets muted teal cloth tint.
for o in visible:
    for p in o.data.polygons:
        p.use_smooth = True
    if "Hood" in o.name:
        for slot in o.material_slots:
            if slot.material and slot.material.name.startswith("MI_Ranger"):
                mat = slot.material.copy()
                slot.material = mat
                bsdf = next(
                    n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"
                )
                tex = bsdf.inputs["Base Color"].links[0].from_socket
                tint = mat.node_tree.nodes.new("ShaderNodeMixRGB")
                tint.blend_type = "COLOR"
                tint.inputs[0].default_value = 1
                tint.inputs[2].default_value = (0.016, 0.11, 0.09, 1)
                mat.node_tree.links.new(tex, tint.inputs[1])
                shade = mat.node_tree.nodes.new("ShaderNodeHueSaturation")
                shade.inputs["Value"].default_value = 0.65
                mat.node_tree.links.new(tint.outputs[0], shade.inputs["Color"])
                mat.node_tree.links.new(shade.outputs[0], bsdf.inputs["Base Color"])


# Original simple low-poly sword geometry, no borrowed/runtime asset.
def mat(name, color):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1)
    m.use_nodes = True
    p = m.node_tree.nodes.get("Principled BSDF")
    p.inputs["Base Color"].default_value = (*color, 1)
    p.inputs["Roughness"].default_value = 0.9
    return m


steel = mat("Original matte sword steel", (0.43, 0.49, 0.48))
brass = mat("Original aged guard", (0.30, 0.21, 0.095))
leather = mat("Original brown sword grip", (0.16, 0.085, 0.035))
# Local Z is blade axis; all objects attach through one bone-space offset.
sword = bpy.data.objects.new("OriginalSwordGrip", None)
bpy.context.scene.collection.objects.link(sword)
sword.parent = rig
sword.parent_type = "BONE"
sword.parent_bone = "hand_r"
sword.location = (0, -rig.data.bones["hand_r"].length, 0)
sword.rotation_euler = (0, 0, 0)
verts = [
    (-0.035, -0.012, 0.07),
    (0.035, -0.012, 0.07),
    (0.035, 0.012, 0.07),
    (-0.035, 0.012, 0.07),
    (-0.026, -0.008, 0.49),
    (0.026, -0.008, 0.49),
    (0.026, 0.008, 0.49),
    (-0.026, 0.008, 0.49),
    (0, 0, 0.60),
]
faces = [
    (0, 3, 2, 1),
    (0, 1, 5, 4),
    (1, 2, 6, 5),
    (2, 3, 7, 6),
    (3, 0, 4, 7),
    (4, 5, 8),
    (5, 6, 8),
    (6, 7, 8),
    (7, 4, 8),
]
mesh = bpy.data.meshes.new("OriginalBladeMesh")
mesh.from_pydata(verts, [], faces)
obj = bpy.data.objects.new("OriginalBlade", mesh)
bpy.context.scene.collection.objects.link(obj)
obj.data.materials.append(steel)
obj.parent = sword
for name, location, scale, material in [
    ("Guard", (0, 0, 0.055), (0.105, 0.023, 0.018), brass),
    ("Grip", (0, 0, -0.015), (0.019, 0.019, 0.06), leather),
]:
    bpy.ops.mesh.primitive_cube_add(size=2, location=(0, 0, 0))
    o = bpy.context.object
    o.name = name
    o.parent = sword
    o.location = location
    o.scale = scale
    o.data.materials.append(material)
scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.cycles.samples = 32
scene.cycles.use_denoising = False
scene.render.threads_mode = "FIXED"
scene.render.threads = 2
scene.render.resolution_x = 256
scene.render.resolution_y = 256
scene.render.resolution_percentage = 100
scene.render.film_transparent = True
scene.render.image_settings.file_format = "PNG"
scene.render.image_settings.color_mode = "RGBA"
scene.render.fps = 30
scene.render.use_persistent_data = True
scene.world = bpy.data.worlds.new("World")
scene.world.color = (0.22, 0.22, 0.22)
scene.view_settings.view_transform = "Standard"
scene.view_settings.look = "Medium High Contrast"
bpy.ops.object.camera_add(location=(0, -6, 5.1))
cam = bpy.context.object
cam.rotation_euler = (
    (Vector((0, 0, 0.9)) - cam.location).to_track_quat("-Z", "Y").to_euler()
)
cam.data.type = "ORTHO"
cam.data.ortho_scale = 3.6
scene.camera = cam
for name, pos, power, size in [
    ("Key", (-3, -4, 6), 360, 5),
    ("Fill", (4, -1, 4), 130, 4),
    ("Rim", (0, 4, 5), 120, 3),
]:
    bpy.ops.object.light_add(type="AREA", location=pos)
    o = bpy.context.object
    o.name = name
    o.data.energy = power
    o.data.shape = "DISK"
    o.data.size = size
    o.rotation_euler = (
        (Vector((0, 0, 1)) - o.location).to_track_quat("-Z", "Y").to_euler()
    )
origin = world_to_camera_view(scene, cam, Vector((0, 0, 0)))
m = {
    "source": "Quaternius CC0 Male_Ranger + male base head + UAL1_Standard + UAL2_Standard",
    "sourceType": "adult male hooded ranger",
    "headSource": "official CC0 Superhero_Male, head-only rest trim; no per-pose changes",
    "headRestMap": [list(row) for row in headMap],
    "headRestCutoffZ": headCut,
    "cellSize": [256, 256],
    "worldOriginAnchorPx": [origin.x * 256, (1 - origin.y) * 256],
    "orthoScale": cam.data.ortho_scale,
    "cameraLocation": list(cam.location),
    "target": [0, 0, 0.9],
    "cameraRotation": list(cam.rotation_euler),
    "fixedObjectScale": list(rig.scale),
    "directions": {"E": 90, "SE": 45},
    "actions": {},
    "frames": [],
    "globalMaterialTreatment": "source baseColor, constant roughness.95/metal0, headhood muted teal multiply.72; smooth source normals",
    "originalSword": "procedurally authored blade/guard/grip parented to hand_r, single fixed bind offset, .6m blade",
}
(OUT / "frames").mkdir(exist_ok=True)

# All slots are separate real rendered directions. S0,W4,N8,E12.
labels = [
    "S",
    "SSW",
    "SW",
    "WSW",
    "W",
    "WNW",
    "NW",
    "NNW",
    "N",
    "NNE",
    "NE",
    "ENE",
    "E",
    "ESE",
    "SE",
    "SSE",
]
m["offlineBakePersistentData"] = True
m["samples"] = 32
m["renderThreads"] = 2
m["directions"] = {label: -22.5 * i for i, label in enumerate(labels)}
m["sourceImportFPS"] = 30
m["class"] = "warrior"
m["actorReferenceHeightRaw256"] = 152 * 3.1 / 3.6
m["runtimeExportScale"] = 0.5
m["motion"] = {
    "directions": 16,
    "runFrames": 8,
    "idleOffset": 0,
    "runOffset": 16,
    "layout": "phase-major",
}
m["globalMaterialTreatment"] = (
    "Source brown leather/boots unchanged; hood-only deterministic COLOR tint(.016,.11,.09) with Value.65 global mutedteal, roughness.95/metal0, smooth source normals"
)
jobs = []
for d in range(16):
    jobs.append(("hero", "idle", d, 0, "Idle_Loop_Armature", 0.0))
for p in range(8):
    for d in range(16):
        jobs.append(("hero", "run", d, p, "Sprint_Loop_Armature", p / 8))
for sheet, action, norms in [
    ("hero-attack", "Sword_Regular_A_Armature", [0.125, 0.5]),
    ("hero-backhand", "Sword_Regular_B_Armature", [0, 0.5]),
    ("hero-cleave", "Sword_Regular_C_Armature", [0.125, 0.375]),
]:
    for p, norm in enumerate(norms):
        for d in range(16):
            jobs.append((sheet, "attack", d, p, action, norm))
for p in range(4):
    for d8 in range(8):
        jobs.append(("roll-warrior", "roll", d8 * 2, p, "Roll_Armature", p / 4))
for jobIndex, (sheet, kind, d, phase, actionName, norm) in enumerate(jobs):
    direction = labels[d]
    angle = -22.5 * d
    yaw.rotation_euler.z = math.radians(angle)
    action = next(a for a in bpy.data.actions if a.name.startswith(actionName))
    rig.animation_data.action = action
    start, end = action.frame_range
    m["actions"][actionName] = {
        "actualActionName": action.name,
        "frameRange": [start, end],
        "sourceSeconds": (end - start) / 30,
    }
    frame = start + (end - start) * norm
    scene.frame_set(int(frame), subframe=frame - int(frame))
    bpy.context.view_layer.update()
    bones = {}
    for name in ["root", "pelvis", "Head", "foot_l", "foot_r", "hand_l", "hand_r"]:
        b = rig.pose.bones[name]
        w = rig.matrix_world @ b.head
        p = world_to_camera_view(scene, cam, w)
        bones[name] = {"world": list(w), "pixel": [p.x * 256, (1 - p.y) * 256]}
    head = rig.pose.bones["Head"]
    localGaze = rig.data.bones["Head"].matrix_local.to_3x3().inverted() @ Vector(
        (0, -1, 0)
    )
    worldGaze = rig.matrix_world.to_3x3() @ head.matrix.to_3x3() @ localGaze
    headWorld = rig.matrix_world @ head.head
    gazePoint = world_to_camera_view(scene, cam, headWorld + 0.25 * worldGaze)
    grip = sword.matrix_world @ Vector((0, 0, 0))
    tip = sword.matrix_world @ Vector((0, 0, 0.6))
    gripPx = world_to_camera_view(scene, cam, grip)
    tipPx = world_to_camera_view(scene, cam, tip)
    bones["projectedGaze"] = {
        "worldDirection": list(worldGaze),
        "pixelDelta": [
            (gazePoint.x * 256) - bones["Head"]["pixel"][0],
            ((1 - gazePoint.y) * 256) - bones["Head"]["pixel"][1],
        ],
    }
    bones["sword"] = {
        "gripWorld": list(grip),
        "tipWorld": list(tip),
        "pixelDelta": [(tipPx.x - gripPx.x) * 256, (gripPx.y - tipPx.y) * 256],
    }
    path = OUT / "frames" / f"{sheet}-{kind}-d{d:02d}-p{phase}.png"
    scene.render.filepath = str(path)
    if not path.exists():
        bpy.ops.render.render(write_still=True)
    m["frames"].append(
        {
            "sheet": sheet,
            "kind": kind,
            "direction": direction,
            "directionIndex": d,
            "yawDegrees": angle,
            "phase": phase,
            "action": actionName,
            "normalizedActionTime": norm,
            "actionFrame": frame,
            "path": str(path),
            "bones": bones,
        }
    )
    if jobIndex % 16 == 0 or jobIndex == len(jobs) - 1:
        (OUT / "render-metadata.json").write_text(json.dumps(m, indent=2))
        print(f"CHECKPOINT {jobIndex + 1}/{len(jobs)}", flush=True)
(OUT / "render-metadata.json").write_text(json.dumps(m, indent=2))
