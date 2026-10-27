import hashlib
import json
import math
import os
from pathlib import Path

import bmesh
import bpy
from bpy_extras.object_utils import world_to_camera_view
from mathutils import Matrix, Vector

ROOT = Path(os.environ.get("SJRPG_CHARACTER_SOURCE_DIR", "/tmp/sjrpg-character-source"))
OUT = ROOT / "mage-full"
OUT.mkdir(exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.scene.render.fps = 30
bpy.ops.import_scene.gltf(
    filepath=str(ROOT / "adult-source/mage/Male_Peasant-matte.gltf")
)
rig = [o for o in bpy.data.objects if o.type == "ARMATURE"][0]
rig.name = "MageRig"
visible = set(
    o
    for o in bpy.data.objects
    if o.type == "MESH" and o.name.startswith("Male_Peasant")
)
# Same free CC0 Ranger hood, rest-bound once to the Peasant's male Head bone.
beforeHood = set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=str(ROOT / "adult-source/Male_Ranger-matte.gltf"))
hoodRig = next(
    o for o in bpy.data.objects if o not in beforeHood and o.type == "ARMATURE"
)
hood = next(
    o
    for o in bpy.data.objects
    if o not in beforeHood and o.name.startswith("Male_Ranger_Head_Hood")
)
hoodMap = (
    rig.data.bones["Head"].matrix_local
    @ hoodRig.data.bones["Head"].matrix_local.inverted()
)
for v in hood.data.vertices:
    v.co = hoodMap @ (hood.matrix_world @ v.co)
for modifier in list(hood.modifiers):
    hood.modifiers.remove(modifier)
hood.parent = rig
hood.parent_type = "BONE"
hood.parent_bone = "Head"
hb = rig.data.bones["Head"]
hood.matrix_parent_inverse = (
    rig.matrix_world @ hb.matrix_local @ Matrix.Translation((0, hb.length, 0))
).inverted()
hood.matrix_basis = Matrix.Identity(4)
visible.add(hood)
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
    if "Hood" in o.name or (o.name.startswith("Male_Peasant") and "Feet" not in o.name):
        for slot in o.material_slots:
            if slot.material and (
                slot.material.name.startswith("MI_Ranger")
                or slot.material.name.startswith("MI_Peasant")
            ):
                material = slot.material.copy()
                slot.material = material
                bsdf = next(
                    n for n in material.node_tree.nodes if n.type == "BSDF_PRINCIPLED"
                )
                tex = bsdf.inputs["Base Color"].links[0].from_socket
                color = material.node_tree.nodes.new("ShaderNodeMixRGB")
                color.blend_type = "COLOR"
                color.inputs[0].default_value = 0.94
                color.inputs[2].default_value = (0.025, 0.07, 0.16, 1)
                material.node_tree.links.new(tex, color.inputs[1])
                shade = material.node_tree.nodes.new("ShaderNodeHueSaturation")
                shade.inputs["Saturation"].default_value = 0.75
                shade.inputs["Value"].default_value = 0.48 if "Hood" in o.name else 0.28
                material.node_tree.links.new(color.outputs[0], shade.inputs["Color"])
                material.node_tree.links.new(
                    shade.outputs[0], bsdf.inputs["Base Color"]
                )


# Original simple low-poly sword geometry, no borrowed/runtime asset.
def mat(name, color):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1)
    m.use_nodes = True
    p = m.node_tree.nodes.get("Principled BSDF")
    p.inputs["Base Color"].default_value = (*color, 1)
    p.inputs["Roughness"].default_value = 0.9
    return m


wood = mat("Original mage wand wood", (0.12, 0.075, 0.045))
crystal = mat("Original quiet blue crystal", (0.12, 0.30, 0.40))
robeMat = mat("Original navy robe panels", (0.018, 0.044, 0.085))
sword = bpy.data.objects.new("OriginalWandGrip", None)
bpy.context.scene.collection.objects.link(sword)
sword.parent = rig
sword.parent_type = "BONE"
sword.parent_bone = "hand_r"
sword.location = (0, -rig.data.bones["hand_r"].length, 0)
bpy.ops.mesh.primitive_cylinder_add(
    vertices=8, radius=0.015, depth=0.45, location=(0, 0, 0)
)
wand = bpy.context.object
wand.name = "OriginalMageWand"
wand.parent = sword
wand.location = (0, 0, 0.17)
wand.data.materials.append(wood)
bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=0.042, location=(0, 0, 0))
tip = bpy.context.object
tip.name = "OriginalSmallWandCrystal"
tip.parent = sword
tip.location = (0, 0, 0.415)
tip.scale = (0.75, 0.75, 1.5)
tip.data.materials.append(crystal)
# Two side panels form a split-front robe, skinned once to pelvis/thighs.
# Actual bone deformation articulates the cloth; no image/frame corrections.
for side, angles in [
    ("left", [-68, -35, 0, 35, 68]),
    ("right", [112, 145, 180, 215, 248]),
]:
    verts = []
    faces = []
    for ring, (z, rx, ry) in enumerate(
        [(0.94, 0.20, 0.135), (0.65, 0.245, 0.17), (0.32, 0.29, 0.205)]
    ):
        for deg in angles:
            a = math.radians(deg)
            verts.append((rx * math.cos(a), ry * math.sin(a), z))
    for ring in range(2):
        for col in range(4):
            i = ring * 5 + col
            faces.append((i, i + 1, i + 6, i + 5))
    mesh = bpy.data.meshes.new("OriginalRobePanel-" + side)
    mesh.from_pydata(verts, [], faces)
    o = bpy.data.objects.new("OriginalNavyRobe-" + side, mesh)
    bpy.context.scene.collection.objects.link(o)
    o.parent = rig
    o.data.materials.append(robeMat)
    pelvis = o.vertex_groups.new(name="pelvis")
    legName = (
        "thigh_l"
        if (side == "left") == (rig.data.bones["thigh_l"].head_local.x > 0)
        else "thigh_r"
    )
    leg = o.vertex_groups.new(name=legName)
    for i in range(15):
        weight = [0, 0.45, 0.8][i // 5]
        pelvis.add([i], 1 - weight, "REPLACE")
        leg.add([i], weight, "REPLACE")
    mod = o.modifiers.new("SameRigClothSkin", "ARMATURE")
    mod.object = rig
    solid = o.modifiers.new("ThinClothEdge", "SOLIDIFY")
    solid.thickness = 0.006
scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.cycles.samples = 32
scene.cycles.use_denoising = False
scene.render.threads_mode = "FIXED"
scene.render.threads = 1
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
    "source": "Quaternius CC0 Male_Peasant + Ranger hood + male base head + UAL1_Standard",
    "sourceType": "adult male navy-robed mage",
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
    "originalSword": "procedural .45m wooden wand/quietblue crystal; splitnavyrobe sidepanels skinnedto pelvis/thighs, no paidoutfit",
}
# A new pose/material contract must never reuse older two-pose PNGs.
source_contract = json.loads((Path(__file__).resolve().parents[2] / "docs/art/character-motion-provenance.json").read_text())["sourceFiles"]
bake_key = hashlib.sha256(Path(__file__).read_bytes() + json.dumps(source_contract, sort_keys=True).encode()).hexdigest()[:16]
FRAME_DIR = OUT / "frames" / bake_key
FRAME_DIR.mkdir(parents=True, exist_ok=True)
m["bakeContract"] = bake_key


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
m["renderThreads"] = 1
m["directions"] = {label: -22.5 * i for i, label in enumerate(labels)}
m["sourceImportFPS"] = 30
m["class"] = "mage"
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
    "FreePeasantcloth+Rangerhood navyCOLOR tint, sourceSkin/brownfeetunchanged, roughness.95; original splitnavyrobe follows actuallegbones"
)
jobs = []
for d in range(16):
    jobs.append(("mage", "idle", d, 0, "Idle_Loop_Armature", 0))
for p in range(8):
    for d in range(16):
        jobs.append(("mage", "run", d, p, "Sprint_Loop_Armature", p / 8))
samples = [("Spell_Simple_Enter_Armature", n) for n in [.05, .38, .78]] + [("Spell_Simple_Shoot_Armature", n) for n in [.12, .48, .82]] + [("Spell_Simple_Exit_Armature", n) for n in [.42, .88]]
for p, (action, norm) in enumerate(samples):
    for d in range(16):
        jobs.append(("mage-cast", "cast", d, p, action, norm))
for p in range(4):
    for d8 in range(8):
        jobs.append(("roll-mage", "roll", d8 * 2, p, "Roll_Armature", p / 4))
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
    bones["projectedGaze"] = {
        "worldDirection": list(worldGaze),
        "pixelDelta": [
            (gazePoint.x * 256) - bones["Head"]["pixel"][0],
            ((1 - gazePoint.y) * 256) - bones["Head"]["pixel"][1],
        ],
    }
    path = FRAME_DIR / f"{sheet}-{kind}-d{d:02d}-p{phase}.png"
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
